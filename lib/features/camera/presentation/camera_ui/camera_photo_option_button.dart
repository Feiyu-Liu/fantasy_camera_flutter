import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../../config/app_config.dart';
import '../../../../theme/app_corners.dart';
import '../../../../theme/app_theme.dart';
import 'camera_photo_overlay_panel.dart';
import 'camera_ui_tokens.dart';

class CameraPhotoOptionButton extends StatelessWidget {
  const CameraPhotoOptionButton({
    required this.tokens,
    required this.label,
    required this.icon,
    required this.selected,
    required this.animationIndex,
    required this.onPressed,
    super.key,
    this.semanticLabel,
  });

  final CameraUiTokens tokens;
  final String label;
  final IconData icon;
  final bool selected;
  final int animationIndex;
  final VoidCallback onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final bool inOverlayPanel = CameraPhotoOverlayPanel.maybeOf(context);
    final Color selectedContentColor = colors.isDark
        ? tokens.accentColor
        : tokens.primaryTextColor;
    final Color contentColor = selected
        ? selectedContentColor
        : tokens.primaryTextColor;
    final Color backgroundColor = selected && !colors.isDark
        ? tokens.accentColor
        : colors.surface;
    final Color resolvedBackgroundColor = inOverlayPanel
        ? backgroundColor.withValues(alpha: selected ? 0.50 : 0.38)
        : backgroundColor;
    final Color borderColor = selected
        ? (colors.isDark ? tokens.accentColor : tokens.primaryTextColor)
        : tokens.primaryTextColor.withValues(alpha: 0.72);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : Duration(milliseconds: 180 + animationIndex * 36),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset((1 - value) * -10, 0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Semantics(
          button: true,
          selected: selected,
          label: semanticLabel ?? label,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            onPressed: () {
              HapticFeedback.selectionClick();
              onPressed();
            },
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 90),
              curve: Curves.easeOutCubic,
              height: 34,
              decoration: AppCorners.controlDecoration(
                color: resolvedBackgroundColor,
                side: BorderSide(
                  color: borderColor,
                  width: AppConfig.cameraUiDividerWidth,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: contentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Icon(icon, color: contentColor, size: 15),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
