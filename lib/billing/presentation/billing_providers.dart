import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../features/backend_api/presentation/backend_api_providers.dart';
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

class BillingControllerState {
  const BillingControllerState({
    this.products = const <BillingProduct>[],
    this.isLoading = false,
    this.isPurchasing = false,
    this.errorMessage,
    this.lastGrantedCredits,
  });

  final List<BillingProduct> products;
  final bool isLoading;
  final bool isPurchasing;
  final String? errorMessage;
  final int? lastGrantedCredits;

  BillingControllerState copyWith({
    List<BillingProduct>? products,
    bool? isLoading,
    bool? isPurchasing,
    String? errorMessage,
    bool clearErrorMessage = false,
    int? lastGrantedCredits,
    bool clearLastGrantedCredits = false,
  }) {
    return BillingControllerState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      lastGrantedCredits: clearLastGrantedCredits
          ? null
          : lastGrantedCredits ?? this.lastGrantedCredits,
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
      final List<CreditProduct> backendProducts = await ref
          .read(billingRepositoryProvider)
          .fetchProducts();
      final List<BillingProduct> revenueCatProducts = await ref
          .read(billingGatewayProvider)
          .fetchProducts();
      state = state.copyWith(
        isLoading: false,
        products: _mergeProducts(backendProducts, revenueCatProducts),
      );
    } on Object {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load credit packs.',
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
          errorMessage: 'Purchase failed. Please try again.',
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
      state = state.copyWith(
        isPurchasing: false,
        lastGrantedCredits: result.grantedCredits > 0
            ? result.grantedCredits
            : null,
      );
    } on Object {
      state = state.copyWith(
        isPurchasing: false,
        errorMessage: 'Purchase completed, but credits could not be synced.',
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
    );
    try {
      await ref.read(billingGatewayProvider).restorePurchases();
      final CreditPurchaseSyncResult result = await ref
          .read(billingRepositoryProvider)
          .syncRevenueCatPurchases();
      await ref
          .read(creditBalanceProvider.notifier)
          .refreshFromServer(userId: await _currentUserId());
      state = state.copyWith(
        isPurchasing: false,
        lastGrantedCredits: result.grantedCredits > 0
            ? result.grantedCredits
            : null,
      );
    } on Object {
      state = state.copyWith(
        isPurchasing: false,
        errorMessage: 'Restore failed. Please try again.',
      );
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
