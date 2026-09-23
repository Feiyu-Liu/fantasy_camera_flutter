import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../config/app_config.dart';
import '../../features/backend_api/domain/api_failure.dart';
import '../../features/backend_api/domain/credit_redemption.dart';
import '../../features/backend_api/presentation/backend_api_providers.dart';
import '../../shared/core/app_logger.dart';
import '../application/billing_catalog_loader.dart';
import '../application/subscription_catalog_loader.dart';
import '../data/billing_repositories.dart';
import '../data/revenuecat_billing_gateway.dart';
import '../data/subscription_billing_repository.dart';
import '../domain/billing_product.dart';
import '../domain/credit_product.dart';
import '../domain/subscription_billing.dart';

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

final billingCatalogRetryPolicyProvider = Provider<BillingCatalogRetryPolicy>(
  (Ref ref) => const BillingCatalogRetryPolicy(),
);

final billingCatalogDelayProvider = Provider<BillingCatalogDelay>(
  (Ref ref) => Future<void>.delayed,
);

final billingCatalogLoaderProvider = Provider<BillingCatalogLoader>(
  (Ref ref) {
    return BillingCatalogLoader(
      gateway: ref.watch(billingGatewayProvider),
      repository: ref.watch(billingRepositoryProvider),
      retryPolicy: ref.watch(billingCatalogRetryPolicyProvider),
      delay: ref.watch(billingCatalogDelayProvider),
    );
  },
  dependencies: <ProviderOrFamily>[
    billingGatewayProvider,
    billingRepositoryProvider,
    billingCatalogRetryPolicyProvider,
    billingCatalogDelayProvider,
  ],
);

final subscriptionStoreGatewayProvider = Provider<SubscriptionStoreGateway>((
  Ref ref,
) {
  final BillingGateway gateway = ref.watch(billingGatewayProvider);
  return gateway is SubscriptionStoreGateway
      ? gateway as SubscriptionStoreGateway
      : const NoopSubscriptionStoreGateway();
}, dependencies: <ProviderOrFamily>[billingGatewayProvider]);

final subscriptionBillingRepositoryProvider =
    Provider<SubscriptionBillingRepository>(
      (Ref ref) => WorkerSubscriptionBillingRepository(
        ref.watch(fantasyApiClientProvider),
      ),
      dependencies: <ProviderOrFamily>[
        accessTokenProvider,
        fantasyApiClientProvider,
      ],
    );

final subscriptionCatalogLoaderProvider = Provider<SubscriptionCatalogLoader>(
  (Ref ref) => SubscriptionCatalogLoader(
    gateway: ref.watch(subscriptionStoreGatewayProvider),
    repository: ref.watch(subscriptionBillingRepositoryProvider),
    offeringId: AppConfig.revenueCatSubscriptionOfferingId,
    retryPolicy: ref.watch(billingCatalogRetryPolicyProvider),
    delay: ref.watch(billingCatalogDelayProvider),
    allowLocalProducts: AppConfig.localSubscriptionCatalogEnabled,
  ),
  dependencies: <ProviderOrFamily>[
    subscriptionStoreGatewayProvider,
    subscriptionBillingRepositoryProvider,
    billingCatalogRetryPolicyProvider,
    billingCatalogDelayProvider,
  ],
);

final subscriptionBillingStatusProvider =
    AsyncNotifierProvider<
      SubscriptionBillingStatusController,
      SubscriptionBillingStatus
    >(
      SubscriptionBillingStatusController.new,
      dependencies: <ProviderOrFamily>[
        authSessionProvider,
        subscriptionBillingRepositoryProvider,
      ],
    );

final subscriptionPurchaseControllerProvider =
    NotifierProvider<SubscriptionPurchaseController, SubscriptionPurchaseState>(
      SubscriptionPurchaseController.new,
      dependencies: <ProviderOrFamily>[
        authSessionProvider,
        subscriptionCatalogLoaderProvider,
        subscriptionStoreGatewayProvider,
        subscriptionBillingStatusProvider,
        creditBalanceProvider,
      ],
    );

final billingControllerProvider =
    NotifierProvider<BillingController, BillingControllerState>(
      BillingController.new,
      dependencies: <ProviderOrFamily>[
        authSessionProvider,
        billingCatalogLoaderProvider,
        billingGatewayProvider,
        billingRepositoryProvider,
        creditBalanceProvider,
      ],
    );

