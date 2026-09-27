import '../data/revenuecat_billing_gateway.dart';
import '../data/subscription_billing_repository.dart';
import '../domain/billing_product.dart';
import '../domain/subscription_billing.dart';
import 'billing_catalog_loader.dart';

class SubscriptionCatalogLoader {
  const SubscriptionCatalogLoader({
    required SubscriptionStoreGateway gateway,
    required SubscriptionBillingRepository repository,
    required String offeringId,
    required BillingCatalogRetryPolicy retryPolicy,
    required BillingCatalogDelay delay,
    bool allowLocalProducts = false,
  }) : _gateway = gateway,
       _repository = repository,
       _offeringId = offeringId,
       _retryPolicy = retryPolicy,
       _delay = delay,
       _allowLocalProducts = allowLocalProducts;

  final SubscriptionStoreGateway _gateway;
  final SubscriptionBillingRepository _repository;
  final String _offeringId;
  final BillingCatalogRetryPolicy _retryPolicy;
  final BillingCatalogDelay _delay;
  final bool _allowLocalProducts;

  Future<SubscriptionCatalog> load({required String? appUserId}) async {
    Object? lastError;
    for (int attempt = 0; attempt <= _retryPolicy.delays.length; attempt += 1) {
      try {
        if (appUserId != null && appUserId.isNotEmpty) {
          await _gateway.logIn(appUserId);
        }
        final List<Object> results = await Future.wait<Object>(<Future<Object>>[
          _repository.fetchStatus(),
          _gateway.fetchProductsForOffering(_offeringId),
        ]);
        final SubscriptionBillingStatus status =
            results[0] as SubscriptionBillingStatus;
        final List<BillingProduct> storeProducts =
            results[1] as List<BillingProduct>;
        final Map<String, BillingProduct> storeById = <String, BillingProduct>{
          for (final BillingProduct product in storeProducts)
            product.productId: product,
        };
        List<SubscriptionProduct> products = status.plans
            .where(
              (SubscriptionPlan plan) =>
                  storeById.containsKey(plan.productIdentifier),
            )
            .map(
              (SubscriptionPlan plan) => SubscriptionProduct(
                plan: plan,
                storeProduct: storeById[plan.productIdentifier]!,
              ),
            )
            .toList(growable: false);
        if (products.isEmpty && _allowLocalProducts) {
          products = status.plans
              .map(
                (SubscriptionPlan plan) => SubscriptionProduct(
                  plan: plan,
                  storeProduct: BillingProduct(
                    productId: plan.productIdentifier,
                    credits: 0,
                    displayRank: plan.displayOrder,
                    price: 'Test',
                    packageIdentifier: plan.productIdentifier,
                    offeringIdentifier: _offeringId,
                  ),
                ),
              )
              .toList(growable: false);
        }
        if (products.isEmpty) {
          throw const BillingCatalogLoadException(
            BillingCatalogFailureKind.productMismatch,
          );
        }
        return SubscriptionCatalog(status: status, products: products);
      } on BillingCatalogLoadException {
        rethrow;
      } on Object catch (error) {
        lastError = error;
      }
      if (attempt == _retryPolicy.delays.length) {
        break;
      }
      await _delay(_retryPolicy.delays[attempt]);
    }
    throw BillingCatalogLoadException(
      BillingCatalogFailureKind.temporarilyUnavailable,
      cause: lastError,
    );
  }
}
