import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../config/app_config.dart';
import '../../features/backend_api/domain/api_failure.dart';
import '../../features/backend_api/domain/credit_redemption.dart';
import '../../features/backend_api/presentation/backend_api_providers.dart';
import '../../shared/core/app_logger.dart';
import '../data/billing_repositories.dart';
import '../data/revenuecat_billing_gateway.dart';
import '../domain/billing_product.dart';
import '../domain/credit_product.dart';

final billingGatewayProvider = Provider<BillingGateway>((Ref ref) {
  final BillingGateway gateway = buildBillingGateway();
  ref.onDispose(() {
    unawaited(gateway.logOut());
  });
  return gateway;
});

final billingRepositoryProvider = Provider<BillingRepository>(
  (Ref ref) {
    return WorkerBillingRepository(ref.watch(fantasyApiClientProvider));
  },
  dependencies: <ProviderOrFamily>[
    accessTokenProvider,
    fantasyApiClientProvider,
  ],
);

final billingControllerProvider =
    NotifierProvider<BillingController, BillingControllerState>(
      BillingController.new,
      dependencies: <ProviderOrFamily>[
        authSessionProvider,
        billingGatewayProvider,
        billingRepositoryProvider,
        creditBalanceProvider,
      ],
    );

final billingStartupPurchaseRecoveryEnabledProvider = Provider<bool>(
  (Ref ref) => AppConfig.workerApiBaseUrl.isNotEmpty,
);

final billingStartupPurchaseRecoveryProvider = FutureProvider<void>((
  Ref ref,
) async {
  if (!ref.watch(billingStartupPurchaseRecoveryEnabledProvider)) {
    return;
  }
  final String? userId = (await ref.watch(authSessionProvider.future)).user?.id;
  if (userId == null || userId.isEmpty) {
    return;
  }

  try {
    final CreditPurchaseSyncResult result = await ref
        .read(billingRepositoryProvider)
        .syncRevenueCatPurchases();
    final balance = await ref.read(creditsRepositoryProvider).fetchBalance();
    await ref
        .read(creditBalanceCacheRepositoryProvider)
        .saveBalance(userId, balance);
    ref.invalidate(creditBalanceProvider);
    appDebugLog(
      'Billing',
      'startup purchase recovery sync processed=${result.processedPurchases} '
          'granted=${result.grantedCredits}',
    );
  } on Object catch (error, stackTrace) {
    logAppError('billing_startup_purchase_recovery_failed', error, stackTrace);
  }
});

final creditRedemptionControllerProvider =
    NotifierProvider<CreditRedemptionController, CreditRedemptionState>(
      CreditRedemptionController.new,
      dependencies: <ProviderOrFamily>[
        authSessionProvider,
        creditsRepositoryProvider,
        creditBalanceProvider,
      ],
    );

enum BillingErrorKind { loadProducts, purchase, restore }

class CreditRedemptionState {
  const CreditRedemptionState({
    this.code = '',
    this.isSubmitting = false,
    this.grantedCredits,
    this.errorCode,
    this.errorMessage,
  });

  final String code;
  final bool isSubmitting;
  final int? grantedCredits;
  final String? errorCode;
  final String? errorMessage;

  bool get canSubmit => code.trim().isNotEmpty && !isSubmitting;

  CreditRedemptionState copyWith({
    String? code,
    bool? isSubmitting,
    int? grantedCredits,
    bool clearGrantedCredits = false,
    String? errorCode,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CreditRedemptionState(
      code: code ?? this.code,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      grantedCredits: clearGrantedCredits
          ? null
          : grantedCredits ?? this.grantedCredits,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class CreditRedemptionController extends Notifier<CreditRedemptionState> {
  @override
  CreditRedemptionState build() {
    return const CreditRedemptionState();
  }

  void setCode(String code) {
    state = state.copyWith(
      code: code.toUpperCase(),
      clearError: true,
      clearGrantedCredits: true,
    );
  }

  void reset() {
    state = const CreditRedemptionState();
  }

  Future<void> redeem() async {
    final String code = state.code.trim();
    if (code.isEmpty || state.isSubmitting) {
      return;
    }
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearGrantedCredits: true,
    );
    try {
      final CreditRedemptionResult result = await ref
          .read(creditsRepositoryProvider)
          .redeemCode(code);
      await ref
          .read(creditBalanceProvider.notifier)
          .refreshFromServer(userId: await _currentUserId());
      state = state.copyWith(
        code: '',
        isSubmitting: false,
        grantedCredits: result.grantedCredits > 0
            ? result.grantedCredits
            : null,
      );
    } on BackendApiFailure catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorCode: error.code,
        errorMessage: error.message,
      );
    } on Object catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorCode: 'redemption_failed',
        errorMessage: error.toString(),
      );
    }
  }

  void clearSuccess() {
    if (state.grantedCredits == null) {
      return;
    }
    state = state.copyWith(clearGrantedCredits: true);
  }

  Future<String?> _currentUserId() async {
    return ref.read(authSessionProvider).valueOrNull?.user?.id ??
        (await ref.read(authSessionProvider.future)).user?.id;
  }
}

