import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String confirmBeforeGenerationPreferenceKey =
    'settings.confirm_before_generation';

class AppSettingsState {
  const AppSettingsState({this.confirmBeforeGenerationEnabled = true});

  final bool confirmBeforeGenerationEnabled;

  AppSettingsState copyWith({bool? confirmBeforeGenerationEnabled}) {
    return AppSettingsState(
      confirmBeforeGenerationEnabled:
          confirmBeforeGenerationEnabled ?? this.confirmBeforeGenerationEnabled,
    );
  }
}

abstract interface class AppSettingsRepository {
  Future<bool> loadConfirmBeforeGenerationEnabled();

  Future<void> saveConfirmBeforeGenerationEnabled(bool value);
}

class SharedPreferencesAppSettingsRepository implements AppSettingsRepository {
  const SharedPreferencesAppSettingsRepository();

  @override
  Future<bool> loadConfirmBeforeGenerationEnabled() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getBool(confirmBeforeGenerationPreferenceKey) ?? true;
  }

  @override
  Future<void> saveConfirmBeforeGenerationEnabled(bool value) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool(confirmBeforeGenerationPreferenceKey, value);
  }
}

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>(
  (Ref ref) => const SharedPreferencesAppSettingsRepository(),
  dependencies: const <ProviderOrFamily>[],
);

final appSettingsControllerProvider =
    NotifierProvider<AppSettingsController, AppSettingsState>(
      AppSettingsController.new,
      dependencies: <ProviderOrFamily>[appSettingsRepositoryProvider],
    );

class AppSettingsController extends Notifier<AppSettingsState> {
  bool _isDisposed = false;
  Future<void>? _loadFuture;

  @override
  AppSettingsState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
    });
    _loadFuture = _load();
    return const AppSettingsState();
  }

  Future<AppSettingsState> ensureLoaded() async {
    await _loadFuture;
    return state;
  }

  Future<void> setConfirmBeforeGenerationEnabled(bool value) async {
    state = state.copyWith(confirmBeforeGenerationEnabled: value);
    await ref
        .read(appSettingsRepositoryProvider)
        .saveConfirmBeforeGenerationEnabled(value);
  }

  Future<void> _load() async {
    final bool value = await ref
        .read(appSettingsRepositoryProvider)
        .loadConfirmBeforeGenerationEnabled();
    if (!_isDisposed) {
      state = state.copyWith(confirmBeforeGenerationEnabled: value);
    }
  }
}
