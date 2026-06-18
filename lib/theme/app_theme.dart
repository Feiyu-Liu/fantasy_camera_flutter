import 'package:flutter/cupertino.dart';

import '../settings/application/app_settings.dart';

class AppThemeColors {
  const AppThemeColors({
    required this.brightness,
    required this.background,
    required this.cameraBackground,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.divider,
    required this.controlFill,
    required this.controlFillDisabled,
    required this.inverseText,
    required this.accentYellow,
    required this.navBlurBackground,
    required this.shadow,
  });

  final Brightness brightness;
  final Color background;
  final Color cameraBackground;
  final Color surface;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color divider;
  final Color controlFill;
  final Color controlFillDisabled;
  final Color inverseText;
  final Color accentYellow;
  final Color navBlurBackground;
  final Color shadow;

  bool get isDark => brightness == Brightness.dark;

  static AppThemeColors of(BuildContext context) {
    final _AppThemeColorsScope? scope = context
        .dependOnInheritedWidgetOfExactType<_AppThemeColorsScope>();
    if (scope != null) {
      return scope.colors;
    }
    final Brightness brightness =
        CupertinoTheme.of(context).brightness ??
        MediaQuery.platformBrightnessOf(context);
    return brightness == Brightness.dark ? dark : light;
  }

  static AppThemeColors lerp(
    AppThemeColors a,
    AppThemeColors b,
    double t, {
    Brightness? brightness,
  }) {
    Color lerpColor(Color begin, Color end) {
      return Color.lerp(begin, end, t) ?? end;
    }

    return AppThemeColors(
      brightness: brightness ?? (t < 0.5 ? a.brightness : b.brightness),
      background: lerpColor(a.background, b.background),
      cameraBackground: lerpColor(a.cameraBackground, b.cameraBackground),
      surface: lerpColor(a.surface, b.surface),
      surfaceMuted: lerpColor(a.surfaceMuted, b.surfaceMuted),
      textPrimary: lerpColor(a.textPrimary, b.textPrimary),
      textSecondary: lerpColor(a.textSecondary, b.textSecondary),
      textMuted: lerpColor(a.textMuted, b.textMuted),
      border: lerpColor(a.border, b.border),
      divider: lerpColor(a.divider, b.divider),
      controlFill: lerpColor(a.controlFill, b.controlFill),
      controlFillDisabled: lerpColor(
        a.controlFillDisabled,
        b.controlFillDisabled,
      ),
      inverseText: lerpColor(a.inverseText, b.inverseText),
      accentYellow: lerpColor(a.accentYellow, b.accentYellow),
      navBlurBackground: lerpColor(a.navBlurBackground, b.navBlurBackground),
      shadow: lerpColor(a.shadow, b.shadow),
    );
  }

  static const AppThemeColors light = AppThemeColors(
    brightness: Brightness.light,
    background: Color(0xFFFDFDFD),
    cameraBackground: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF5F5F5),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF555555),
    textMuted: Color(0xFF777777),
    border: Color(0xFF000000),
    divider: Color(0xFFEFEFEF),
    controlFill: Color(0xFFFFFFFF),
    controlFillDisabled: Color(0xFFE2E2E2),
    inverseText: Color(0xFFFFFFFF),
    accentYellow: Color(0xFFFFDE55),
    navBlurBackground: Color(0xB8FDFDFD),
    shadow: Color(0x1A000000),
  );

  static const AppThemeColors dark = AppThemeColors(
    brightness: Brightness.dark,
    background: Color(0xFF080808),
    cameraBackground: Color(0xFF000000),
    surface: Color(0xFF151515),
    surfaceMuted: Color(0xFF202020),
    textPrimary: Color(0xFFF7F7F7),
    textSecondary: Color(0xFFC8C8C8),
    textMuted: Color(0xFF9B9B9B),
    border: Color(0xFFECECEC),
    divider: Color(0xFF2C2C2C),
    controlFill: Color(0xFF101010),
    controlFillDisabled: Color(0xFF2B2B2B),
    inverseText: Color(0xFF000000),
    accentYellow: Color(0xFFFFDE55),
    navBlurBackground: Color(0xB8080808),
    shadow: Color(0x66000000),
  );
}

class AppThemeColorsScope extends StatelessWidget {
  const AppThemeColorsScope({
    required this.colors,
    required this.child,
    super.key,
  });

  final AppThemeColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _AppThemeColorsScope(colors: colors, child: child);
  }
}

class _AppThemeColorsScope extends InheritedWidget {
  const _AppThemeColorsScope({required this.colors, required super.child});

  final AppThemeColors colors;

  @override
  bool updateShouldNotify(_AppThemeColorsScope oldWidget) {
    return colors != oldWidget.colors;
  }
}

CupertinoThemeData appCupertinoThemeForPreference(
  AppThemePreference preference,
) {
  return switch (preference) {
    AppThemePreference.light => CupertinoThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppThemeColors.light.background,
      primaryColor: AppThemeColors.light.textPrimary,
      barBackgroundColor: AppThemeColors.light.background,
    ),
    AppThemePreference.dark => CupertinoThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppThemeColors.dark.background,
      primaryColor: AppThemeColors.dark.textPrimary,
      barBackgroundColor: AppThemeColors.dark.background,
    ),
  };
}

AppThemeColors appThemeColorsForPreference(AppThemePreference preference) {
  return switch (preference) {
    AppThemePreference.light => AppThemeColors.light,
    AppThemePreference.dark => AppThemeColors.dark,
  };
}

CupertinoThemeData lerpCupertinoThemeData(
  CupertinoThemeData a,
  CupertinoThemeData b,
  double t, {
  Brightness? brightness,
}) {
  Color lerpColor(Color begin, Color end) {
    return Color.lerp(begin, end, t) ?? end;
  }

  return CupertinoThemeData(
    brightness: brightness ?? (t < 0.5 ? a.brightness : b.brightness),
    scaffoldBackgroundColor: lerpColor(
      a.scaffoldBackgroundColor,
      b.scaffoldBackgroundColor,
    ),
    primaryColor: lerpColor(a.primaryColor, b.primaryColor),
    primaryContrastingColor: lerpColor(
      a.primaryContrastingColor,
      b.primaryContrastingColor,
    ),
    barBackgroundColor: lerpColor(a.barBackgroundColor, b.barBackgroundColor),
    selectionHandleColor: lerpColor(
      a.selectionHandleColor,
      b.selectionHandleColor,
    ),
    applyThemeToAll: b.applyThemeToAll,
  );
}
