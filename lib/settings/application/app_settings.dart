import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/l10n.dart';

const String confirmBeforeGenerationPreferenceKey =
    'settings.confirm_before_generation';
const String localePreferenceKey = 'settings.locale_preference';
const String themePreferenceKey = 'settings.theme_preference';

enum AppLocalePreference {
  system,
  zh,
  zhTW,
  en,
  ja,
  fr;

  static AppLocalePreference fromStorageValue(String? value) {
    return AppLocalePreference.values.firstWhere(
      (AppLocalePreference preference) => preference.storageValue == value,
      orElse: () => AppLocalePreference.system,
    );
  }

  String get storageValue => name;
}

Locale? localeForPreference(AppLocalePreference preference) {
  return switch (preference) {
    AppLocalePreference.system => null,
    AppLocalePreference.zh => const Locale('zh'),
    AppLocalePreference.zhTW => const Locale('zh', 'TW'),
    AppLocalePreference.en => const Locale('en'),
    AppLocalePreference.ja => const Locale('ja'),
    AppLocalePreference.fr => const Locale('fr'),
  };
}

Locale effectiveLocaleForPreference(
  AppLocalePreference preference, {
  Locale? platformLocale,
}) {
  final Locale? explicitLocale = localeForPreference(preference);
  if (explicitLocale != null) {
    return explicitLocale;
  }
  final Locale resolvedPlatformLocale =
      platformLocale ?? WidgetsBinding.instance.platformDispatcher.locale;
  return _supportedLocaleFor(resolvedPlatformLocale);
}

String localeNameForPreference(
  AppLocalePreference preference, {
  Locale? platformLocale,
}) {
  return appLocalizationsFor(
    effectiveLocaleForPreference(preference, platformLocale: platformLocale),
  ).localeName;
}

Locale _supportedLocaleFor(Locale locale) {
  for (final Locale supportedLocale in AppLocalizations.supportedLocales) {
    if (supportedLocale.languageCode == locale.languageCode &&
        supportedLocale.countryCode == locale.countryCode) {
      return supportedLocale;
    }
  }
  for (final Locale supportedLocale in AppLocalizations.supportedLocales) {
    if (supportedLocale.languageCode == locale.languageCode &&
        supportedLocale.countryCode == null) {
      return supportedLocale;
    }
  }
  return defaultAppLocale;
}

enum AppThemePreference {
  light,
  dark;

  static AppThemePreference fromStorageValue(String? value) {
    return AppThemePreference.values.firstWhere(
      (AppThemePreference preference) => preference.storageValue == value,
      orElse: () => AppThemePreference.light,
    );
  }

  String get storageValue => name;
}

class AppSettingsState {
  const AppSettingsState({
    this.confirmBeforeGenerationEnabled = true,
    this.localePreference = AppLocalePreference.system,
    this.themePreference = AppThemePreference.light,
  });

  final bool confirmBeforeGenerationEnabled;
  final AppLocalePreference localePreference;
  final AppThemePreference themePreference;

  AppSettingsState copyWith({
    bool? confirmBeforeGenerationEnabled,
    AppLocalePreference? localePreference,
    AppThemePreference? themePreference,
  }) {
    return AppSettingsState(
      confirmBeforeGenerationEnabled:
          confirmBeforeGenerationEnabled ?? this.confirmBeforeGenerationEnabled,
      localePreference: localePreference ?? this.localePreference,
      themePreference: themePreference ?? this.themePreference,
    );
  }
}

abstract interface class AppSettingsRepository {
  Future<AppSettingsState> loadSettings();

  Future<void> saveConfirmBeforeGenerationEnabled(bool value);

  Future<void> saveLocalePreference(AppLocalePreference preference);

  Future<void> saveThemePreference(AppThemePreference preference);
}

class SharedPreferencesAppSettingsRepository implements AppSettingsRepository {
  const SharedPreferencesAppSettingsRepository();

  @override
  Future<AppSettingsState> loadSettings() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return AppSettingsState(
      confirmBeforeGenerationEnabled:
          preferences.getBool(confirmBeforeGenerationPreferenceKey) ?? true,
      localePreference: AppLocalePreference.fromStorageValue(
        preferences.getString(localePreferenceKey),
      ),
      themePreference: AppThemePreference.fromStorageValue(
        preferences.getString(themePreferenceKey),
      ),
    );
  }

  @override
  Future<void> saveConfirmBeforeGenerationEnabled(bool value) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool(confirmBeforeGenerationPreferenceKey, value);
  }

  @override
  Future<void> saveLocalePreference(AppLocalePreference preference) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(localePreferenceKey, preference.storageValue);
  }

  @override
  Future<void> saveThemePreference(AppThemePreference preference) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(themePreferenceKey, preference.storageValue);
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
  AppSettingsController({AppSettingsState? initialState})
    : _initialState = initialState;

  final AppSettingsState? _initialState;
  bool _isDisposed = false;
  Future<void>? _loadFuture;

  @override
  AppSettingsState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
    });
    _loadFuture = _load();
    return _initialState ?? const AppSettingsState();
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

  Future<void> setLocalePreference(AppLocalePreference preference) async {
    state = state.copyWith(localePreference: preference);
    await ref
        .read(appSettingsRepositoryProvider)
        .saveLocalePreference(preference);
  }

  Future<void> setThemePreference(AppThemePreference preference) async {
    state = state.copyWith(themePreference: preference);
    await ref
        .read(appSettingsRepositoryProvider)
        .saveThemePreference(preference);
  }

  Future<void> _load() async {
    final AppSettingsState loadedState = await ref
        .read(appSettingsRepositoryProvider)
        .loadSettings();
    if (!_isDisposed) {
      state = loadedState;
    }
  }
}
