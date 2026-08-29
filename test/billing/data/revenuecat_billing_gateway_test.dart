import 'dart:async';

import 'package:fantasy_camera_flutter/billing/data/revenuecat_billing_gateway.dart';
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
    List<Object> configureErrors = const <Object>[],
  }) : _configureErrors = List<Object>.of(configureErrors);

  final Completer<void>? configureGate;
  final List<Object> _configureErrors;
  final List<String?> configuredAppUserIds = <String?>[];
  final List<String> loginUserIds = <String>[];
  int configureCalls = 0;
  int logoutCalls = 0;

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
    throw UnimplementedError();
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
  Future<void> purchase(PurchaseParams purchaseParams) {
    throw UnimplementedError();
  }

  @override
  Future<void> restorePurchases() {
    throw UnimplementedError();
  }

  @override
  Future<void> setLogLevel(LogLevel level) async {}
}
