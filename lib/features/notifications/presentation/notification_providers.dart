import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../auth/domain/auth_session_state.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../config/app_config.dart';
import '../../../features/backend_api/data/backend_repositories.dart';
import '../../../features/backend_api/presentation/backend_api_providers.dart';
import '../../../shared/core/app_logger.dart';
import '../../../settings/application/app_settings.dart';
import '../../generation_submission/application/generation_submission_service.dart';
import '../data/notification_device_store.dart';
import '../data/push_notification_gateway.dart';
import '../domain/notification_device.dart';

final notificationDeviceStoreProvider = Provider<NotificationDeviceStore>((
  Ref ref,
) {
  return const SharedPreferencesNotificationDeviceStore();
}, dependencies: const <ProviderOrFamily>[]);

final pushNotificationGatewayProvider = Provider<PushNotificationGateway>((
  Ref ref,
) {
  return const PushPackageNotificationGateway();
}, dependencies: const <ProviderOrFamily>[]);

final notificationDeviceRepositoryProvider =
    Provider<NotificationDeviceRepository>(
      (Ref ref) {
        return WorkerNotificationDeviceRepository(
          ref.watch(fantasyApiClientProvider),
        );
      },
      dependencies: <ProviderOrFamily>[
        accessTokenProvider,
        fantasyApiClientProvider,
      ],
    );

final notificationDeviceControllerProvider =
    NotifierProvider<NotificationDeviceController, NotificationDeviceState>(
      NotificationDeviceController.new,
      dependencies: <ProviderOrFamily>[
        appSettingsControllerProvider,
        authSessionProvider,
        sessionCoordinatorProvider,
        notificationDeviceStoreProvider,
        notificationDeviceRepositoryProvider,
        pushNotificationGatewayProvider,
      ],
    );

final notificationLifecycleProvider = Provider<void>((Ref ref) {
  ref.watch(notificationDeviceControllerProvider.notifier).start();
}, dependencies: <ProviderOrFamily>[notificationDeviceControllerProvider]);

class NotificationDeviceState {
  const NotificationDeviceState({
    this.deviceId,
    this.permissionEnabled = false,
    this.isRegistering = false,
    this.lastError,
  });

  final String? deviceId;
  final bool permissionEnabled;
  final bool isRegistering;
  final String? lastError;

