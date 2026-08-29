import 'dart:async';

import 'package:fantasy_camera_flutter/billing/application/billing_catalog_loader.dart';
import 'package:fantasy_camera_flutter/billing/data/billing_repositories.dart';
import 'package:fantasy_camera_flutter/billing/data/revenuecat_billing_gateway.dart';
import 'package:fantasy_camera_flutter/billing/domain/billing_product.dart';
import 'package:fantasy_camera_flutter/billing/domain/credit_product.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/api_failure.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  const CreditProduct backendProduct = CreditProduct(
    productId: 'tessercam_credits_40_v2',
    displayNameKey: 'Standard',
    credits: 40,
    displayRank: 1,
    savingsPercent: 47,
  );
  const BillingProduct revenueCatProduct = BillingProduct(
    productId: 'tessercam_credits_40_v2',
    credits: 0,
    displayRank: 999,
    price: r'¥30.00',
    packageIdentifier: r'$rc_custom_40',
  );

  test(
    'retries a transient RevenueCat failure and reuses backend data',
    () async {
      final _SequenceBillingGateway gateway = _SequenceBillingGateway(
        productResults: <Object>[
          _revenueCatError(PurchasesErrorCode.networkError),
          const <BillingProduct>[revenueCatProduct],
        ],
      );
      final _SequenceBillingRepository repository = _SequenceBillingRepository(
        productResults: const <Object>[
          <CreditProduct>[backendProduct],
        ],
      );
      final List<Duration> delays = <Duration>[];
      final BillingCatalogLoader loader = _loader(
        gateway: gateway,
        repository: repository,
        delays: delays,
      );

      final List<BillingProduct> products = await loader.load(
        appUserId: 'user-1',
      );

      expect(products.single.credits, 40);
      expect(gateway.fetchCalls, 2);
      expect(repository.fetchCalls, 1);
      expect(delays, const <Duration>[Duration(milliseconds: 700)]);
    },
  );

  test('retries three empty RevenueCat results before succeeding', () async {
    final _SequenceBillingGateway gateway = _SequenceBillingGateway(
      productResults: const <Object>[
        <BillingProduct>[],
        <BillingProduct>[],
        <BillingProduct>[],
        <BillingProduct>[revenueCatProduct],
      ],
    );
    final _SequenceBillingRepository repository = _SequenceBillingRepository(
      productResults: const <Object>[
        <CreditProduct>[backendProduct],
      ],
    );
    final List<Duration> delays = <Duration>[];

    final List<BillingProduct> products = await _loader(
      gateway: gateway,
      repository: repository,
      delays: delays,
    ).load(appUserId: 'user-1');

    expect(products, hasLength(1));
    expect(gateway.fetchCalls, 4);
    expect(repository.fetchCalls, 1);
    expect(delays, const <Duration>[
      Duration(milliseconds: 700),
      Duration(milliseconds: 1800),
      Duration(milliseconds: 3200),
    ]);
  });

  test('retries only backend after RevenueCat has succeeded', () async {
    final _SequenceBillingGateway gateway = _SequenceBillingGateway(
      productResults: const <Object>[
        <BillingProduct>[revenueCatProduct],
      ],
    );
    final _SequenceBillingRepository repository = _SequenceBillingRepository(
      productResults: const <Object>[
        BackendApiFailure(code: 'network_error', message: 'offline'),
        <CreditProduct>[backendProduct],
      ],
    );

    final List<BillingProduct> products = await _loader(
      gateway: gateway,
      repository: repository,
    ).load(appUserId: 'user-1');

    expect(products, hasLength(1));
    expect(gateway.fetchCalls, 1);
    expect(repository.fetchCalls, 2);
  });

  test('does not retry invalid RevenueCat credentials', () async {
    final _SequenceBillingGateway gateway = _SequenceBillingGateway(
      productResults: <Object>[
        _revenueCatError(PurchasesErrorCode.invalidCredentialsError),
      ],
    );
    final _SequenceBillingRepository repository = _SequenceBillingRepository(
      productResults: const <Object>[
        <CreditProduct>[backendProduct],
      ],
    );

    await expectLater(
      _loader(
        gateway: gateway,
        repository: repository,
      ).load(appUserId: 'user-1'),
      throwsA(isA<BillingCatalogLoadException>()),
    );
    expect(gateway.fetchCalls, 1);
  });

  test('does not retry RevenueCat configuration errors', () async {
    final _SequenceBillingGateway gateway = _SequenceBillingGateway(
      productResults: <Object>[
        _revenueCatError(PurchasesErrorCode.configurationError),
      ],
    );
    final _SequenceBillingRepository repository = _SequenceBillingRepository(
      productResults: const <Object>[
        <CreditProduct>[backendProduct],
      ],
    );

    await expectLater(
      _loader(
        gateway: gateway,
        repository: repository,
      ).load(appUserId: 'user-1'),
      throwsA(isA<BillingCatalogLoadException>()),
    );
    expect(gateway.fetchCalls, 1);
  });

  test('does not retry backend authorization failures', () async {
    final _SequenceBillingGateway gateway = _SequenceBillingGateway(
      productResults: const <Object>[
        <BillingProduct>[revenueCatProduct],
      ],
    );
    final _SequenceBillingRepository repository = _SequenceBillingRepository(
      productResults: const <Object>[
        BackendApiFailure(
          code: 'unauthorized',
          message: 'unauthorized',
          statusCode: 401,
        ),
      ],
    );

    await expectLater(
      _loader(
        gateway: gateway,
        repository: repository,
      ).load(appUserId: 'user-1'),
      throwsA(isA<BillingCatalogLoadException>()),
    );
    expect(repository.fetchCalls, 1);
  });

  test('does not retry backend forbidden failures', () async {
    final _SequenceBillingGateway gateway = _SequenceBillingGateway(
      productResults: const <Object>[
        <BillingProduct>[revenueCatProduct],
      ],
    );
    final _SequenceBillingRepository repository = _SequenceBillingRepository(
      productResults: const <Object>[
        BackendApiFailure(
          code: 'forbidden',
          message: 'forbidden',
          statusCode: 403,
        ),
      ],
    );

    await expectLater(
      _loader(
        gateway: gateway,
        repository: repository,
      ).load(appUserId: 'user-1'),
      throwsA(isA<BillingCatalogLoadException>()),
    );
    expect(repository.fetchCalls, 1);
  });

  test('does not retry a non-empty catalog with no matching ids', () async {
    final _SequenceBillingGateway gateway = _SequenceBillingGateway(
      productResults: const <Object>[
        <BillingProduct>[
          BillingProduct(
            productId: 'different_product',
            credits: 0,
            displayRank: 999,
            price: r'¥30.00',
            packageIdentifier: 'different',
          ),
        ],
      ],
    );
    final _SequenceBillingRepository repository = _SequenceBillingRepository(
      productResults: const <Object>[
        <CreditProduct>[backendProduct],
      ],
    );

    await expectLater(
      _loader(
        gateway: gateway,
        repository: repository,
      ).load(appUserId: 'user-1'),
      throwsA(
        isA<BillingCatalogLoadException>().having(
          (BillingCatalogLoadException error) => error.kind,
          'kind',
          BillingCatalogFailureKind.productMismatch,
        ),
      ),
    );
    expect(gateway.fetchCalls, 1);
    expect(repository.fetchCalls, 1);
  });

  test('reports temporary failure after four transient attempts', () async {
    final _SequenceBillingGateway gateway = _SequenceBillingGateway(
      productResults: <Object>[
        for (int index = 0; index < 4; index += 1)
          _revenueCatError(PurchasesErrorCode.offlineConnectionError),
      ],
    );
    final _SequenceBillingRepository repository = _SequenceBillingRepository(
      productResults: const <Object>[
        <CreditProduct>[backendProduct],
      ],
    );

    await expectLater(
      _loader(
        gateway: gateway,
        repository: repository,
      ).load(appUserId: 'user-1'),
      throwsA(
        isA<BillingCatalogLoadException>().having(
          (BillingCatalogLoadException error) => error.kind,
          'kind',
          BillingCatalogFailureKind.temporarilyUnavailable,
        ),
      ),
    );
    expect(gateway.fetchCalls, 4);
    expect(repository.fetchCalls, 1);
  });

  test('a manual retry starts a fresh loading cycle', () async {
    final _SequenceBillingGateway gateway = _SequenceBillingGateway(
      productResults: <Object>[
        for (int index = 0; index < 4; index += 1)
          _revenueCatError(PurchasesErrorCode.networkError),
        const <BillingProduct>[revenueCatProduct],
      ],
    );
    final _SequenceBillingRepository repository = _SequenceBillingRepository(
      productResults: const <Object>[
        <CreditProduct>[backendProduct],
        <CreditProduct>[backendProduct],
      ],
    );
    final BillingCatalogLoader loader = _loader(
      gateway: gateway,
      repository: repository,
    );

    await expectLater(
      loader.load(appUserId: 'user-1'),
      throwsA(isA<BillingCatalogLoadException>()),
    );
    final List<BillingProduct> products = await loader.load(
      appUserId: 'user-1',
    );

    expect(products, hasLength(1));
    expect(gateway.fetchCalls, 5);
    expect(repository.fetchCalls, 2);
  });

  test('starts backend and RevenueCat requests in parallel', () async {
    final Completer<void> backendStarted = Completer<void>();
    final Completer<void> revenueCatStarted = Completer<void>();
    final Completer<void> releaseRequests = Completer<void>();
    final _ParallelBillingGateway gateway = _ParallelBillingGateway(
      started: revenueCatStarted,
      release: releaseRequests,
      products: const <BillingProduct>[revenueCatProduct],
    );
    final _ParallelBillingRepository repository = _ParallelBillingRepository(
      started: backendStarted,
      release: releaseRequests,
      products: const <CreditProduct>[backendProduct],
    );

    final Future<List<BillingProduct>> loadFuture = _loader(
      gateway: gateway,
      repository: repository,
    ).load(appUserId: 'user-1');
    await Future.wait(<Future<void>>[
      backendStarted.future,
      revenueCatStarted.future,
    ]);
    releaseRequests.complete();

    expect(await loadFuture, hasLength(1));
  });
}