final billingRevenueCatWarmupProvider = FutureProvider<void>((Ref ref) async {
  final String? userId = (await ref.watch(authSessionProvider.future)).user?.id;
  if (userId == null || userId.isEmpty) {
    return;
  }
  try {
    await ref.read(billingGatewayProvider).logIn(userId);
    appDebugLog('Billing', 'RevenueCat warmup completed');
  } on Object catch (error, stackTrace) {
    logAppError('billing_revenuecat_warmup_failed', error, stackTrace);
  }
});

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
    ref.invalidate(subscriptionBillingStatusProvider);
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
  int _productLoadGeneration = 0;

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
    final int loadGeneration = ++_productLoadGeneration;
    try {
      final String? userId = await _currentUserId();
      final List<BillingProduct> mergedProducts = await ref
          .read(billingCatalogLoaderProvider)
          .load(appUserId: userId);
      appDebugLog('Billing', 'products loaded merged=${mergedProducts.length}');
      state = state.copyWith(isLoading: false, products: mergedProducts);
      unawaited(_syncPurchasesAfterProductLoad(loadGeneration));
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

  Future<void> _syncPurchasesAfterProductLoad(int loadGeneration) async {
    try {
      final CreditPurchaseSyncResult result = await ref
          .read(billingRepositoryProvider)
          .syncRevenueCatPurchases();
      await ref
          .read(creditBalanceProvider.notifier)
          .refreshFromServer(userId: await _currentUserId());
      if (loadGeneration != _productLoadGeneration ||
          result.grantedCredits <= 0) {
        return;
      }
      state = state.copyWith(
        lastGrantedCredits: result.grantedCredits,
        purchaseSuccessCredits: result.grantedCredits,
      );
    } on Object catch (error, stackTrace) {
      logAppError(
        'billing_product_load_purchase_sync_failed',
        error,
        stackTrace,
      );
    }
  }

  Future<String?> _currentUserId() async {
    return ref.read(authSessionProvider).valueOrNull?.user?.id ??
        (await ref.read(authSessionProvider.future)).user?.id;
  }
}

class SubscriptionBillingStatusController
    extends AsyncNotifier<SubscriptionBillingStatus> {
  String? _userId;
  int _requestGeneration = 0;

  @override
  Future<SubscriptionBillingStatus> build() async {
    final String? userId = (await ref.watch(
      authSessionProvider.future,
    )).user?.id;
    if (userId == null || userId.isEmpty) {
      return Future<SubscriptionBillingStatus>.error(
        StateError('Sign in is required to load subscription status.'),
      );
    }
    _userId = userId;
    final int generation = ++_requestGeneration;
    final SubscriptionBillingStatus status = await ref
        .watch(subscriptionBillingRepositoryProvider)
        .fetchStatus();
    if (_userId != userId || generation != _requestGeneration) {
      return Future<SubscriptionBillingStatus>.error(
        StateError('Subscription status response was superseded.'),
      );
    }
    return status;
  }

  Future<SubscriptionBillingStatus?> refreshFromServer({bool sync = false}) {
    return _refresh(sync: sync);
  }

  Future<SubscriptionBillingStatus?> _refresh({required bool sync}) async {
    final String? userId = ref.read(authSessionProvider).valueOrNull?.user?.id;
    if (userId == null || userId.isEmpty) {
      return null;
    }
    _userId = userId;
    final int generation = ++_requestGeneration;
    final SubscriptionBillingStatus? previous = state.valueOrNull;
    if (previous == null) {
      state = const AsyncValue<SubscriptionBillingStatus>.loading();
    }
    try {
      final SubscriptionBillingRepository repository = ref.read(
        subscriptionBillingRepositoryProvider,
      );
      final SubscriptionBillingStatus next = sync
          ? await repository.syncRevenueCatPurchases()
          : await repository.fetchStatus();
      if (_userId != userId || generation != _requestGeneration) {
        return null;
      }
      state = AsyncValue<SubscriptionBillingStatus>.data(next);
      return next;
    } on Object catch (error, stackTrace) {
      if (_userId != userId || generation != _requestGeneration) {
        return null;
      }
      state = previous == null
          ? AsyncValue<SubscriptionBillingStatus>.error(error, stackTrace)
          : AsyncValue<SubscriptionBillingStatus>.data(previous);
      rethrow;
    }
  }
}

enum SubscriptionPurchaseErrorKind { loadProducts, purchase, restore }

enum SubscriptionPurchaseSuccess { purchase, restore }

class SubscriptionPurchaseState {
  const SubscriptionPurchaseState({
    this.products = const <SubscriptionProduct>[],
    this.isLoading = false,
    this.isPurchasing = false,
    this.isSyncPending = false,
    this.selectedProductId,
    this.errorKind,
    this.catalogStatus,
    this.lastSuccess,
    this.successSerial = 0,
  });

  final List<SubscriptionProduct> products;
  final bool isLoading;
  final bool isPurchasing;
  final bool isSyncPending;
  final String? selectedProductId;
  final SubscriptionPurchaseErrorKind? errorKind;
  final SubscriptionBillingStatus? catalogStatus;
  final SubscriptionPurchaseSuccess? lastSuccess;

  /// Bumped on every successful purchase or restore so listeners can react
  /// to repeated successes of the same kind.
  final int successSerial;