  NotificationDeviceState copyWith({
    String? deviceId,
    bool clearDeviceId = false,
    bool? permissionEnabled,
    bool? isRegistering,
    String? lastError,
    bool clearLastError = false,
  }) {
    return NotificationDeviceState(
      deviceId: clearDeviceId ? null : deviceId ?? this.deviceId,
      permissionEnabled: permissionEnabled ?? this.permissionEnabled,
      isRegistering: isRegistering ?? this.isRegistering,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }
}

class NotificationDeviceController extends Notifier<NotificationDeviceState>
    implements NotificationDeviceCoordinator {
  @override
  NotificationDeviceState build() {
    return const NotificationDeviceState();
  }

  NotificationDeviceStore get _store =>
      ref.read(notificationDeviceStoreProvider);

  NotificationDeviceRepository get _repository =>
      ref.read(notificationDeviceRepositoryProvider);

  PushNotificationGateway get _gateway =>
      ref.read(pushNotificationGatewayProvider);

  bool _started = false;
  bool _registering = false;
  VoidCallback? _unsubscribeToken;
  VoidCallback? _unsubscribeForeground;
  VoidCallback? _unsubscribeTap;
  StreamSubscription<AuthSessionState>? _authSubscription;

  void start() {
    if (_started) {
      return;
    }
    _started = true;

    _unsubscribeToken = _gateway.addTokenListener((String token) async {
      await _registerToken(token: token, requestPermission: false);
    });
    _unsubscribeForeground = _gateway.addForegroundMessageListener((
      GenerationNotificationPayload payload,
    ) async {
      _debugLog('foreground notification task=${payload.taskId}');
    });
    _unsubscribeTap = _gateway.addNotificationTapListener(_handleTap);
    unawaited(_handleLaunchTap());

    _authSubscription = ref.read(sessionCoordinatorProvider).states.listen((
      AuthSessionState authState,
    ) {
      if (authState.status == AuthSessionStatus.signedOut ||
          authState.status == AuthSessionStatus.sessionExpired) {
        unawaited(unregisterCurrentDevice());
      }
    });

    ref.onDispose(_dispose);
  }

  @override
  Future<String?> ensureRegisteredForGeneration() async {
    final StoredNotificationDevice? stored = await _store.loadDevice();
    if (stored != null && stored.permissionEnabled) {
      state = state.copyWith(
        deviceId: stored.deviceId,
        permissionEnabled: stored.permissionEnabled,
        clearLastError: true,
      );
      return stored.deviceId;
    }

    return _registerToken(token: null, requestPermission: true);
  }

  Future<void> unregisterCurrentDevice() async {
    final StoredNotificationDevice? stored = await _store.loadDevice();
    if (stored == null) {
      return;
    }
    try {
      await _repository.unregisterDevice(stored.deviceId);
    } on Object catch (error, stackTrace) {
      logAppError('notification_device_unregister_failed', error, stackTrace);
    } finally {
      await _store.clearDevice();
      _gateway.unregisterForRemoteNotifications();
      state = state.copyWith(
        clearDeviceId: true,
        permissionEnabled: false,
        clearLastError: true,
      );
    }
  }

  Future<String?> _registerToken({
    required String? token,
    required bool requestPermission,
  }) async {
    if (_registering) {
      return state.deviceId;
    }
    if (!Platform.isIOS && !Platform.isMacOS) {
      return null;
    }
    _registering = true;
    state = state.copyWith(isRegistering: true, clearLastError: true);
    try {
      final bool permissionEnabled = requestPermission
          ? await _gateway.requestPermission()
          : await _gateway.areNotificationsEnabled();

      if (token == null) {
        _gateway.registerForRemoteNotifications();
      }
      final String? currentToken = token ?? await _gateway.token();
      if (currentToken == null || currentToken.isEmpty) {
        state = state.copyWith(
          isRegistering: false,
          permissionEnabled: permissionEnabled,
        );
        return null;
      }

      final String installationId = await _store.installationId();
      final String environment = _pushEnvironment();
      final String topic = AppConfig.pushNotificationTopic;
      final String tokenHash = notificationTokenHash(currentToken);
      final StoredNotificationDevice? stored = await _store.loadDevice();

      if (stored != null &&
          stored.tokenHash == tokenHash &&
          stored.environment == environment &&
          stored.topic == topic &&
          stored.permissionEnabled == permissionEnabled) {
        state = state.copyWith(
          deviceId: stored.deviceId,
          permissionEnabled: stored.permissionEnabled,
          isRegistering: false,
        );
        return stored.deviceId;
      }

      final RegisteredNotificationDevice registered = await _repository
          .registerDevice(
            RegisterNotificationDeviceInput(
              installationId: installationId,
              deviceToken: currentToken,
              environment: environment,
              topic: topic,
              locale: _currentLocale(),
              permissionEnabled: permissionEnabled,
            ),
          );

      await _store.saveDevice(
        StoredNotificationDevice(
          deviceId: registered.id,
          tokenHash: tokenHash,
          environment: registered.environment,
          topic: registered.topic,
          permissionEnabled: registered.permissionEnabled,
        ),
      );
      state = state.copyWith(
        deviceId: registered.id,
        permissionEnabled: registered.permissionEnabled,
        isRegistering: false,
      );
      return registered.id;
    } on Object catch (error, stackTrace) {
      logAppError('notification_device_register_failed', error, stackTrace);
      state = state.copyWith(isRegistering: false, lastError: error.toString());
      return null;
    } finally {
      _registering = false;
    }
  }

  Future<void> _handleLaunchTap() async {
    final GenerationNotificationPayload? payload = await _gateway
        .notificationTapWhichLaunchedApp();
    if (payload != null) {
      await _handleTap(payload);
    }
  }

  Future<void> _handleTap(GenerationNotificationPayload payload) async {
    notificationNavigationDelegate.openGalleryForTask(payload.taskId);
  }

  String _currentLocale() {
    return localeNameForPreference(
      ref.read(appSettingsControllerProvider).localePreference,
    );
  }

  String _pushEnvironment() {
    return kReleaseMode ? 'production' : 'development';
  }

  void _dispose() {
    _unsubscribeToken?.call();
    _unsubscribeForeground?.call();
    _unsubscribeTap?.call();
    unawaited(_authSubscription?.cancel());
  }
}

final NotificationNavigationDelegate notificationNavigationDelegate =
    NotificationNavigationDelegate();

class NotificationNavigationDelegate {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void openGalleryForTask(String taskId) {
    final BuildContext? context = navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    context.go(generationGalleryRouteForTask(taskId));
  }
}

void _debugLog(String message) {
  appDebugLog('Notifications', message);
}