BillingCatalogLoader _loader({
  required BillingGateway gateway,
  required BillingRepository repository,
  List<Duration>? delays,
}) {
  return BillingCatalogLoader(
    gateway: gateway,
    repository: repository,
    retryPolicy: const BillingCatalogRetryPolicy(),
    delay: (Duration duration) async {
      delays?.add(duration);
    },
  );
}

PlatformException _revenueCatError(PurchasesErrorCode code) {
  return PlatformException(code: '${code.index}', message: code.name);
}

class _SequenceBillingGateway implements BillingGateway {
  _SequenceBillingGateway({required List<Object> productResults})
    : _productResults = List<Object>.of(productResults);

  final List<Object> _productResults;
  int fetchCalls = 0;

  @override
  bool get isPurchaseAvailable => true;

  @override
  Future<List<BillingProduct>> fetchProducts() async {
    fetchCalls += 1;
    final Object result = _productResults.removeAt(0);
    if (result is List<BillingProduct>) {
      return result;
    }
    throw result;
  }

  @override
  Future<void> logIn(String appUserId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<BillingPurchaseOutcome> purchaseProduct(BillingProduct product) async {
    return const BillingPurchaseCompleted();
  }

  @override
  Future<void> restorePurchases() async {}
}

class _SequenceBillingRepository implements BillingRepository {
  _SequenceBillingRepository({required List<Object> productResults})
    : _productResults = List<Object>.of(productResults);

