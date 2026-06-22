import 'package:fantasy_camera_flutter/auth/domain/auth_session_state.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_user.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_providers.dart';
import 'package:fantasy_camera_flutter/billing/data/billing_repositories.dart';
import 'package:fantasy_camera_flutter/billing/data/revenuecat_billing_gateway.dart';
import 'package:fantasy_camera_flutter/billing/domain/billing_product.dart';
import 'package:fantasy_camera_flutter/billing/domain/credit_product.dart';
import 'package:fantasy_camera_flutter/billing/presentation/billing_providers.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/credit_balance_cache_repository.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/credit_balance.dart';
import 'package:fantasy_camera_flutter/features/backend_api/presentation/backend_api_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loadProducts logs in and merges backend credit metadata', () async {
    final _FakeBillingGateway gateway = _FakeBillingGateway(
      products: const <BillingProduct>[
        BillingProduct(
          productId: 'tessercam_credits_100',
          credits: 0,
          displayRank: 999,
          price: r'$9.99',
          packageIdentifier: r'$rc_custom_100',
        ),
        BillingProduct(
          productId: 'unknown_product',
          credits: 0,
          displayRank: 999,
          price: r'$99.99',
          packageIdentifier: 'unknown',
        ),
      ],
    );
    final _FakeBillingRepository billingRepository = _FakeBillingRepository(
      backendProducts: const <CreditProduct>[
        CreditProduct(
          productId: 'tessercam_credits_100',
          credits: 100,
          displayRank: 1,
        ),
      ],
    );
    final ProviderContainer container = _container(
      gateway: gateway,
      billingRepository: billingRepository,
    );
    addTearDown(container.dispose);

    await container.read(authSessionProvider.future);
    await container.read(billingControllerProvider.notifier).loadProducts();

    final BillingControllerState state = container.read(
      billingControllerProvider,
    );
    expect(gateway.loggedInUserIds, <String>['user-1']);
    expect(state.products, hasLength(1));
    expect(state.products.single.productId, 'tessercam_credits_100');
    expect(state.products.single.credits, 100);
    expect(state.products.single.displayRank, 1);
    expect(state.products.single.price, r'$9.99');
    expect(state.errorMessage, isNull);
  });

  test(
    'purchase cancellation clears purchasing without syncing credits',
    () async {
      final _FakeBillingGateway gateway = _FakeBillingGateway(
        purchaseOutcome: const BillingPurchaseCancelled(),
      );
      final _FakeBillingRepository billingRepository = _FakeBillingRepository();
      final ProviderContainer container = _container(
        gateway: gateway,
        billingRepository: billingRepository,
      );
      addTearDown(container.dispose);

      await container
          .read(billingControllerProvider.notifier)
          .purchase(
            const BillingProduct(
              productId: 'tessercam_credits_30',
              credits: 30,
              displayRank: 0,
              price: r'$2.99',
              packageIdentifier: r'$rc_custom_30',
            ),
          );

      final BillingControllerState state = container.read(
        billingControllerProvider,
      );
      expect(gateway.purchaseCalls, 1);
      expect(billingRepository.syncCalls, 0);
      expect(state.isPurchasing, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.lastGrantedCredits, isNull);
    },
  );

  test(
    'purchase success syncs server credits and invalidates balance',
    () async {
      final _FakeBillingGateway gateway = _FakeBillingGateway(
        purchaseOutcome: const BillingPurchaseCompleted(),
      );
      final _FakeBillingRepository billingRepository = _FakeBillingRepository(
        syncResult: const CreditPurchaseSyncResult(
          grantedCredits: 30,
          processedPurchases: 1,
          balance: 158,
          products: <CreditProduct>[],
        ),
      );
      final ProviderContainer container = _container(
        gateway: gateway,
        billingRepository: billingRepository,
        creditsRepository: _FakeCreditsRepository(balance: 158),
      );
      addTearDown(container.dispose);

      await container
          .read(billingControllerProvider.notifier)
          .purchase(
            const BillingProduct(
              productId: 'tessercam_credits_30',
              credits: 30,
              displayRank: 0,
              price: r'$2.99',
              packageIdentifier: r'$rc_custom_30',
            ),
          );

      final BillingControllerState state = container.read(
        billingControllerProvider,
      );
      expect(gateway.purchaseCalls, 1);
      expect(billingRepository.syncCalls, 1);
      expect(state.isPurchasing, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.lastGrantedCredits, 30);
      expect(container.read(creditBalanceProvider).valueOrNull?.balance, 158);
    },
  );

  test('purchase sync failure reports server sync error', () async {
    final _FakeBillingGateway gateway = _FakeBillingGateway(
      purchaseOutcome: const BillingPurchaseCompleted(),
    );
    final _FakeBillingRepository billingRepository = _FakeBillingRepository(
      syncError: StateError('sync failed'),
    );
    final ProviderContainer container = _container(
      gateway: gateway,
      billingRepository: billingRepository,
    );
    addTearDown(container.dispose);

    await container
        .read(billingControllerProvider.notifier)
        .purchase(
          const BillingProduct(
            productId: 'tessercam_credits_30',
            credits: 30,
            displayRank: 0,
            price: r'$2.99',
            packageIdentifier: r'$rc_custom_30',
          ),
        );

    final BillingControllerState state = container.read(
      billingControllerProvider,
    );
    expect(billingRepository.syncCalls, 1);
    expect(state.isPurchasing, isFalse);
    expect(
      state.errorMessage,
      'Purchase completed, but credits could not be synced.',
    );
    expect(state.lastGrantedCredits, isNull);
  });
}

