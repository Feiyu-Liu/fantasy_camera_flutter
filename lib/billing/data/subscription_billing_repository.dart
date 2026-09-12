import '../../features/backend_api/data/fantasy_api_client.dart';
import '../../features/backend_api/domain/json_value.dart';
import '../domain/subscription_billing.dart';

abstract interface class SubscriptionBillingRepository {
  Future<SubscriptionBillingStatus> fetchStatus();

  Future<SubscriptionBillingStatus> syncRevenueCatPurchases();
}

class WorkerSubscriptionBillingRepository
    implements SubscriptionBillingRepository {
  const WorkerSubscriptionBillingRepository(this._client);

  final FantasyApiClient _client;

  @override
  Future<SubscriptionBillingStatus> fetchStatus() {
    return _client.get<SubscriptionBillingStatus>(
      '/v1/billing/status',
      decode: _decodeStatus,
    );
  }

  @override
  Future<SubscriptionBillingStatus> syncRevenueCatPurchases() {
    return _client.post<SubscriptionBillingStatus>(
      '/v1/billing/revenuecat/sync',
      decode: _decodeStatus,
    );
  }
}

SubscriptionBillingStatus _decodeStatus(Object? data) {
  final JsonObject json = data is Map<String, Object?>
      ? data
      : Map<String, Object?>.from(data as Map);
  return SubscriptionBillingStatus.fromJson(json);
}
