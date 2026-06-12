import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../domain/billing_product.dart';
import 'billing_providers.dart';

class CreditPurchasePage extends ConsumerStatefulWidget {
  const CreditPurchasePage({super.key});

  @override
  ConsumerState<CreditPurchasePage> createState() => _CreditPurchasePageState();
}

class _CreditPurchasePageState extends ConsumerState<CreditPurchasePage> {
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
    return CupertinoPageScaffold(
      backgroundColor: AppColors.settingsBackground,
      child: Stack(
        children: <Widget>[
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset + 74, 16, 24),
            physics: const BouncingScrollPhysics(),
            children: <Widget>[
              const _PurchaseHero(),
              const SizedBox(height: 24),
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: CupertinoActivityIndicator(color: AppColors.black),
                  ),
                )
              else if (state.products.isEmpty)
                _EmptyPurchaseState(
                  onRetry: () {
                    ref.read(billingControllerProvider.notifier).loadProducts();
                  },
                )
              else
                for (final BillingProduct product in state.products)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CreditPackRow(
                      product: product,
                      isBusy: state.isPurchasing,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(billingControllerProvider.notifier)
                            .purchase(product);
                      },
                    ),
                  ),
              const SizedBox(height: 8),
              _RestoreButton(
                isBusy: state.isPurchasing,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref.read(billingControllerProvider.notifier).restore();
                },
              ),
              if (state.errorMessage case final String message)
                _MessageBanner(message: message, danger: true),
              if (state.lastGrantedCredits case final int credits)
                _MessageBanner(
                  message: context.l10n.billingGrantedCreditsMessage(credits),
                  danger: false,
                ),
              const SizedBox(height: 28),
              const _LegalLinks(),
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.settingsBackground.withValues(alpha: 0.72),
            border: const Border(
              bottom: BorderSide(color: AppColors.black, width: 0.5),
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
                      child: const Icon(
                        CupertinoIcons.chevron_left,
                        color: AppColors.black,
                        size: 20,
                      ),
                    ),
                  ),
                  Text(
                    context.l10n.billingTitle,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      color: AppColors.black,
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.black, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(LucideIcons.tickets, color: AppColors.black, size: 28),
            const SizedBox(height: 18),
            Text(
              context.l10n.billingHeroTitle,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Times New Roman',
                fontSize: 36,
                fontWeight: FontWeight.w700,
                height: 0.92,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.billingHeroSubtitle,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                color: AppColors.settingsMutedText,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.25,
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
    required this.onPressed,
  });

  final BillingProduct product;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: isBusy ? null : onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.black, width: 0.5),
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
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.l10n.billingCreditPackSubtitle,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        color: AppColors.settingsMutedText,
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
                style: const TextStyle(
                  color: AppColors.black,
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

class _RestoreButton extends StatelessWidget {
  const _RestoreButton({required this.isBusy, required this.onPressed});

  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: isBusy ? null : onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          context.l10n.billingRestorePurchases,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            color: AppColors.black,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.black, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            Text(
              context.l10n.billingProductsUnavailable,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                color: AppColors.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              color: AppColors.black,
              minimumSize: Size.zero,
              onPressed: onRetry,
              child: Text(
                context.l10n.billingRetry,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(color: AppColors.white, fontSize: 13),
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
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message,
        textAlign: TextAlign.center,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: danger ? AppColors.danger : AppColors.black,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.l10n.billingLegalNote,
      textAlign: TextAlign.center,
      textScaler: TextScaler.noScaling,
      style: const TextStyle(
        color: AppColors.settingsMutedText,
        fontSize: 11,
        height: 1.35,
      ),
    );
  }
}
