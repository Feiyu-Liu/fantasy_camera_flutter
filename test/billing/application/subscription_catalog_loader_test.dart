import 'package:fantasy_camera_flutter/billing/application/billing_catalog_loader.dart';
import 'package:fantasy_camera_flutter/billing/application/subscription_catalog_loader.dart';
import 'package:fantasy_camera_flutter/billing/data/revenuecat_billing_gateway.dart';
import 'package:fantasy_camera_flutter/billing/data/subscription_billing_repository.dart';
import 'package:fantasy_camera_flutter/billing/domain/billing_product.dart';
import 'package:fantasy_camera_flutter/billing/domain/subscription_billing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merges plans with store prices and keeps backend order', () async {
    final _StoreGateway gateway = _StoreGateway(<BillingProduct>[
      const BillingProduct(
        productId: 'tessercam_plus_monthly',
        credits: 0,
        displayRank: 0,
        price: r'$9.99',
        packageIdentifier: r'$rc_monthly',
        offeringIdentifier: 'subscriptions',
      ),
      const BillingProduct(
        productId: 'unknown',
        credits: 0,
        displayRank: 0,
        price: r'$1.00',
        packageIdentifier: 'unknown',
      ),
    ]);
    final SubscriptionCatalog catalog = await SubscriptionCatalogLoader(
      gateway: gateway,
      repository: _Repository(_status()),
      offeringId: 'subscriptions',
      retryPolicy: const BillingCatalogRetryPolicy(delays: <Duration>[]),
      delay: (_) async {},
    ).load(appUserId: 'user-1');

    expect(gateway.loggedInUserId, 'user-1');
    expect(catalog.products, hasLength(1));
    expect(catalog.products.single.plan.tier, SubscriptionTier.plus);
    expect(catalog.products.single.storeProduct.price, r'$9.99');
  });

  test('uses backend plans for explicitly enabled local E2E catalog', () async {
    final SubscriptionCatalog catalog = await SubscriptionCatalogLoader(
      gateway: _StoreGateway(const <BillingProduct>[]),
      repository: _Repository(_status()),
      offeringId: 'subscriptions',
      retryPolicy: const BillingCatalogRetryPolicy(delays: <Duration>[]),
      delay: (_) async {},
      allowLocalProducts: true,
    ).load(appUserId: 'user-1');

    expect(catalog.products.single.plan.tier, SubscriptionTier.plus);
    expect(
      catalog.products.single.storeProduct.productId,
      'tessercam_plus_monthly',
    );
    expect(catalog.products.single.storeProduct.price, 'Test');
  });
}

class _StoreGateway implements SubscriptionStoreGateway {
  _StoreGateway(this.products);

  final List<BillingProduct> products;
  String? loggedInUserId;

  @override
  bool get isPurchaseAvailable => true;

  @override
  Future<List<BillingProduct>> fetchProductsForOffering(
    String offeringId,
  ) async {
    return products;
  }

  @override
  Future<void> logIn(String appUserId) async {
    loggedInUserId = appUserId;
  }

  @override
  Future<BillingPurchaseOutcome> purchaseProduct(BillingProduct product) async {
    return const BillingPurchaseCompleted();
  }

  @override
  Future<void> restorePurchases() async {}
}

class _Repository implements SubscriptionBillingRepository {
  const _Repository(this.status);

  final SubscriptionBillingStatus status;

  @override
  Future<SubscriptionBillingStatus> fetchStatus() async => status;

  @override
  Future<SubscriptionBillingStatus> syncRevenueCatPurchases() async => status;
}

SubscriptionBillingStatus _status() {
  return SubscriptionBillingStatus(
    billingEnvironment: 'SANDBOX',
    capabilities: const BillingCapabilities(
      maxEnabled: false,
      qualityTiers: <String>{'full'},
    ),
    plans: const <SubscriptionPlan>[
      SubscriptionPlan(
        productIdentifier: 'tessercam_plus_monthly',
        tier: SubscriptionTier.plus,
        displayOrder: 1,
        fullAllowanceUnits: 34,
        overflowAllowanceUnits: 20,
        maxEnabled: true,
        revision: 1,
      ),
    ],
    qualityTiers: const <QualityTierCost>[
      QualityTierCost(qualityTier: 'full', allowanceUnits: 2, revision: 1),
    ],
  );
}
