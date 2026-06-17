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
  final Color navBlurBackground;
  final Color shadow;

  bool get isDark => brightness == Brightness.dark;

  static AppThemeColors of(BuildContext context) {
    final Brightness brightness =
        CupertinoTheme.of(context).brightness ??
        MediaQuery.platformBrightnessOf(context);
    return brightness == Brightness.dark ? dark : light;
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
    navBlurBackground: Color(0xB8FDFDFD),
    shadow: Color(0x1A000000),
  );

  static const AppThemeColors dark = AppThemeColors(
    brightness: Brightness.dark,
    background: Color(0xFF080808),
    cameraBackground: Color(0xFF050505),
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
    navBlurBackground: Color(0xB8080808),
    shadow: Color(0x66000000),
  );
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
