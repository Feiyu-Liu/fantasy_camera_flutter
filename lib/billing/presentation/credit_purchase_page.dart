import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../domain/billing_product.dart';
import 'billing_providers.dart';

class CreditPurchasePage extends ConsumerStatefulWidget {
  const CreditPurchasePage({super.key});

  @override
  ConsumerState<CreditPurchasePage> createState() => _CreditPurchasePageState();
}

class _CreditPurchasePageState extends ConsumerState<CreditPurchasePage> {
  String? _selectedProductId;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() {
      ref.read(billingControllerProvider.notifier).loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final BillingControllerState state = ref.watch(billingControllerProvider);
    final double topInset = MediaQuery.paddingOf(context).top;
    final BillingProduct? selectedProduct = state.products.isEmpty
        ? null
        : state.products.firstWhere(
            (BillingProduct product) => product.productId == _selectedProductId,
            orElse: () => state.products.first,
          );
    final String? selectedProductId = selectedProduct?.productId;
    final AppThemeColors colors = AppThemeColors.of(context);
    return CupertinoPageScaffold(
      backgroundColor: colors.background,
      child: Stack(
        children: <Widget>[
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset + 74, 16, 24),
            physics: const BouncingScrollPhysics(),
            children: <Widget>[
              const _PurchaseHero(),
              const SizedBox(height: 24),
              if (state.isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: CupertinoActivityIndicator(
                      color: colors.textPrimary,
                    ),
                  ),
                )
              else if (state.products.isEmpty)
                _EmptyPurchaseState(
                  onRetry: () {
                    ref.read(billingControllerProvider.notifier).loadProducts();
                  },
                )
              else ...<Widget>[
                for (final BillingProduct product in state.products)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CreditPackRow(
                      product: product,
                      isBusy: state.isPurchasing,
                      isSelected: product.productId == selectedProductId,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedProductId = product.productId;
                        });
                      },
                    ),
                  ),
                const SizedBox(height: 2),
                _PurchaseButton(
                  isBusy: state.isPurchasing,
                  onPressed: selectedProduct == null
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(billingControllerProvider.notifier)
                              .purchase(selectedProduct);
                        },
                ),
              ],
              if (state.errorMessage case final String message)
                _MessageBanner(message: message, danger: true),
              if (state.lastGrantedCredits case final int credits)
                _MessageBanner(
                  message: context.l10n.billingGrantedCreditsMessage(credits),
                  danger: false,
                ),
              const SizedBox(height: 10),
              _PurchaseFooterLinks(
                isBusy: state.isPurchasing,
                onRestorePressed: () {
                  HapticFeedback.selectionClick();
                  ref.read(billingControllerProvider.notifier).restore();
                },
                onPrivacyPressed: () {
                  HapticFeedback.selectionClick();
                },
                onTermsPressed: () {
                  HapticFeedback.selectionClick();
                },
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _PurchaseNavigationBar(
              topInset: topInset,
              onBackPressed: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseNavigationBar extends StatelessWidget {
  const _PurchaseNavigationBar({
    required this.topInset,
    required this.onBackPressed,
  });

  final double topInset;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.navBlurBackground,
            border: Border(
              bottom: BorderSide(color: colors.border, width: 0.5),
            ),
          ),
          child: SizedBox(
            height: topInset + 50,
            child: Padding(
              padding: EdgeInsets.only(top: topInset),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned(
                    left: 12,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      onPressed: onBackPressed,
                      child: Icon(
                        CupertinoIcons.chevron_left,
                        color: colors.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                  Text(
                    context.l10n.billingTitle,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseHero extends StatelessWidget {
  const _PurchaseHero();

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.fromBorderSide(
                  BorderSide(color: colors.border, width: 1),
                ),
              ),
              child: SizedBox(
                width: 92,
                height: 92,
                child: Center(
                  child: Icon(
                    LucideIcons.star,
                    color: colors.textPrimary,
                    size: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              context.l10n.billingHeroTitle,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditPackRow extends StatelessWidget {
  const _CreditPackRow({
    required this.product,
    required this.isBusy,
    required this.isSelected,
    required this.onPressed,
  });

  final BillingProduct product;
  final bool isBusy;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: isBusy ? null : onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentYellow : colors.surface,
          border: Border.all(color: colors.border, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 15, 16, 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.billingCreditPackTitle(product.credits),
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.black
                            : colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.l10n.billingCreditPackSubtitle,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.black.withValues(alpha: 0.72)
                            : colors.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                product.price,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: isSelected ? AppColors.black : colors.textPrimary,
                  fontSize: 15,
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

class _PurchaseButton extends StatelessWidget {
  const _PurchaseButton({required this.isBusy, required this.onPressed});

  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: isBusy ? null : onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isBusy || onPressed == null
              ? colors.controlFillDisabled
              : colors.textPrimary,
          border: Border.all(color: colors.border, width: 0.5),
        ),
        child: SizedBox(
          height: 52,
          child: Center(
            child: isBusy
                ? CupertinoActivityIndicator(color: colors.inverseText)
                : Text(
                    context.l10n.billingPurchaseButton,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: colors.inverseText,
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

class _PurchaseFooterLinks extends StatelessWidget {
  const _PurchaseFooterLinks({
    required this.isBusy,
    required this.onRestorePressed,
    required this.onPrivacyPressed,
    required this.onTermsPressed,
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

class _EmptyPurchaseState extends StatelessWidget {
  const _EmptyPurchaseState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            Text(
              context.l10n.billingProductsUnavailable,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              color: colors.textPrimary,
              minimumSize: Size.zero,
              onPressed: onRetry,
              child: Text(
                context.l10n.billingRetry,
                textScaler: TextScaler.noScaling,
                style: TextStyle(color: colors.inverseText, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.danger});

  final String message;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message,
        textAlign: TextAlign.center,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: danger ? AppColors.danger : colors.textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