class BillingControllerState {
  const BillingControllerState({
    this.products = const <BillingProduct>[],
    this.isLoading = false,
    this.isPurchasing = false,
    this.errorMessage,
    this.errorKind,
    this.lastGrantedCredits,
    this.purchaseSuccessCredits,
    this.restoreFeedbackCredits,
  });

  final List<BillingProduct> products;
  final bool isLoading;
  final bool isPurchasing;
  final String? errorMessage;
  final BillingErrorKind? errorKind;
  final int? lastGrantedCredits;
  final int? purchaseSuccessCredits;
  final int? restoreFeedbackCredits;

  BillingControllerState copyWith({
    List<BillingProduct>? products,
    bool? isLoading,
    bool? isPurchasing,
    String? errorMessage,
    BillingErrorKind? errorKind,
    bool clearErrorMessage = false,
    int? lastGrantedCredits,
    bool clearLastGrantedCredits = false,
    int? purchaseSuccessCredits,
    bool clearPurchaseSuccessCredits = false,
    int? restoreFeedbackCredits,
    bool clearRestoreFeedbackCredits = false,
  }) {
    return BillingControllerState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      errorKind: clearErrorMessage ? null : errorKind ?? this.errorKind,
      lastGrantedCredits: clearLastGrantedCredits
          ? null
          : lastGrantedCredits ?? this.lastGrantedCredits,
      purchaseSuccessCredits: clearPurchaseSuccessCredits
          ? null
          : purchaseSuccessCredits ?? this.purchaseSuccessCredits,
      restoreFeedbackCredits: clearRestoreFeedbackCredits
          ? null
          : restoreFeedbackCredits ?? this.restoreFeedbackCredits,
    );
  }
}

class BillingController extends Notifier<BillingControllerState> {
  @override
  BillingControllerState build() {
    return const BillingControllerState();
  }

