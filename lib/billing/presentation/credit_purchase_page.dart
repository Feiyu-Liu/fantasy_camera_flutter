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
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 800,
            child: _PurchaseHeroBackground(),
          ),
          Column(
            children: <Widget>[
              _PurchaseHeroContent(topInset: topInset),
              Expanded(
                child: CustomScrollView(
                  physics: const _TopBouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: <Widget>[
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Container(
                        color: colors.background,
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: _EmptyPurchaseState(
                                  onRetry: () {
                                    ref
                                        .read(
                                          billingControllerProvider.notifier,
                                        )
                                        .loadProducts();
                                  },
                                ),
                              )
                            else ...<Widget>[
                              for (final BillingProduct product
                                  in state.products)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    12,
                                  ),
                                  child: _CreditPackRow(
                                    product: product,
                                    isBusy: state.isPurchasing,
                                    isSelected:
                                        product.productId == selectedProductId,
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _selectedProductId = product.productId;
                                      });
                                      ref
                                          .read(
                                            billingControllerProvider.notifier,
                                          )
                                          .clearPurchaseSuccess();
                                    },
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: _PurchaseButton(
                                  isBusy: state.isPurchasing,
                                  grantedCredits: state.purchaseSuccessCredits,
                                  onPressed: selectedProduct == null
                                      ? null
                                      : () {
                                          HapticFeedback.selectionClick();
                                          ref
                                              .read(
                                                billingControllerProvider
                                                    .notifier,
                                              )
                                              .purchase(selectedProduct);
                                        },
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: _PurchaseFooterLinks(
                                isBusy: state.isPurchasing,
                                onRestorePressed: () {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(billingControllerProvider.notifier)
                                      .restore();
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
                      ),
                    ),
                  ],
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

class _Star {
  _Star({
    required this.x,
    required this.y,
    required this.delay,
    required this.duration,
    required this.targetOpacity,
    required this.twinklePhase,
    required this.twinkleSpeed,
  });
  final double x;
  final double y;
  final double delay;
  final double duration;
  final double targetOpacity;
  final double twinklePhase;
  final double twinkleSpeed;
}

class _PurchaseHeroBackground extends StatefulWidget {
  const _PurchaseHeroBackground();

  @override
  State<_PurchaseHeroBackground> createState() =>
      _PurchaseHeroBackgroundState();
}

class _PurchaseHeroBackgroundState extends State<_PurchaseHeroBackground>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _twinkleController;
  List<_Star>? _stars;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();

    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stars == null) {
      _generateStars(MediaQuery.of(context).size.width, 800);
    }
  }

  void _generateStars(double width, double height) {
    _stars = [];
    final Random rnd = Random();
    const double cellSize = 60.0; // 控制星星密度，类似 Poisson Disk Sampling，防止扎堆

    for (double x = 0; x < width; x += cellSize) {
      for (double y = 0; y < height; y += cellSize) {
        // 在网格内加上一点安全边距随机生成位置
        final double dotX = x + 5 + rnd.nextDouble() * (cellSize - 10);
        final double dotY = y + 5 + rnd.nextDouble() * (cellSize - 10);

        final double delay = rnd.nextDouble() * 0.75; // 进场延迟
        final double duration = 0.2 + rnd.nextDouble() * 0.2; // 进场时长
        final double targetOpacity = 0.4 + rnd.nextDouble() * 0.6; // 最终透明度
        final double twinklePhase = rnd.nextDouble() * 2 * pi; // 闪烁相位

        // 修复突变问题：速度必须是整数！
        // 因为底层动画是 8 秒一循环（0.0 -> 1.0），当进度突变回 0.0 时，
        // 如果速度不是整数，正弦波的波峰/波谷就会断裂。
        // 设置为 1, 2, 3，代表在 8 秒内正好呼吸 1 次、2 次或 3 次，保证首尾无缝衔接。
        final double twinkleSpeed = (1 + rnd.nextInt(3)).toDouble();

        _stars!.add(
          _Star(
            x: dotX,
            y: dotY,
            delay: delay,
            duration: duration,
            targetOpacity: targetOpacity,
            twinklePhase: twinklePhase,
            twinkleSpeed: twinkleSpeed,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _twinkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: <double>[0.0, 0.5, 1.0],
          colors: <Color>[
            Color(0xFF0A0A1A), // 顶部依然保持深邃的暗黑蓝色
            Color(0xFF222255), // 中间过渡色调亮
            Color(0xFF404085), // 底部（浅蓝色）显著调浅
          ],
        ),
      ),
      child: CustomPaint(
        painter: _StarryBackgroundPainter(
          stars: _stars!,
          entranceAnimation: _entranceController,
          twinkleAnimation: _twinkleController,
        ),
      ),
    );
  }
}

class _PurchaseHeroContent extends StatelessWidget {
  const _PurchaseHeroContent({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}

class _StarryBackgroundPainter extends CustomPainter {
  _StarryBackgroundPainter({
    required this.stars,
    required this.entranceAnimation,
    required this.twinkleAnimation,
  }) : super(
         repaint: Listenable.merge(<Listenable>[
           entranceAnimation,
           twinkleAnimation,
         ]),
       );

  final List<_Star> stars;
  final Animation<double> entranceAnimation;
  final Animation<double> twinkleAnimation;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (final _Star star in stars) {
      double entranceOpacity = 0.0;
      if (entranceAnimation.value > star.delay) {
        entranceOpacity =
            (entranceAnimation.value - star.delay) / star.duration;
        if (entranceOpacity > 1.0) entranceOpacity = 1.0;
        entranceOpacity = Curves.easeInOutSine.transform(entranceOpacity);
      }

      // 如果还没开始进场，跳过绘制
      if (entranceOpacity <= 0) continue;

      // 连续闪烁逻辑：利用正弦波，映射到 0.4x 到 1.0x 的透明度变化
      final double twinkle =
          (sin(
                twinkleAnimation.value * 2 * pi * star.twinkleSpeed +
                    star.twinklePhase,
              ) +
              1) /
          2;

      // 综合透明度 = 进场进度 * 基础目标透明度 * 闪烁波动
      final double finalOpacity =
          star.targetOpacity * entranceOpacity * (0.4 + 0.6 * twinkle);

      paint.color = const Color(0xFFFFFFFF).withValues(alpha: finalOpacity);
      canvas.drawCircle(Offset(star.x, star.y), 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarryBackgroundPainter oldDelegate) {
    return oldDelegate.stars != stars ||
        oldDelegate.entranceAnimation != entranceAnimation ||
        oldDelegate.twinkleAnimation != twinkleAnimation;
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

class _TopBouncingScrollPhysics extends BouncingScrollPhysics {
  const _TopBouncingScrollPhysics({super.parent});

  @override
  _TopBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _TopBouncingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double frictionFactor(double overscrollFraction) {
    // 默认是 0.52，调到 0.3 会让下拉显得更加“紧绷”，下拉幅度变小
    return 0.3 * pow(1 - overscrollFraction, 2);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value > position.maxScrollExtent &&
        position.maxScrollExtent >= position.minScrollExtent) {
      if (position.pixels >= position.maxScrollExtent) {
        return value - position.pixels;
      }
      return value - position.maxScrollExtent;
    }
    return super.applyBoundaryConditions(position, value);
  }
}
