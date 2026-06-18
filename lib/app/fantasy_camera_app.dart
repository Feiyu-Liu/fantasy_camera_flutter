import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/presentation/auth_providers.dart';
import '../features/notifications/presentation/notification_providers.dart';
import '../l10n/l10n.dart';
import '../settings/application/app_settings.dart';
import '../theme/app_theme.dart';
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

class _FantasyCameraAppView extends ConsumerStatefulWidget {
  const _FantasyCameraAppView();

  @override
  ConsumerState<_FantasyCameraAppView> createState() =>
      _FantasyCameraAppViewState();
}

class _FantasyCameraAppViewState extends ConsumerState<_FantasyCameraAppView> {
  late final GoRouter _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    final AppSettingsState appSettings = ref.watch(
      appSettingsControllerProvider,
    );
    final Locale? locale = localeForPreference(appSettings.localePreference);
    final AppLocalizations titleLocalizations = appLocalizationsFor(
      locale ?? defaultAppLocale,
    );
    ref.watch(notificationLifecycleProvider);
    return AnimatedAppTheme(
      preference: appSettings.themePreference,
      builder: (BuildContext context, CupertinoThemeData theme) {
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
          theme: theme,
          routerConfig: _router,
        );
      },
    );
  }
}

class AnimatedAppTheme extends StatelessWidget {
  const AnimatedAppTheme({
    required this.preference,
    required this.builder,
    this.duration = const Duration(milliseconds: 280),
    this.curve = Curves.easeInOutCubic,
    super.key,
  });

  final AppThemePreference preference;
  final Duration duration;
  final Curve curve;
  final Widget Function(BuildContext context, CupertinoThemeData theme) builder;

  @override
  Widget build(BuildContext context) {
    final _AppThemeBundle targetTheme = _AppThemeBundle.forPreference(
      preference,
    );
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<_AppThemeBundle>(
      tween: _AppThemeBundleTween(end: targetTheme),
      duration: reduceMotion ? Duration.zero : duration,
      curve: curve,
      builder:
          (BuildContext context, _AppThemeBundle animatedTheme, Widget? child) {
            return AppThemeColorsScope(
              colors: animatedTheme.colors,
              child: builder(context, animatedTheme.cupertinoTheme),
            );
          },
    );
  }
}

class _AppThemeBundle {
  const _AppThemeBundle({
    required this.preference,
    required this.colors,
    required this.cupertinoTheme,
  });

  factory _AppThemeBundle.forPreference(AppThemePreference preference) {
    return _AppThemeBundle(
      preference: preference,
      colors: appThemeColorsForPreference(preference),
      cupertinoTheme: appCupertinoThemeForPreference(preference),
    );
  }

  final AppThemePreference preference;
  final AppThemeColors colors;
  final CupertinoThemeData cupertinoTheme;

  static _AppThemeBundle lerp(
    _AppThemeBundle begin,
    _AppThemeBundle end,
    double t,
  ) {
    final AppThemeColors targetColors = appThemeColorsForPreference(
      end.preference,
    );
    return _AppThemeBundle(
      preference: end.preference,
      colors: AppThemeColors.lerp(
        begin.colors,
        end.colors,
        t,
        brightness: targetColors.brightness,
      ),
      cupertinoTheme: lerpCupertinoThemeData(
        begin.cupertinoTheme,
        end.cupertinoTheme,
        t,
        brightness: targetColors.brightness,
      ),
    );
  }
}

class _AppThemeBundleTween extends Tween<_AppThemeBundle> {
  _AppThemeBundleTween({required _AppThemeBundle end}) : super(end: end);

  @override
  _AppThemeBundle lerp(double t) {
    final _AppThemeBundle? beginValue = begin;
    final _AppThemeBundle? endValue = end;
    if (beginValue == null && endValue == null) {
      return _AppThemeBundle.forPreference(AppThemePreference.light);
    }
    if (beginValue == null) {
      return endValue!;
    }
    if (endValue == null) {
      return beginValue;
    }
    return _AppThemeBundle.lerp(beginValue, endValue, t);
  }
}
