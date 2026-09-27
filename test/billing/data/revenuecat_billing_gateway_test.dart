import 'dart:async';

import 'package:fantasy_camera_flutter/billing/data/revenuecat_billing_gateway.dart';
import 'package:fantasy_camera_flutter/billing/domain/billing_product.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  test(
    'concurrent warmup and paywall login configure RevenueCat once',
    () async {
      final Completer<void> configureGate = Completer<void>();
      final _FakeRevenueCatClient client = _FakeRevenueCatClient(
        configureGate: configureGate,
      );
      final RevenueCatBillingGateway gateway = _gateway(client);

      final Future<void> warmup = gateway.logIn('user-1');
      await Future<void>.delayed(Duration.zero);
      final Future<void> paywall = gateway.logIn('user-1');
      await Future<void>.delayed(Duration.zero);

      expect(client.configureCalls, 1);
      configureGate.complete();
      await Future.wait(<Future<void>>[warmup, paywall]);
      expect(client.configureCalls, 1);
      expect(client.configuredAppUserIds, <String?>['user-1']);
      expect(client.loginUserIds, isEmpty);
    },
  );

  test('logout and a later login do not configure RevenueCat again', () async {
    final _FakeRevenueCatClient client = _FakeRevenueCatClient();
    final RevenueCatBillingGateway gateway = _gateway(client);

    await gateway.logIn('user-1');
    await gateway.logOut();
    await gateway.logIn('user-2');

    expect(client.configureCalls, 1);
    expect(client.logoutCalls, 1);
    expect(client.loginUserIds, <String>['user-2']);
  });

  test('logout waits for an in-flight configuration', () async {
    final Completer<void> configureGate = Completer<void>();
    final _FakeRevenueCatClient client = _FakeRevenueCatClient(
      configureGate: configureGate,
    );
    final RevenueCatBillingGateway gateway = _gateway(client);

    final Future<void> warmup = gateway.logIn('user-1');
    await Future<void>.delayed(Duration.zero);
    final Future<void> logout = gateway.logOut();
    await Future<void>.delayed(Duration.zero);

    expect(client.logoutCalls, 0);
    configureGate.complete();
    await Future.wait(<Future<void>>[warmup, logout]);
    expect(client.configureCalls, 1);
    expect(client.logoutCalls, 1);
  });

  test('a failed configuration can be retried', () async {
    final _FakeRevenueCatClient client = _FakeRevenueCatClient(
      configureErrors: <Object>[StateError('configure failed')],
    );
    final RevenueCatBillingGateway gateway = _gateway(client);

    await expectLater(gateway.logIn('user-1'), throwsStateError);
    await gateway.logIn('user-1');

    expect(client.configureCalls, 2);
    expect(client.configuredAppUserIds, <String?>['user-1', 'user-1']);
  });

  test(
    'an unavailable subscription offering never falls back to credit packs',
    () async {
      const StoreProduct creditStoreProduct = StoreProduct(
        'tessercam_credits_6_v2',
        'Credits',
        'Credits',
        1.99,
        r'$1.99',
        'USD',
      );
      const Package creditPackage = Package(
        'credit-pack',
        PackageType.custom,
        creditStoreProduct,
        PresentedOfferingContext('credits', null, null),
      );
      const Offering credits = Offering(
        'credits',
        'Credit packs',
        <String, Object>{},
        <Package>[creditPackage],
      );
      final _FakeRevenueCatClient client = _FakeRevenueCatClient(
        offerings: const Offerings(<String, Offering>{
          'credits': credits,
        }, current: credits),
      );
      final RevenueCatBillingGateway gateway = _gateway(client);

      expect(await gateway.fetchProductsForOffering('subscription'), isEmpty);
      final BillingPurchaseOutcome outcome = await gateway.purchaseProduct(
        const BillingProduct(
          productId: 'tessercam_credits_6_v2',
          credits: 6,
          displayRank: 0,
          price: r'$1.99',
          packageIdentifier: 'credit-pack',
          offeringIdentifier: 'subscription',
        ),
      );
      expect(outcome, isA<BillingPurchaseFailed>());
      expect(client.purchaseCalls, 0);
    },
  );
}

RevenueCatBillingGateway _gateway(RevenueCatClient client) {
  return RevenueCatBillingGateway(
    iosPublicSdkKey: 'appl_test',
    offeringId: 'default',
    client: client,
    isPurchaseAvailableOverride: true,
  );
}

class _FakeRevenueCatClient implements RevenueCatClient {
  _FakeRevenueCatClient({
    this.configureGate,
    this.offerings,
    List<Object> configureErrors = const <Object>[],
  }) : _configureErrors = List<Object>.of(configureErrors);

  final Completer<void>? configureGate;
  final Offerings? offerings;
  final List<Object> _configureErrors;
  final List<String?> configuredAppUserIds = <String?>[];
  final List<String> loginUserIds = <String>[];
  int configureCalls = 0;
  int logoutCalls = 0;
  int purchaseCalls = 0;

  @override
  Future<void> configure(PurchasesConfiguration configuration) async {
    configureCalls += 1;
    configuredAppUserIds.add(configuration.appUserID);
    if (_configureErrors.isNotEmpty) {
      throw _configureErrors.removeAt(0);
    }
    await configureGate?.future;
  }

  @override
  Future<Offerings> getOfferings() {
    return Future<Offerings>.value(
      offerings ?? const Offerings(<String, Offering>{}),
    );
  }

  @override
  Future<void> logIn(String appUserId) async {
    loginUserIds.add(appUserId);
  }

  @override
  Future<void> logOut() async {
    logoutCalls += 1;
  }

  @override
  Future<void> purchase(PurchaseParams purchaseParams) async {
    purchaseCalls += 1;
  }

  @override
  Future<void> restorePurchases() {
    throw UnimplementedError();
  }

  @override
  Future<void> setLogLevel(LogLevel level) async {}
}
