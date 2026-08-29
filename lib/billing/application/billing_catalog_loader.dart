import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../data/billing_repositories.dart';
import '../data/revenuecat_billing_gateway.dart';
import '../domain/billing_product.dart';
import '../domain/credit_product.dart';
import '../../features/backend_api/domain/api_failure.dart';

typedef BillingCatalogDelay = Future<void> Function(Duration duration);

class BillingCatalogRetryPolicy {
  const BillingCatalogRetryPolicy({
    this.delays = const <Duration>[
      Duration(milliseconds: 700),
      Duration(milliseconds: 1800),
      Duration(milliseconds: 3200),
    ],
  });

  final List<Duration> delays;
}

enum BillingCatalogFailureKind {
  temporarilyUnavailable,
  permanent,
  productMismatch,
}

class BillingCatalogLoadException implements Exception {
  const BillingCatalogLoadException(this.kind, {this.cause});

  final BillingCatalogFailureKind kind;
  final Object? cause;

  @override
  String toString() {
    final Object? failure = cause;
    return failure == null
        ? 'BillingCatalogLoadException(${kind.name})'
        : 'BillingCatalogLoadException(${kind.name}): $failure';
  }
}

class BillingCatalogLoader {
  const BillingCatalogLoader({
    required BillingGateway gateway,
    required BillingRepository repository,
    required BillingCatalogRetryPolicy retryPolicy,
    required BillingCatalogDelay delay,
  }) : _gateway = gateway,
       _repository = repository,
       _retryPolicy = retryPolicy,
       _delay = delay;

  final BillingGateway _gateway;
  final BillingRepository _repository;
  final BillingCatalogRetryPolicy _retryPolicy;
  final BillingCatalogDelay _delay;

  Future<List<BillingProduct>> load({required String? appUserId}) async {
    if (!_gateway.isPurchaseAvailable) {
      throw const BillingCatalogLoadException(
        BillingCatalogFailureKind.permanent,
      );
    }

    List<CreditProduct>? backendProducts;
    List<BillingProduct>? revenueCatProducts;
    Object? lastFailure;

    for (int attempt = 0; attempt <= _retryPolicy.delays.length; attempt += 1) {
      _CatalogSourceResult<List<CreditProduct>>? backendResult;
      _CatalogSourceResult<List<BillingProduct>>? revenueCatResult;
      await Future.wait<void>(<Future<void>>[
        if (backendProducts == null)
          _captureSource<List<CreditProduct>>(
            _repository.fetchProducts,
            isRetryable: _isBackendRetryable,
            isEmpty: (List<CreditProduct> products) => products.isEmpty,
          ).then((result) => backendResult = result),
        if (revenueCatProducts == null)
          _captureSource<List<BillingProduct>>(
            () => _fetchRevenueCatProducts(appUserId),
            isRetryable: _isRevenueCatRetryable,
            isEmpty: (List<BillingProduct> products) => products.isEmpty,
          ).then((result) => revenueCatResult = result),
      ]);

      if (backendResult
          case final _CatalogSourceResult<List<CreditProduct>> result) {
        if (result.value case final List<CreditProduct> products) {
          backendProducts = products;
        } else {
          lastFailure = result.error;
          if (!result.isRetryable) {
            throw BillingCatalogLoadException(
              BillingCatalogFailureKind.permanent,
              cause: result.error,
            );
          }
        }
      }
      if (revenueCatResult
          case final _CatalogSourceResult<List<BillingProduct>> result) {
        if (result.value case final List<BillingProduct> products) {
          revenueCatProducts = products;
        } else {
          lastFailure = result.error;
          if (!result.isRetryable) {
            throw BillingCatalogLoadException(
              BillingCatalogFailureKind.permanent,
              cause: result.error,
            );
          }
        }
      }

      if (backendProducts != null && revenueCatProducts != null) {
        final List<BillingProduct> products = _mergeProducts(
          backendProducts,
          revenueCatProducts,
        );
        if (products.isEmpty) {
          throw const BillingCatalogLoadException(
            BillingCatalogFailureKind.productMismatch,
          );
        }
        return products;
      }

      if (attempt == _retryPolicy.delays.length) {
        throw BillingCatalogLoadException(
          BillingCatalogFailureKind.temporarilyUnavailable,
          cause: lastFailure,
        );
      }
      await _delay(_retryPolicy.delays[attempt]);
    }

    throw BillingCatalogLoadException(
      BillingCatalogFailureKind.temporarilyUnavailable,
      cause: lastFailure,
    );
  }

  Future<List<BillingProduct>> _fetchRevenueCatProducts(
    String? appUserId,
  ) async {
    if (appUserId != null && appUserId.isNotEmpty) {
      await _gateway.logIn(appUserId);
    }
    return _gateway.fetchProducts();
  }

  List<BillingProduct> _mergeProducts(
    List<CreditProduct> backendProducts,
    List<BillingProduct> revenueCatProducts,
  ) {
    final Map<String, CreditProduct> backendById = <String, CreditProduct>{
      for (final CreditProduct product in backendProducts)
        product.productId: product,
    };
    final List<BillingProduct> products =
        revenueCatProducts
            .where(
              (BillingProduct product) =>
                  backendById.containsKey(product.productId),
            )
            .map(
              (BillingProduct product) => product.copyWithCreditProduct(
                backendById[product.productId]!,
              ),
            )
            .toList(growable: false)
          ..sort(
            (BillingProduct a, BillingProduct b) =>
                a.displayRank.compareTo(b.displayRank),
          );
    return products;
  }
}

class _CatalogSourceResult<T> {
  const _CatalogSourceResult.success(this.value)
    : error = null,
      isRetryable = false;

  const _CatalogSourceResult.failure(this.error, {required this.isRetryable})
    : value = null;

  final T? value;
  final Object? error;
  final bool isRetryable;
}

Future<_CatalogSourceResult<T>> _captureSource<T>(
  Future<T> Function() load, {
  required bool Function(Object error) isRetryable,
  required bool Function(T value) isEmpty,
}) async {
  try {
    final T value = await load();
    if (isEmpty(value)) {
      return _CatalogSourceResult<T>.failure(
        const _EmptyCatalogResult(),
        isRetryable: true,
      );
    }
    return _CatalogSourceResult<T>.success(value);
  } on Object catch (error) {
    return _CatalogSourceResult<T>.failure(
      error,
      isRetryable: isRetryable(error),
    );
  }
}

bool _isBackendRetryable(Object error) {
  if (error is! BackendApiFailure) {
    return false;
  }
  if (error.code == 'network_error' || error.code == 'network_timeout') {
    return true;
  }
  final int? statusCode = error.statusCode;
  return statusCode == 408 ||
      statusCode == 429 ||
      (statusCode != null && statusCode >= 500);
}

bool _isRevenueCatRetryable(Object error) {
  if (error is! PlatformException) {
    return false;
  }
  final PurchasesErrorCode code;
  try {
    code = PurchasesErrorHelper.getErrorCode(error);
  } on Object {
    return false;
  }
  return switch (code) {
    PurchasesErrorCode.networkError ||
    PurchasesErrorCode.storeProblemError ||
    PurchasesErrorCode.productRequestTimeout ||
    PurchasesErrorCode.apiEndpointBlocked ||
    PurchasesErrorCode.offlineConnectionError ||
    PurchasesErrorCode.unknownBackendError ||
    PurchasesErrorCode.unexpectedBackendResponseError ||
    PurchasesErrorCode.operationAlreadyInProgressError => true,
    _ => false,
  };
}

class _EmptyCatalogResult implements Exception {
  const _EmptyCatalogResult();
}
