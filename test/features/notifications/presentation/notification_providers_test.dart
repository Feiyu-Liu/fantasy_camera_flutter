import 'dart:async';

import 'package:fantasy_camera_flutter/features/notifications/data/notification_device_store.dart';
import 'package:fantasy_camera_flutter/features/notifications/data/push_notification_gateway.dart';
import 'package:fantasy_camera_flutter/features/notifications/presentation/notification_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification denial does not wait for an APNs token', () async {
    final _DeniedPushGateway gateway = _DeniedPushGateway();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        notificationDeviceStoreProvider.overrideWithValue(
          const _EmptyNotificationDeviceStore(),
        ),
        pushNotificationGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);

    final String? deviceId = await container
        .read(notificationDeviceControllerProvider.notifier)
        .ensureRegisteredForGeneration();

    expect(deviceId, isNull);
    expect(gateway.registerCalls, 0);
    expect(gateway.tokenCalls, 0);
  });
}

class _EmptyNotificationDeviceStore implements NotificationDeviceStore {
  const _EmptyNotificationDeviceStore();

  @override
  Future<void> clearDevice() async {}

  @override
  Future<String> installationId() async => 'installation-1';

  @override
  Future<StoredNotificationDevice?> loadDevice() async => null;

  @override
  Future<void> saveDevice(StoredNotificationDevice device) async {}
}

class _DeniedPushGateway implements PushNotificationGateway {
  int registerCalls = 0;
  int tokenCalls = 0;

  @override
  VoidCallback addForegroundMessageListener(
    FutureOr<void> Function(GenerationNotificationPayload payload) handler,
  ) => () {};

  @override
  VoidCallback addNotificationTapListener(
    FutureOr<void> Function(GenerationNotificationPayload payload) handler,
  ) => () {};

  @override
  VoidCallback addTokenListener(
    FutureOr<void> Function(String token) handler,
  ) => () {};

  @override
  Future<bool> areNotificationsEnabled() async => false;

  @override
  Future<GenerationNotificationPayload?>
  notificationTapWhichLaunchedApp() async => null;

  @override
  void registerForRemoteNotifications() {
    registerCalls += 1;
  }

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> token() async {
    tokenCalls += 1;
    return null;
  }

  @override
  void unregisterForRemoteNotifications() {}
}