ProviderContainer _container({
  required _FakeBillingGateway gateway,
  required _FakeBillingRepository billingRepository,
  _FakeCreditsRepository? creditsRepository,
}) {
  return ProviderContainer(
    overrides: <Override>[
      authSessionProvider.overrideWith(
        (_) => Stream<AuthSessionState>.value(
          const AuthSessionState.signedIn(
            AuthUser(id: 'user-1', email: 'alex@example.com'),
          ),
        ),
      ),
      billingGatewayProvider.overrideWithValue(gateway),
      billingRepositoryProvider.overrideWithValue(billingRepository),
      creditsRepositoryProvider.overrideWithValue(
        creditsRepository ?? _FakeCreditsRepository(),
      ),
      creditBalanceCacheRepositoryProvider.overrideWithValue(
        _FakeCreditBalanceCacheRepository(),
      ),
    ],
  );
}

class _FakeBillingGateway implements BillingGateway {
  _FakeBillingGateway({
    this.products = const <BillingProduct>[],
    this.purchaseOutcome = const BillingPurchaseCompleted(),
  });

  final List<BillingProduct> products;
  final BillingPurchaseOutcome purchaseOutcome;
  final List<String> loggedInUserIds = <String>[];
  int purchaseCalls = 0;

  @override
  bool get isPurchaseAvailable => true;

  @override
  Future<List<BillingProduct>> fetchProducts() async {
    return products;
  }

  @override
  Future<void> logIn(String appUserId) async {
    loggedInUserIds.add(appUserId);
  }

  @override
  Future<void> logOut() async {}

  @override
  Future<BillingPurchaseOutcome> purchaseProduct(BillingProduct product) async {
    purchaseCalls += 1;
    return purchaseOutcome;
  }

  @override
  Future<void> restorePurchases() async {}
}

class _FakeBillingRepository implements BillingRepository {
  _FakeBillingRepository({
    this.backendProducts = const <CreditProduct>[],
    this.syncResult = const CreditPurchaseSyncResult(
      grantedCredits: 0,
      processedPurchases: 0,
      balance: null,
      products: <CreditProduct>[],
    ),
    this.syncError,
  });

  final List<CreditProduct> backendProducts;
  final CreditPurchaseSyncResult syncResult;
  final Object? syncError;
  int syncCalls = 0;

  @override
  Future<List<CreditProduct>> fetchProducts() async {
    return backendProducts;
  }

  @override
  Future<CreditPurchaseSyncResult> syncRevenueCatPurchases() async {
    syncCalls += 1;
    if (syncError case final Object error) {
      throw error;
    }
    return syncResult;
  }
}

class _FakeCreditsRepository implements CreditsRepository {
  _FakeCreditsRepository({this.balance = 128});

  final int balance;
  int fetchCalls = 0;

  @override
  Future<CreditBalance> fetchBalance() async {
    fetchCalls += 1;
    return CreditBalance(
      balance: balance,
      reservedBalance: 0,
      lifetimeEarned: balance,
      lifetimeSpent: 0,
      updatedAt: DateTime.utc(2026, 6, 12),
    );
  }
}

class _FakeCreditBalanceCacheRepository
    implements CreditBalanceCacheRepository {
  final Map<String, CreditBalance> balances = <String, CreditBalance>{};

  @override
  Future<CreditBalance?> loadBalance(String userId) async {
    return balances[userId];
  }

  @override
  Future<void> saveBalance(String userId, CreditBalance balance) async {
    balances[userId] = balance;
  }
}
