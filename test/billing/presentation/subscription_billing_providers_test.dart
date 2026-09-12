import 'package:fantasy_camera_flutter/auth/domain/auth_session_state.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_user.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_providers.dart';
import 'package:fantasy_camera_flutter/billing/data/revenuecat_billing_gateway.dart';
import 'package:fantasy_camera_flutter/billing/data/subscription_billing_repository.dart';
import 'package:fantasy_camera_flutter/billing/domain/billing_product.dart';
import 'package:fantasy_camera_flutter/billing/domain/subscription_billing.dart';
import 'package:fantasy_camera_flutter/billing/presentation/billing_providers.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/api_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subscription catalog defaults to Plus', () async {
    final _StoreGateway gateway = _StoreGateway();
    final _Repository repository = _Repository();
    final ProviderContainer container = _container(gateway, repository);
    addTearDown(container.dispose);

    await container
        .read(subscriptionPurchaseControllerProvider.notifier)
        .loadProducts();

    final SubscriptionPurchaseState state = container.read(
      subscriptionPurchaseControllerProvider,
    );
    expect(state.products, hasLength(3));
    expect(state.selectedProductId, 'tessercam_plus_monthly');
    expect(gateway.loggedInUserId, 'user-1');
  });

  test('purchase cancellation does not start backend sync', () async {
    final _StoreGateway gateway = _StoreGateway(
      outcome: const BillingPurchaseCancelled(),
    );
    final _Repository repository = _Repository();
    final ProviderContainer container = _container(gateway, repository);
    addTearDown(container.dispose);
    final SubscriptionPurchaseController controller = container.read(
      subscriptionPurchaseControllerProvider.notifier,
    );
    await controller.loadProducts();

    await controller.purchaseSelected();

    expect(repository.syncCalls, 0);
    expect(
      container.read(subscriptionPurchaseControllerProvider).isPurchasing,
      isFalse,
    );
  });

  test('billing_sync_pending prevents duplicate purchase feedback', () async {
    final _StoreGateway gateway = _StoreGateway();
    final _Repository repository = _Repository(
      syncError: const BackendApiFailure(
        code: 'billing_sync_pending',
        message: 'pending',
        statusCode: 409,
      ),
    );
    final ProviderContainer container = _container(gateway, repository);
    addTearDown(container.dispose);
    final SubscriptionPurchaseController controller = container.read(
      subscriptionPurchaseControllerProvider.notifier,
    );
    await controller.loadProducts();

    await controller.purchaseSelected();

    final SubscriptionPurchaseState state = container.read(
      subscriptionPurchaseControllerProvider,
    );
    expect(state.isPurchasing, isFalse);
    expect(state.isSyncPending, isTrue);
    expect(state.errorKind, isNull);
  });
}

ProviderContainer _container(_StoreGateway gateway, _Repository repository) {
  return ProviderContainer(
    overrides: <Override>[
      authSessionProvider.overrideWith(
        (_) => Stream<AuthSessionState>.value(
          const AuthSessionState.signedIn(
            AuthUser(id: 'user-1', email: 'user@example.com'),
          ),
        ),
      ),
      subscriptionStoreGatewayProvider.overrideWithValue(gateway),
      subscriptionBillingRepositoryProvider.overrideWithValue(repository),
      billingCatalogDelayProvider.overrideWithValue((_) async {}),
    ],
  );
}

class _StoreGateway implements SubscriptionStoreGateway {
  _StoreGateway({this.outcome = const BillingPurchaseCompleted()});

  final BillingPurchaseOutcome outcome;
  String? loggedInUserId;

  @override
  bool get isPurchaseAvailable => true;

  @override
  Future<List<BillingProduct>> fetchProductsForOffering(
    String offeringId,
  ) async {
    return <BillingProduct>[
      for (final String id in <String>[
        'tessercam_mini_monthly',
        'tessercam_plus_monthly',
        'tessercam_pro_monthly',
      ])
        BillingProduct(
          productId: id,
          credits: 0,
          displayRank: 0,
          price: r'$9.99',
          packageIdentifier: id,
          offeringIdentifier: offeringId,
        ),
    ];
  }

  @override
  Future<void> logIn(String appUserId) async {
    loggedInUserId = appUserId;
  }

  @override
  Future<BillingPurchaseOutcome> purchaseProduct(BillingProduct product) async {
    return outcome;
  }

  @override
  Future<void> restorePurchases() async {}
}

class _Repository implements SubscriptionBillingRepository {
  _Repository({this.syncError});

  final Object? syncError;
  int syncCalls = 0;

  @override
  Future<SubscriptionBillingStatus> fetchStatus() async => _status();

  @override
  Future<SubscriptionBillingStatus> syncRevenueCatPurchases() async {
    syncCalls += 1;
    if (syncError case final Object error) {
      throw error;
    }
    return _status(active: true);
  }
}

SubscriptionBillingStatus _status({bool active = false}) {
  const List<SubscriptionPlan> plans = <SubscriptionPlan>[
    SubscriptionPlan(
      productIdentifier: 'tessercam_mini_monthly',
      tier: SubscriptionTier.mini,
      displayOrder: 0,
      fullAllowanceUnits: 12,
      overflowAllowanceUnits: 8,
      maxEnabled: false,
      revision: 1,
    ),
    SubscriptionPlan(
      productIdentifier: 'tessercam_plus_monthly',
      tier: SubscriptionTier.plus,
      displayOrder: 1,
      fullAllowanceUnits: 34,
      overflowAllowanceUnits: 20,
      maxEnabled: true,
      revision: 1,
    ),
    SubscriptionPlan(
      productIdentifier: 'tessercam_pro_monthly',
      tier: SubscriptionTier.pro,
      displayOrder: 2,
      fullAllowanceUnits: 72,
      overflowAllowanceUnits: 40,
      maxEnabled: true,
      revision: 1,
    ),
  ];
  return SubscriptionBillingStatus(
    billingEnvironment: 'SANDBOX',
    subscription: active
        ? const SubscriptionAccess(
            active: true,
            tier: SubscriptionTier.plus,
            productIdentifier: 'tessercam_plus_monthly',
            willRenew: true,
            accessEndIsFinal: false,
            syncFreshness: 'fresh',
          )
        : null,
    capabilities: BillingCapabilities(
      maxEnabled: active,
      qualityTiers: active
          ? const <String>{'full', 'max'}
          : const <String>{'full'},
    ),
    plans: plans,
    qualityTiers: const <QualityTierCost>[
      QualityTierCost(qualityTier: 'full', allowanceUnits: 2, revision: 1),
      QualityTierCost(qualityTier: 'max', allowanceUnits: 6, revision: 1),
    ],
  );
}
