import 'package:flutter/cupertino.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_corners.dart';
import '../../theme/app_theme.dart';

enum PurchaseMode { subscription, credits }

class PurchaseModeSwitcher extends StatelessWidget {
  const PurchaseModeSwitcher({
    required this.mode,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final PurchaseMode mode;
  final bool enabled;
  final ValueChanged<PurchaseMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return DecoratedBox(
      decoration: AppCorners.controlDecoration(
        color: colors.surface,
        side: BorderSide(color: colors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: <Widget>[
            _PurchaseModeSegment(
              key: const ValueKey<String>('purchase-mode-subscription'),
              semanticsIdentifier: 'purchase-mode-subscription',
              label: context.l10n.purchaseModeSubscription,
              selected: mode == PurchaseMode.subscription,
              onPressed: enabled
                  ? () => onChanged(PurchaseMode.subscription)
                  : null,
            ),
            _PurchaseModeSegment(
              key: const ValueKey<String>('purchase-mode-credits'),
              semanticsIdentifier: 'purchase-mode-credits',
              label: context.l10n.purchaseModeCredits,
              selected: mode == PurchaseMode.credits,
              onPressed: enabled ? () => onChanged(PurchaseMode.credits) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseModeSegment extends StatelessWidget {
  const _PurchaseModeSegment({
    required this.semanticsIdentifier,
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String semanticsIdentifier;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Expanded(
      child: Semantics(
        identifier: semanticsIdentifier,
        button: true,
        selected: selected,
        enabled: onPressed != null,
        excludeSemantics: true,
        label: label,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: selected ? null : onPressed,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 36,
            decoration: AppCorners.controlDecoration(
              color: selected
                  ? colors.textPrimary
                  : colors.textPrimary.withValues(alpha: 0),
            ),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: selected
                      ? colors.inverseText
                      : onPressed == null
                      ? colors.textMuted.withValues(alpha: 0.45)
                      : colors.textSecondary,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PurchasePrimaryButton extends StatelessWidget {
  const PurchasePrimaryButton({
    required this.label,
    required this.isBusy,
    required this.onPressed,
    this.successLabel,
    super.key,
  });

  final String label;
  final bool isBusy;
  final VoidCallback? onPressed;

  /// Non-null switches the button into its green, disabled success state.
  final String? successLabel;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    final String? success = successLabel;
    final bool isSuccess = success != null;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: isBusy || isSuccess ? null : onPressed,
      child: AnimatedContainer(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: AppCorners.controlDecoration(
          color: isSuccess
              ? AppColors.purchaseSuccessGreen
              : isBusy || onPressed == null
              ? colors.controlFillDisabled
              : colors.textPrimary,
          side: BorderSide(color: colors.border, width: 0.5),
        ),
        child: SizedBox(
          height: 52,
          child: Center(
            child: isBusy
                ? CupertinoActivityIndicator(color: colors.textMuted)
                : Text(
                    success ?? label,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: !isSuccess && onPressed == null
                          ? colors.textMuted
                          : colors.inverseText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class PurchaseFooterLinks extends StatelessWidget {
  const PurchaseFooterLinks({
    required this.isBusy,
    required this.onRestorePressed,
    required this.onPrivacyPressed,
    required this.onTermsPressed,
    super.key,
  });

  final bool isBusy;
  final VoidCallback onRestorePressed;
  final VoidCallback onPrivacyPressed;
  final VoidCallback onTermsPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return Row(
      children: <Widget>[
        _FooterLinkButton(
          label: context.l10n.billingRestorePurchases,
          onPressed: isBusy ? null : onRestorePressed,
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: <Widget>[
                  _FooterLinkButton(
                    label: context.l10n.settingsPrivacyPolicyTitle,
                    onPressed: onPrivacyPressed,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '|',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  _FooterLinkButton(
                    label: context.l10n.settingsTermsTitle,
                    onPressed: onTermsPressed,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterLinkButton extends StatelessWidget {
  const _FooterLinkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Text(
        label,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: onPressed == null
              ? colors.textMuted.withValues(alpha: 0.45)
              : colors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          decoration: onPressed == null
              ? TextDecoration.none
              : TextDecoration.underline,
          decorationColor: onPressed == null
              ? colors.textMuted.withValues(alpha: 0)
              : colors.textMuted,
          decorationThickness: 0.7,
        ),
      ),
    );
  }
}
