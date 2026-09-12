import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_config.dart';
import '../../l10n/l10n.dart';
import '../../shared/platform/external_link_launcher.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../domain/subscription_billing.dart';
import 'billing_providers.dart';

class SubscriptionPurchasePage extends ConsumerStatefulWidget {
  const SubscriptionPurchasePage({super.key});

  @override
  ConsumerState<SubscriptionPurchasePage> createState() =>
      _SubscriptionPurchasePageState();
}

class _SubscriptionPurchasePageState
    extends ConsumerState<SubscriptionPurchasePage> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(
      ref.read(subscriptionPurchaseControllerProvider.notifier).loadProducts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final SubscriptionPurchaseState state = ref.watch(
      subscriptionPurchaseControllerProvider,
    );
    final SubscriptionBillingStatus? status =
        ref.watch(subscriptionBillingStatusProvider).valueOrNull ??
        state.catalogStatus;
    final AppThemeColors colors = AppThemeColors.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: colors.background.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: context.pop,
          child: Icon(CupertinoIcons.chevron_left, color: colors.textPrimary),
        ),
        middle: Text(context.l10n.subscriptionTitle),
      ),
      backgroundColor: colors.background,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
          children: <Widget>[
            Icon(LucideIcons.sparkles, size: 34, color: colors.textPrimary),
            const SizedBox(height: 14),
            Text(
              context.l10n.subscriptionHeroTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 27,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.subscriptionHeroSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
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
                      status?.subscription?.productIdentifier,
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
            if (state.errorKind != null) ...[
              const SizedBox(height: 4),
              _InlineMessage(message: _errorMessage(context, state.errorKind!)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: CupertinoButton.filled(
                onPressed: state.isPurchasing || state.selectedProductId == null
                    ? null
                    : ref
                          .read(subscriptionPurchaseControllerProvider.notifier)
                          .purchaseSelected,
                child: state.isPurchasing
                    ? const CupertinoActivityIndicator(color: AppColors.black)
                    : Text(context.l10n.subscriptionPurchaseButton),
              ),
            ),
            const SizedBox(height: 10),
            CupertinoButton(
              onPressed: state.isPurchasing
                  ? null
                  : ref
                        .read(subscriptionPurchaseControllerProvider.notifier)
                        .restore,
              child: Text(context.l10n.billingRestorePurchases),
            ),
            Text(
              context.l10n.subscriptionAutoRenewDisclosure,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: () => unawaited(
                    ref.read(externalLinkLauncherProvider)(
                      Uri.parse(AppConfig.termsOfUseUrl),
                    ),
                  ),
                  child: Text(context.l10n.settingsTermsTitle),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: () => unawaited(
                    ref.read(externalLinkLauncherProvider)(
                      Uri.parse(AppConfig.privacyPolicyUrl),
                    ),
                  ),
                  child: Text(context.l10n.settingsPrivacyPolicyTitle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _errorMessage(
    BuildContext context,
    SubscriptionPurchaseErrorKind kind,
  ) {
    return switch (kind) {
      SubscriptionPurchaseErrorKind.loadProducts =>
        context.l10n.subscriptionProductsUnavailable,
      SubscriptionPurchaseErrorKind.purchase =>
        context.l10n.subscriptionPurchaseFailed,
      SubscriptionPurchaseErrorKind.restore =>
        context.l10n.subscriptionRestoreFailed,
    };
  }
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
    final int photos = fullQualityUnits <= 0
        ? 0
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
          decoration: BoxDecoration(
            color: selected ? colors.accentYellow : colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? colors.accentYellow : colors.border,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          _tierName(context, product.plan.tier),
                          style: TextStyle(
                            color: selected
                                ? AppColors.black
                                : colors.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
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

  String _tierName(BuildContext context, SubscriptionTier tier) {
    return switch (tier) {
      SubscriptionTier.mini => context.l10n.subscriptionTierMini,
      SubscriptionTier.plus => context.l10n.subscriptionTierPlus,
      SubscriptionTier.pro => context.l10n.subscriptionTierPro,
    };
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
