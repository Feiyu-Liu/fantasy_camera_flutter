import '../../features/backend_api/data/fantasy_api_client.dart';
import '../../features/backend_api/domain/json_value.dart';
import '../domain/credit_product.dart';

abstract interface class BillingRepository {
  Future<List<CreditProduct>> fetchProducts();

  Future<CreditPurchaseSyncResult> syncRevenueCatPurchases();
}

class WorkerBillingRepository implements BillingRepository {
  const WorkerBillingRepository(this._client);

  final FantasyApiClient _client;

  @override
  Future<List<CreditProduct>> fetchProducts() {
    return _client.get<List<CreditProduct>>(
      '/v1/billing/products',
      decode: (Object? data) {
        final JsonObject json = data is Map<String, Object?>
            ? data
            : Map<String, Object?>.from(data as Map);
        return decodeJsonObjectList(json['products'], CreditProduct.fromJson);
      },
    );
  }

  @override
  Future<CreditPurchaseSyncResult> syncRevenueCatPurchases() {
    return _client.post<CreditPurchaseSyncResult>(
      '/v1/billing/revenuecat/sync',
      decode: (Object? data) {
        return decodeJsonObject(data, CreditPurchaseSyncResult.fromJson);
      },
    );
  }
}