  SubscriptionPurchaseState copyWith({
    List<SubscriptionProduct>? products,
    bool? isLoading,
    bool? isPurchasing,
    bool? isSyncPending,
    String? selectedProductId,
    SubscriptionPurchaseErrorKind? errorKind,
    SubscriptionBillingStatus? catalogStatus,
    SubscriptionPurchaseSuccess? lastSuccess,
    int? successSerial,
    bool clearError = false,
  }) {
    return SubscriptionPurchaseState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isSyncPending: isSyncPending ?? this.isSyncPending,
      selectedProductId: selectedProductId ?? this.selectedProductId,
      errorKind: clearError ? null : errorKind ?? this.errorKind,
      catalogStatus: catalogStatus ?? this.catalogStatus,
      lastSuccess: lastSuccess ?? this.lastSuccess,
      successSerial: successSerial ?? this.successSerial,
    );
  }
}

class SubscriptionPurchaseController
    extends Notifier<SubscriptionPurchaseState> {
  @override
  SubscriptionPurchaseState build() => const SubscriptionPurchaseState();

  Future<void> loadProducts() async {
    if (state.isLoading) {
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final String? userId = await _currentUserId();
      final SubscriptionCatalog catalog = await ref
          .read(subscriptionCatalogLoaderProvider)
          .load(appUserId: userId);
      final String selectedProductId = _defaultProductId(catalog.products);
      state = state.copyWith(
        products: catalog.products,
        selectedProductId: selectedProductId,
        isLoading: false,
        catalogStatus: catalog.status,
      );
      unawaited(
        ref
            .read(subscriptionBillingStatusProvider.notifier)
            .refreshFromServer(),
      );
    } on Object catch (error, stackTrace) {
      logAppError('subscription_products_load_failed', error, stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorKind: SubscriptionPurchaseErrorKind.loadProducts,
      );
    }
  }

  void selectProduct(String productId) {
    if (state.isPurchasing) {
      return;
    }
    state = state.copyWith(selectedProductId: productId, clearError: true);
  }

  Future<void> purchaseSelected() async {
    if (state.isPurchasing) {
      return;
    }
    final SubscriptionProduct? product = state.products
        .where(
          (SubscriptionProduct value) =>
              value.storeProduct.productId == state.selectedProductId,
        )
        .firstOrNull;
    if (product == null) {
      return;
    }
    state = state.copyWith(
      isPurchasing: true,
      isSyncPending: false,
      clearError: true,
    );
    final BillingPurchaseOutcome outcome = await ref
        .read(subscriptionStoreGatewayProvider)
        .purchaseProduct(product.storeProduct);
    switch (outcome) {
      case BillingPurchaseCancelled():
        state = state.copyWith(isPurchasing: false);
        return;
      case BillingPurchaseFailed():
        state = state.copyWith(
          isPurchasing: false,
          errorKind: SubscriptionPurchaseErrorKind.purchase,
        );
        return;
      case BillingPurchaseCompleted():
        await _syncAfterStoreChange(
          SubscriptionPurchaseErrorKind.purchase,
          SubscriptionPurchaseSuccess.purchase,
        );
    }
  }

  Future<void> restore() async {
    if (state.isPurchasing) {
      return;
    }
    state = state.copyWith(
      isPurchasing: true,
      isSyncPending: false,
      clearError: true,
    );
    try {
      final String? userId = await _currentUserId();
      if (userId != null && userId.isNotEmpty) {
        await ref.read(subscriptionStoreGatewayProvider).logIn(userId);
      }
      await ref.read(subscriptionStoreGatewayProvider).restorePurchases();
      await _syncAfterStoreChange(
        SubscriptionPurchaseErrorKind.restore,
        SubscriptionPurchaseSuccess.restore,
      );
    } on Object catch (error, stackTrace) {
      logAppError('subscription_restore_failed', error, stackTrace);
      state = state.copyWith(
        isPurchasing: false,
        errorKind: SubscriptionPurchaseErrorKind.restore,
      );
    }
  }

  Future<void> _syncAfterStoreChange(
    SubscriptionPurchaseErrorKind errorKind,
    SubscriptionPurchaseSuccess successKind,
  ) async {
    try {
      await ref
          .read(subscriptionBillingStatusProvider.notifier)
          .refreshFromServer(sync: true);
      ref.invalidate(creditBalanceProvider);
      state = state.copyWith(
        isPurchasing: false,
        isSyncPending: false,
        lastSuccess: successKind,
        successSerial: state.successSerial + 1,
      );
    } on BackendApiFailure catch (error) {
      if (error.code == 'billing_sync_pending') {
        state = state.copyWith(isPurchasing: false, isSyncPending: true);
        return;
      }
      state = state.copyWith(isPurchasing: false, errorKind: errorKind);
    } on Object catch (error, stackTrace) {
      logAppError('subscription_sync_failed', error, stackTrace);
      state = state.copyWith(isPurchasing: false, errorKind: errorKind);
    }
  }

  String _defaultProductId(List<SubscriptionProduct> products) {
    for (final SubscriptionProduct product in products) {
      if (product.plan.tier == SubscriptionTier.plus) {
        return product.storeProduct.productId;
      }
    }
    return products.first.storeProduct.productId;
  }

  Future<String?> _currentUserId() async {
    return ref.read(authSessionProvider).valueOrNull?.user?.id ??
        (await ref.read(authSessionProvider.future)).user?.id;
  }
}
