import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_corners.dart';
import '../../theme/app_theme.dart';
import '../domain/subscription_billing.dart';
import 'billing_providers.dart';
import 'purchase_page_components.dart';

class SubscriptionPurchaseContent extends ConsumerWidget {
  const SubscriptionPurchaseContent({
    required this.onOpenExternalLink,
    super.key,
  });

  final ValueChanged<String> onOpenExternalLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SubscriptionPurchaseState state = ref.watch(
      subscriptionPurchaseControllerProvider,
    );
    final SubscriptionBillingStatus? status =
        ref.watch(subscriptionBillingStatusProvider).valueOrNull ??
        state.catalogStatus;
    final AppThemeColors colors = AppThemeColors.of(context);
    final String? currentProductIdentifier =
        status?.subscription?.active == true
        ? status!.subscription!.productIdentifier
        : null;
    final bool selectedIsCurrent =
        currentProductIdentifier != null &&
        state.products.any(
          (SubscriptionProduct product) =>
              product.storeProduct.productId == state.selectedProductId &&
              product.plan.productIdentifier == currentProductIdentifier,
        );
    // The hero and credit mode opt out of Dynamic Type; plan cards follow so
    // the two modes lay out alike and prices cannot overflow at large sizes.
    return MediaQuery.withNoTextScaling(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (state.isLoading)
              const Center(child: CupertinoActivityIndicator())
            else if (state.products.isEmpty)
              _InlineMessage(
                message: context.l10n.subscriptionProductsUnavailable,
                actionLabel: context.l10n.billingRetry,
                onPressed: ref
                    .read(subscriptionPurchaseControllerProvider.notifier)
                    .loadProducts,
              )
            else
              for (final SubscriptionProduct product in state.products) ...[
                _SubscriptionPlanCard(
                  product: product,
                  selected:
                      product.storeProduct.productId == state.selectedProductId,
                  current:
                      product.plan.productIdentifier ==
                      currentProductIdentifier,
                  busy: state.isPurchasing,
                  fullQualityUnits: status?.allowanceUnitsFor('full') ?? 0,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(subscriptionPurchaseControllerProvider.notifier)
                        .selectProduct(product.storeProduct.productId);
                  },
                ),
                const SizedBox(height: 10),
              ],
            if (state.isSyncPending) ...[
              const SizedBox(height: 4),
              _InlineMessage(message: context.l10n.subscriptionSyncPending),
            ],
            const SizedBox(height: 12),
            PurchasePrimaryButton(
              label: selectedIsCurrent
                  ? context.l10n.subscriptionCurrentPlanButton
                  : context.l10n.subscriptionPurchaseButton,
              isBusy: state.isPurchasing,
              onPressed:
                  selectedIsCurrent ||
                      state.isSyncPending ||
                      state.selectedProductId == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(subscriptionPurchaseControllerProvider.notifier)
                          .purchaseSelected();
                    },
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.subscriptionAutoRenewDisclosure,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            PurchaseFooterLinks(
              isBusy: state.isPurchasing,
              onRestorePressed: () {
                HapticFeedback.selectionClick();
                ref
                    .read(subscriptionPurchaseControllerProvider.notifier)
                    .restore();
              },
              onPrivacyPressed: () =>
                  onOpenExternalLink(AppConfig.privacyPolicyUrl),
              onTermsPressed: () => onOpenExternalLink(AppConfig.termsOfUseUrl),
            ),
          ],
        ),
      ),
    );
  }
}

String subscriptionTierName(AppLocalizations l10n, SubscriptionTier tier) {
  return switch (tier) {
    SubscriptionTier.mini => l10n.subscriptionTierMini,
    SubscriptionTier.plus => l10n.subscriptionTierPlus,
    SubscriptionTier.pro => l10n.subscriptionTierPro,
  };
}

class _SubscriptionPlanCard extends StatelessWidget {
  const _SubscriptionPlanCard({
    required this.product,
    required this.selected,
    required this.current,
    required this.busy,
    required this.fullQualityUnits,
    required this.onPressed,
  });

  final SubscriptionProduct product;
  final bool selected;
  final bool current;
  final bool busy;
  final int fullQualityUnits;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    // Without a Full cost from billing status the photo estimate would read
    // "0 photos", so the line is hidden until the status arrives.
    final int? photos = fullQualityUnits <= 0
        ? null
        : product.plan.fullAllowanceUnits ~/ fullQualityUnits;
    return Semantics(
      identifier: 'subscription_plan_${product.plan.tier.name}',
      button: true,
      selected: selected,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: busy ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: AppCorners.controlDecoration(
            color: selected ? colors.accentYellow : colors.surface,
            side: BorderSide(color: colors.border, width: 0.5),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            subscriptionTierName(
                              context.l10n,
                              product.plan.tier,
                            ),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.black
                                  : colors.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (current) ...[
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.subscriptionCurrentPlan,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.black.withValues(alpha: 0.65)
                                  : colors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    if (photos != null) ...<Widget>[
                      Text(
                        context.l10n.subscriptionPhotosPerWindow(photos),
                        style: TextStyle(
                          color: selected
                              ? AppColors.black.withValues(alpha: 0.72)
                              : colors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      product.plan.maxEnabled
                          ? context.l10n.subscriptionMaxIncluded
                          : context.l10n.subscriptionMaxUnavailable,
                      style: TextStyle(
                        color: selected
                            ? AppColors.black.withValues(alpha: 0.72)
                            : colors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                product.storeProduct.price,
                style: TextStyle(
                  color: selected ? AppColors.black : colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return Column(
      children: <Widget>[
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textMuted, fontSize: 13),
        ),
        if (actionLabel != null && onPressed != null)
          CupertinoButton(onPressed: onPressed, child: Text(actionLabel!)),
      ],
    );
  }
}
