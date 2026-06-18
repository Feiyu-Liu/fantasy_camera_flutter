import 'package:flutter/cupertino.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_theme.dart';

class CameraUiTokens {
  const CameraUiTokens({
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.viewfinderColor = const Color(0xFF000000),
    this.primaryTextColor = const Color(0xFF000000),
    this.inverseTextColor = const Color(0xFFFFFFFF),
    this.accentColor = AppColors.accentYellow,
    this.inactiveColor = const Color(0xFF888888),
    this.dividerColor = const Color(0xFF000000),
    this.dividerWidth = 0.5,
    this.topBarHeight = 44,
    this.topBarTrailingWidth = 82,
    this.topBarButtonSize = 44,
    this.topBarIconSize = 21,
    this.aspectRatioTextStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w900,
    ),
    this.viewfinderMessageMargin = const EdgeInsets.only(
      top: 24,
      left: 24,
      right: 24,
    ),
    this.viewfinderMessageOverlayOpacity = 0.62,
    this.viewfinderMessageRadius = 14,
    this.viewfinderMessagePadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    this.viewfinderMessageTextStyle = const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    this.zoomSafeAreaPadding = const EdgeInsets.only(
      left: 24,
      right: 24,
      bottom: 0,
    ),
    this.zoomTrackItemWidth = 48,
    this.zoomTrackMinWidth = 128,
    this.zoomTrackMaxWidth = 240,
    this.zoomTrackHeight = 40,
    this.zoomPillPadding = const EdgeInsets.all(3),
    this.zoomPillOuterColor = CupertinoColors.white,
    this.zoomPillOuterOpacity = 0.92,
    this.zoomPillOuterRadius = 20,
    this.zoomPillInnerColor = const Color(0xFFE7E7E9),
    this.zoomPillInnerRadius = 17,
    this.zoomPillSmoothness = 0.8,
    this.zoomThumbColor = const Color(0xFF111111),
    this.zoomThumbSize = 30,
    this.zoomThumbRadius = 15,
    this.zoomThumbPressedScale = 1.04,
    this.zoomThumbMotionDuration = const Duration(milliseconds: 300),
    this.zoomThumbScaleDuration = const Duration(milliseconds: 180),
    this.zoomLabelPadding = const EdgeInsets.symmetric(
      horizontal: 4,
      vertical: 8,
    ),
    this.zoomSelectedLabelColor = CupertinoColors.white,
    this.zoomUnselectedLabelColor = const Color(0xFF6B6B6D),
    this.zoomSelectedLabelTextStyle = const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
    this.zoomUnselectedLabelTextStyle = const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
    ),
    this.modeRowHeight = 42,
    this.modeItemWidth = 80,
    this.modeItemPadding = const EdgeInsets.symmetric(horizontal: 8),
    this.modeSelectedTextStyle = const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.5,
    ),
    this.modeUnselectedTextStyle = const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    ),
    this.modeIndicatorTopMargin = 4,
    this.modeIndicatorWidth = 32,
    this.modeIndicatorHeight = 1.5,
    this.modeExtensionExpandedHeight = 48,
    this.modeExtensionMotionDuration = const Duration(milliseconds: 260),
    this.modeExtensionInitialDelay = 0.08,
    this.modeExtensionStaggerDelay = 0.08,
    this.modeExtensionItemDuration = 0.34,
    this.modeExtensionSlideOffset = const Offset(0, -0.14),
    this.bottomControlsHeight = 100,
    this.bottomControlsPadding = const EdgeInsets.symmetric(horizontal: 24),
    this.collapsedBottomControlLift = 18,
    this.bottomControlMotionDuration = const Duration(milliseconds: 260),
    this.galleryButtonSize = 54,
    this.shutterSize = 72,
    this.shutterOuterBorderWidth = 1.5,
    this.shutterInnerPadding = const EdgeInsets.all(4),
    this.shutterPressedScale = 0.94,
    this.shutterPressDuration = const Duration(milliseconds: 90),
    this.shutterBusyIndicatorSize = 24,
    this.disabledOpacity = 0.4,
    this.zoomDisabledOpacity = 0.46,
    this.flipButtonSize = 44,
    this.flipIconSize = 24,
    this.flipBusyIndicatorSize = 20,
    this.rotationDuration = const Duration(milliseconds: 200),
    this.standardEaseOutCurve = Curves.easeOutCubic,
    this.standardEaseInCurve = Curves.easeInCubic,
    this.zoomMotionCurve = Curves.easeOutQuart,
    this.rotationCurve = Curves.easeInOut,
    this.checkerboardCells = 8,
    this.checkerboardLightColor = const Color(0xFFEEEEEE),
    this.checkerboardDarkColor = const Color(0xFFF5F5F5),
  });

  factory CameraUiTokens.forTheme(
    BuildContext context, {
    double dividerWidth = 0.5,
  }) {
    final AppThemeColors colors = AppThemeColors.of(context);
    if (!colors.isDark) {
      return CameraUiTokens(dividerWidth: dividerWidth);
    }
    return CameraUiTokens(
      backgroundColor: colors.cameraBackground,
      viewfinderColor: AppColors.black,
      primaryTextColor: colors.textPrimary,
      inverseTextColor: colors.inverseText,
      accentColor: colors.accentYellow,
      inactiveColor: colors.textMuted,
      dividerColor: colors.divider,
      dividerWidth: dividerWidth,
      zoomPillOuterColor: const Color(0xFF151515),
      zoomPillInnerColor: const Color(0xFF262626),
      zoomThumbColor: AppColors.white,
      zoomSelectedLabelColor: AppColors.black,
      zoomUnselectedLabelColor: colors.textMuted,
      checkerboardLightColor: const Color(0xFF202020),
      checkerboardDarkColor: const Color(0xFF2B2B2B),
    );
  }

  final Color backgroundColor;
  final Color viewfinderColor;
  final Color primaryTextColor;
  final Color inverseTextColor;
  final Color accentColor;
  final Color inactiveColor;
  final Color dividerColor;
  final double dividerWidth;

  final double topBarHeight;
  final double topBarTrailingWidth;
  final double topBarButtonSize;
  final double topBarIconSize;
  final TextStyle aspectRatioTextStyle;

  final EdgeInsetsGeometry viewfinderMessageMargin;
  final double viewfinderMessageOverlayOpacity;
  final double viewfinderMessageRadius;
  final EdgeInsetsGeometry viewfinderMessagePadding;
  final TextStyle viewfinderMessageTextStyle;

  final EdgeInsetsGeometry zoomSafeAreaPadding;
  final double zoomTrackItemWidth;
  final double zoomTrackMinWidth;
  final double zoomTrackMaxWidth;
  final double zoomTrackHeight;
  final EdgeInsetsGeometry zoomPillPadding;
  final Color zoomPillOuterColor;
  final double zoomPillOuterOpacity;
  final double zoomPillOuterRadius;
  final Color zoomPillInnerColor;
  final double zoomPillInnerRadius;
  final double zoomPillSmoothness;
  final Color zoomThumbColor;
  final double zoomThumbSize;
  final double zoomThumbRadius;
  final double zoomThumbPressedScale;
  final Duration zoomThumbMotionDuration;
  final Duration zoomThumbScaleDuration;
  final EdgeInsetsGeometry zoomLabelPadding;
  final Color zoomSelectedLabelColor;
  final Color zoomUnselectedLabelColor;
  final TextStyle zoomSelectedLabelTextStyle;
  final TextStyle zoomUnselectedLabelTextStyle;

  final double modeRowHeight;
  final double modeItemWidth;
  final EdgeInsetsGeometry modeItemPadding;
  final TextStyle modeSelectedTextStyle;
  final TextStyle modeUnselectedTextStyle;
  final double modeIndicatorTopMargin;
  final double modeIndicatorWidth;
  final double modeIndicatorHeight;

  final double modeExtensionExpandedHeight;
  final Duration modeExtensionMotionDuration;
  final double modeExtensionInitialDelay;
  final double modeExtensionStaggerDelay;
  final double modeExtensionItemDuration;
  final Offset modeExtensionSlideOffset;

  final double bottomControlsHeight;
  final EdgeInsetsGeometry bottomControlsPadding;
  final double collapsedBottomControlLift;
  final Duration bottomControlMotionDuration;

  final double galleryButtonSize;
  final double shutterSize;
  final double shutterOuterBorderWidth;
  final EdgeInsetsGeometry shutterInnerPadding;
  final double shutterPressedScale;
  final Duration shutterPressDuration;
  final double shutterBusyIndicatorSize;
  final double disabledOpacity;
  final double zoomDisabledOpacity;
  final double flipButtonSize;
  final double flipIconSize;
  final double flipBusyIndicatorSize;
  final Duration rotationDuration;
  final Curve standardEaseOutCurve;
  final Curve standardEaseInCurve;
  final Curve zoomMotionCurve;
  final Curve rotationCurve;

  final int checkerboardCells;
  final Color checkerboardLightColor;
  final Color checkerboardDarkColor;
}
