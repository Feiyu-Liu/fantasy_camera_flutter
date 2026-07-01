import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../../shared/toast/app_toast.dart';
import '../../theme/app_corners.dart';
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
    ref.listen<BillingControllerState>(billingControllerProvider, (
      BillingControllerState? previous,
      BillingControllerState next,
    ) {
      final AppToastService toastService = ref.read(appToastServiceProvider);
      final AppLocalizations l10n = context.l10n;
      final int? purchaseSuccessCredits = next.purchaseSuccessCredits;
      if (purchaseSuccessCredits != null &&
          purchaseSuccessCredits != previous?.purchaseSuccessCredits) {
        toastService.showPurchaseSuccess(l10n, purchaseSuccessCredits);
      }

      final String? errorMessage = next.errorMessage;
      if (errorMessage == null ||
          (previous?.errorMessage == errorMessage &&
              previous?.errorKind == next.errorKind)) {
        return;
      }
      switch (next.errorKind) {
        case BillingErrorKind.purchase:
          toastService.showPurchaseFailure(l10n);
        case BillingErrorKind.restore:
          toastService.showRestorePurchaseFailure(l10n);
        case BillingErrorKind.loadProducts:
        case null:
          break;
      }
    });
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
            padding: const EdgeInsets.only(bottom: 24),
            physics: const BouncingScrollPhysics(),
            children: <Widget>[
              _PurchaseHero(topInset: topInset),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _EmptyPurchaseState(
                    onRetry: () {
                      ref.read(billingControllerProvider.notifier).loadProducts();
                    },
                  ),
                )
              else ...<Widget>[
                for (final BillingProduct product in state.products)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _CreditPackRow(
                      product: product,
                      isBusy: state.isPurchasing,
                      isSelected: product.productId == selectedProductId,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedProductId = product.productId;
                        });
                        ref
                            .read(billingControllerProvider.notifier)
                            .clearPurchaseSuccess();
                      },
                    ),
                  ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _PurchaseButton(
                    isBusy: state.isPurchasing,
                    grantedCredits: state.purchaseSuccessCredits,
                    onPressed: selectedProduct == null
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(billingControllerProvider.notifier)
                                .purchase(selectedProduct);
                          },
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PurchaseFooterLinks(
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1123).withValues(alpha: 0.8),
            border: const Border(
              bottom: BorderSide(color: Color(0xFF1D203D), width: 0.5),
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
                        color: Color(0xFFFFFFFF),
                        size: 20,
                      ),
                    ),
                  ),
                  Text(
                    context.l10n.billingTitle,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
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
  const _PurchaseHero({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: <double>[0.0, 0.5, 1.0],
          colors: <Color>[
            Color(0xFF0A0A1A),
            Color(0xFF1A1A3E),
            Color(0xFF2A2A5A),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: CustomPaint(
              painter: _StarryBackgroundPainter(),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 50 + 56, 16, 64),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x00000000),
                    border: Border.all(
                      color: const Color(0xFFFFFFFF).withValues(alpha: 0.4),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const SizedBox(
                    width: 76,
                    height: 76,
                    child: Center(
                      child: Icon(
                        LucideIcons.star,
                        color: Color(0xFFFFFFFF),
                        size: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.billingHeroTitle,
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    context.l10n.billingHeroSubtitle,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: const Color(0xFFFFFFFF).withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.1,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarryBackgroundPainter extends CustomPainter {
  const _StarryBackgroundPainter();

  static const List<Offset> _dotPositions = <Offset>[
    Offset(20, 30),
    Offset(40, 70),
    Offset(50, 160),
    Offset(90, 40),
    Offset(130, 80),
    Offset(160, 120),
    Offset(180, 10),
    Offset(30, 100),
    Offset(80, 160),
    Offset(140, 140),
    Offset(50, 50),
    Offset(110, 20),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    const double tileSize = 200.0;
    
    for (double x = 0; x < size.width; x += tileSize) {
      for (double y = 0; y < size.height; y += tileSize) {
        for (final Offset pos in _dotPositions) {
          final double dotX = x + pos.dx;
          final double dotY = y + pos.dy;
          if (dotX <= size.width && dotY <= size.height) {
            canvas.drawCircle(Offset(dotX, dotY), 1.0, paint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarryBackgroundPainter oldDelegate) => false;
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
        decoration: AppCorners.controlDecoration(
          color: isSelected ? colors.accentYellow : colors.surface,
          side: BorderSide(color: colors.border, width: 0.5),
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
  const _PurchaseButton({
    required this.isBusy,
    required this.grantedCredits,
    required this.onPressed,
  });

  final bool isBusy;
  final int? grantedCredits;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    final int? successCredits = grantedCredits;
    final bool isSuccess = successCredits != null;
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
                ? CupertinoActivityIndicator(color: colors.inverseText)
                : Text(
                    isSuccess
                        ? context.l10n.billingPurchaseSuccessButton(
                            successCredits,
                          )
                        : context.l10n.billingPurchaseButton,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: AppColors.white,
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
      decoration: AppCorners.controlDecoration(
        color: colors.surface,
        side: BorderSide(color: colors.border, width: 0.5),
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
