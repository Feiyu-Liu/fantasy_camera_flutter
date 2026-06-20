import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_corners.dart';
import '../../../theme/app_theme.dart';

class AppSelectableRectButton extends StatelessWidget {
  const AppSelectableRectButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
    super.key,
    this.enabled = true,
    this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Color selectedContentColor = colors.isDark
        ? colors.accentYellow
        : colors.textPrimary;
    final Color contentColor = selected
        ? selectedContentColor
        : colors.textPrimary;
    final Color effectiveContentColor = enabled
        ? contentColor
        : contentColor.withValues(alpha: 0.42);
    final Color backgroundColor = selected && !colors.isDark
        ? colors.accentYellow
        : colors.surface;
    final Color borderColor = selected
        ? (colors.isDark ? colors.accentYellow : colors.textPrimary)
        : colors.textPrimary.withValues(alpha: 0.72);
    final VoidCallback? effectiveOnPressed = enabled ? onPressed : null;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: effectiveOnPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                effectiveOnPressed();
              },
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 90),
          curve: Curves.easeOutCubic,
          height: 34,
          decoration: AppCorners.controlDecoration(
            color: backgroundColor,
            side: BorderSide(color: borderColor, width: 0.5),
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
                    color: effectiveContentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 7),
                Icon(icon, color: effectiveContentColor, size: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