  Future<void> loadProducts() async {
    if (state.isLoading) {
      return;
    }
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearLastGrantedCredits: true,
      clearPurchaseSuccessCredits: true,
      clearRestoreFeedbackCredits: true,
    );
    try {
      final String? userId = ref
          .read(authSessionProvider)
          .valueOrNull
          ?.user
          ?.id;
      if (userId != null && userId.isNotEmpty) {
        await ref.read(billingGatewayProvider).logIn(userId);
      }
      final CreditPurchaseSyncResult? recoveredPurchases =
          await _syncRevenueCatPurchasesBestEffort();
      final List<CreditProduct> backendProducts = await ref
          .read(billingRepositoryProvider)
          .fetchProducts();
      final List<BillingProduct> revenueCatProducts = await ref
          .read(billingGatewayProvider)
          .fetchProducts();
      final List<BillingProduct> mergedProducts = _mergeProducts(
        backendProducts,
        revenueCatProducts,
      );
      appDebugLog(
        'Billing',
        'products loaded backend=${backendProducts.length} '
            'revenueCat=${revenueCatProducts.length} merged=${mergedProducts.length}',
      );
      state = state.copyWith(
        isLoading: false,
        products: mergedProducts,
        lastGrantedCredits:
            recoveredPurchases != null && recoveredPurchases.grantedCredits > 0
            ? recoveredPurchases.grantedCredits
            : null,
        purchaseSuccessCredits:
            recoveredPurchases != null && recoveredPurchases.grantedCredits > 0
            ? recoveredPurchases.grantedCredits
            : null,
      );
    } on Object catch (error, stackTrace) {
      logAppError('billing_products_load_failed', error, stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'billing_products_load_failed',
        errorKind: BillingErrorKind.loadProducts,
      );
    }
  }

  Future<void> purchase(BillingProduct product) async {
    if (state.isPurchasing) {
      return;
    }
    state = state.copyWith(
      isPurchasing: true,
      clearErrorMessage: true,
      clearLastGrantedCredits: true,
      clearPurchaseSuccessCredits: true,
      clearRestoreFeedbackCredits: true,
    );
    final BillingPurchaseOutcome outcome = await ref
        .read(billingGatewayProvider)
        .purchaseProduct(product);
    switch (outcome) {
      case BillingPurchaseCancelled():
        state = state.copyWith(isPurchasing: false, clearErrorMessage: true);
        return;
      case BillingPurchaseFailed():
        state = state.copyWith(
          isPurchasing: false,
          errorMessage: 'billing_purchase_failed',
          errorKind: BillingErrorKind.purchase,
        );
        return;
      case BillingPurchaseCompleted():
        break;
    }

    try {
      final CreditPurchaseSyncResult result = await ref
          .read(billingRepositoryProvider)
          .syncRevenueCatPurchases();
      await ref
          .read(creditBalanceProvider.notifier)
          .refreshFromServer(userId: await _currentUserId());
      final int? purchaseSuccessCredits = result.grantedCredits > 0
          ? result.grantedCredits
          : product.credits > 0
          ? product.credits
          : null;
      appDebugLog(
        'Billing',
        'purchase sync completed product=${product.productId} '
            'processed=${result.processedPurchases} granted=${result.grantedCredits} '
            'feedbackCredits=${purchaseSuccessCredits ?? 0}',
      );
      state = state.copyWith(
        isPurchasing: false,
        lastGrantedCredits: result.grantedCredits > 0
            ? result.grantedCredits
            : null,
        purchaseSuccessCredits: purchaseSuccessCredits,
      );
    } on Object {
      state = state.copyWith(
        isPurchasing: false,
        errorMessage: 'billing_purchase_sync_failed',
        errorKind: BillingErrorKind.purchase,
      );
    }
  }

  Future<void> restore() async {
    if (state.isPurchasing) {
      return;
    }
    state = state.copyWith(
      isPurchasing: true,
      clearErrorMessage: true,
      clearLastGrantedCredits: true,
      clearPurchaseSuccessCredits: true,
      clearRestoreFeedbackCredits: true,
    );
    try {
      final String? userId = await _currentUserId();
      if (userId != null && userId.isNotEmpty) {
        await ref.read(billingGatewayProvider).logIn(userId);
      }
      await ref.read(billingGatewayProvider).restorePurchases();
      final CreditPurchaseSyncResult result = await ref
          .read(billingRepositoryProvider)
          .syncRevenueCatPurchases();
      await ref
          .read(creditBalanceProvider.notifier)
          .refreshFromServer(userId: userId);
      appDebugLog(
        'Billing',
        'restore sync completed processed=${result.processedPurchases} '
            'granted=${result.grantedCredits}',
      );
      state = state.copyWith(
        isPurchasing: false,
        lastGrantedCredits: result.grantedCredits > 0
            ? result.grantedCredits
            : null,
        restoreFeedbackCredits: result.grantedCredits,
      );
    } on Object catch (error, stackTrace) {
      logAppError('billing_restore_failed', error, stackTrace);
      state = state.copyWith(
        isPurchasing: false,
        errorMessage: 'billing_restore_failed',
        errorKind: BillingErrorKind.restore,
      );
    }
  }

  void clearPurchaseSuccess() {
    if (state.purchaseSuccessCredits == null) {
      return;
    }
    state = state.copyWith(clearPurchaseSuccessCredits: true);
  }

  Future<CreditPurchaseSyncResult?> _syncRevenueCatPurchasesBestEffort() async {
    try {
      final CreditPurchaseSyncResult result = await ref
          .read(billingRepositoryProvider)
          .syncRevenueCatPurchases();
      await ref
          .read(creditBalanceProvider.notifier)
          .refreshFromServer(userId: await _currentUserId());
      return result;
    } on Object {
      return null;
    }
  }

  List<BillingProduct> _mergeProducts(
    List<CreditProduct> backendProducts,
    List<BillingProduct> revenueCatProducts,
  ) {
    final Map<String, CreditProduct> backendById = <String, CreditProduct>{
      for (final CreditProduct product in backendProducts)
        product.productId: product,
    };
    return revenueCatProducts
        .where(
          (BillingProduct product) =>
              backendById.containsKey(product.productId),
        )
        .map((BillingProduct product) {
          return product.copyWithCreditProduct(backendById[product.productId]!);
        })
        .toList(growable: false)
      ..sort(
        (BillingProduct a, BillingProduct b) =>
            a.displayRank.compareTo(b.displayRank),
      );
  }

  Future<String?> _currentUserId() async {
    return ref.read(authSessionProvider).valueOrNull?.user?.id ??
        (await ref.read(authSessionProvider.future)).user?.id;
  }
}
