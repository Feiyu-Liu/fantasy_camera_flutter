import 'package:flutter/cupertino.dart';

abstract final class AppColors {
  static const Color black = CupertinoColors.black;
  static const Color white = CupertinoColors.white;

  static const Color accentYellow = Color(0xFFFFDE55);

  static const Color success = CupertinoColors.activeGreen;
  static const Color purchaseSuccessGreen = Color(0xFF0F7A34);
  static const Color danger = CupertinoColors.systemRed;
  static const Color link = CupertinoColors.activeBlue;

  static const CupertinoDynamicColor secondaryLabel =
      CupertinoColors.secondaryLabel;
  static const Color textSecondary = Color(0xFFBDBDBD);
  static const Color textMuted = Color(0xFF777777);
  static const Color textPlaceholder = Color(0xFFBBBBBB);

  static const Color border = Color(0xFFDDDDDD);
  static const Color borderSubtle = Color(0xFFEEEEEE);
  static const Color surface = Color(0xFFF9F9F9);
  static const Color surfaceMuted = Color(0xFFF5F5F5);

  static const Color settingsBackground = Color(0xFFFDFDFD);
  static const Color settingsAvatarBackground = Color(0xFFF1F1F1);
  static const Color settingsMutedText = Color(0xFF777777);
  static const Color settingsRowDivider = Color(0xFFEFEFEF);
  static const Color settingsDisabledSwitch = Color(0xFFE2E2E2);
  static const Color settingsProgressBackground = Color(0xFFECECEC);

  static const Color darkSurface = Color(0xFF111111);
  static const Color authInputBackground = Color(0xFF151515);
  static const Color authInputBorder = Color(0xFF2A2A2A);
  static const Color disabledDark = Color(0xFF555555);
  static const Color disabledText = Color(0xFF777777);
  static const Color disabledSurfaceDark = Color(0xFF222222);
  static const Color authError = Color(0xFFFFB4A8);
  static const Color authEditorialBackground = Color(0xFFFBFBFA);
  static const Color authEditorialMuted = Color(0xFF7C7C80);
  static const Color authEditorialPlaceholder = Color(0xFFC9C9C9);
  static const Color authEditorialDisabled = Color(0xFFC6C6C6);
  static const Color authEditorialError = Color(0xFFB3261E);

  static const Color shadowBlack10 = Color(0x1A000000);
  static const Color textShadowBlack50 = Color(0x80000000);

  static Color blackOverlay(double alpha) => black.withValues(alpha: alpha);
}
