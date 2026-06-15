import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/presentation/auth_providers.dart';
import '../l10n/l10n.dart';
import '../settings/application/app_settings.dart';
import '../theme/app_colors.dart';
import 'app_router.dart';

class FantasyCameraApp extends StatelessWidget {
  const FantasyCameraApp({
    this.initialSettings = const AppSettingsState(),
    this.overrides = const <Override>[],
    super.key,
  });

  final AppSettingsState initialSettings;
  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: <Override>[
        appSettingsControllerProvider.overrideWith(
          () => AppSettingsController(initialState: initialSettings),
        ),
        ...overrides,
      ],
      child: const _FantasyCameraAppView(),
    );
  }
}

class _FantasyCameraAppView extends ConsumerWidget {
  const _FantasyCameraAppView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettingsState appSettings = ref.watch(
      appSettingsControllerProvider,
    );
    final Locale? locale = localeForPreference(appSettings.localePreference);
    final AppLocalizations titleLocalizations = appLocalizationsFor(
      locale ?? defaultAppLocale,
    );
    return CupertinoApp.router(
      title: titleLocalizations.appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? child) {
        return ProviderScope(
          overrides: <Override>[
            appLocalizationsProvider.overrideWithValue(context.l10n),
          ],
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: const CupertinoThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.black,
        primaryColor: AppColors.white,
      ),
      routerConfig: createAppRouter(),
    );
  }
}