  final List<Object> _productResults;
  int fetchCalls = 0;

  @override
  Future<List<CreditProduct>> fetchProducts() async {
    fetchCalls += 1;
    final Object result = _productResults.removeAt(0);
    if (result is List<CreditProduct>) {
      return result;
    }
    throw result;
  }

  @override
  Future<CreditPurchaseSyncResult> syncRevenueCatPurchases() {
    throw UnimplementedError();
  }
}

class _ParallelBillingGateway implements BillingGateway {
  const _ParallelBillingGateway({
    required this.started,
    required this.release,
    required this.products,
  });

  final Completer<void> started;
  final Completer<void> release;
  final List<BillingProduct> products;

  @override
  bool get isPurchaseAvailable => true;

  @override
  Future<List<BillingProduct>> fetchProducts() async {
    started.complete();
    await release.future;
    return products;
  }

  @override
  Future<void> logIn(String appUserId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<BillingPurchaseOutcome> purchaseProduct(BillingProduct product) async {
    return const BillingPurchaseCompleted();
  }

  @override
  Future<void> restorePurchases() async {}
}

class _ParallelBillingRepository implements BillingRepository {
  const _ParallelBillingRepository({
    required this.started,
    required this.release,
    required this.products,
  });

  final Completer<void> started;
  final Completer<void> release;
  final List<CreditProduct> products;

  @override
  Future<List<CreditProduct>> fetchProducts() async {
    started.complete();
    await release.future;
    return products;
  }

  @override
  Future<CreditPurchaseSyncResult> syncRevenueCatPurchases() {
    throw UnimplementedError();
  }
}
