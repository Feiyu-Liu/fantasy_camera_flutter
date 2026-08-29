import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../config/app_config.dart';
import '../domain/billing_product.dart';
import '../../shared/core/app_logger.dart';

sealed class BillingPurchaseOutcome {
  const BillingPurchaseOutcome();
}

class BillingPurchaseCompleted extends BillingPurchaseOutcome {
  const BillingPurchaseCompleted();
}

class BillingPurchaseCancelled extends BillingPurchaseOutcome {
  const BillingPurchaseCancelled();
}

class BillingPurchaseFailed extends BillingPurchaseOutcome {
  const BillingPurchaseFailed(this.error);

  final Object error;
}

abstract interface class BillingGateway {
  bool get isPurchaseAvailable;

  Future<void> logIn(String appUserId);

  Future<void> logOut();

  Future<List<BillingProduct>> fetchProducts();

  Future<BillingPurchaseOutcome> purchaseProduct(BillingProduct product);

  Future<void> restorePurchases();
}

abstract interface class RevenueCatClient {
  Future<void> setLogLevel(LogLevel level);

  Future<void> configure(PurchasesConfiguration configuration);

  Future<void> logIn(String appUserId);

  Future<void> logOut();

  Future<Offerings> getOfferings();

  Future<void> purchase(PurchaseParams purchaseParams);

  Future<void> restorePurchases();
}

class PurchasesRevenueCatClient implements RevenueCatClient {
  const PurchasesRevenueCatClient();

  @override
  Future<void> configure(PurchasesConfiguration configuration) {
    return Purchases.configure(configuration);
  }

  @override
  Future<Offerings> getOfferings() {
    return Purchases.getOfferings();
  }

  @override
  Future<void> logIn(String appUserId) async {
    await Purchases.logIn(appUserId);
  }

  @override
  Future<void> logOut() async {
    await Purchases.logOut();
  }

  @override
  Future<void> purchase(PurchaseParams purchaseParams) async {
    await Purchases.purchase(purchaseParams);
  }

  @override
  Future<void> restorePurchases() async {
    await Purchases.restorePurchases();
  }

  @override
  Future<void> setLogLevel(LogLevel level) {
    return Purchases.setLogLevel(level);
  }
}

class RevenueCatBillingGateway implements BillingGateway {
  RevenueCatBillingGateway({
    required String iosPublicSdkKey,
    required String offeringId,
    RevenueCatClient client = const PurchasesRevenueCatClient(),
    bool? isPurchaseAvailableOverride,
  }) : _iosPublicSdkKey = iosPublicSdkKey,
       _offeringId = offeringId,
       _client = client,
       _isPurchaseAvailableOverride = isPurchaseAvailableOverride;

  final String _iosPublicSdkKey;
  final String _offeringId;
  final RevenueCatClient _client;
  final bool? _isPurchaseAvailableOverride;
  bool _configured = false;
  String? _configuredUserId;
  Future<void>? _configurationFuture;

  @override
  bool get isPurchaseAvailable {
    return _isPurchaseAvailableOverride ??
        (!kIsWeb && Platform.isIOS && _iosPublicSdkKey.isNotEmpty);
  }

  @override
  Future<void> logIn(String appUserId) async {
    if (!isPurchaseAvailable) {
      return;
    }
    await _ensureConfigured(appUserId);
    if (_configuredUserId != appUserId) {
      await _client.logIn(appUserId);
      _configuredUserId = appUserId;
    }
  }

  @override
  Future<void> logOut() async {
    try {
      if (!isPurchaseAvailable) {
        return;
      }
      final Future<void>? configuration = _configurationFuture;
      if (configuration != null) {
        await configuration;
      }
      if (_configured) {
        await _client.logOut();
      }
    } on Object catch (error, stackTrace) {
      logAppError('billing_revenuecat_logout_failed', error, stackTrace);
    } finally {
      _configuredUserId = null;
    }
  }

  @override
  Future<List<BillingProduct>> fetchProducts() async {
    if (!isPurchaseAvailable) {
      return const <BillingProduct>[];
    }
    await _ensureConfigured(_configuredUserId);
    final Offerings offerings = await _client.getOfferings();
    final Offering? offering = _offeringId.isEmpty
        ? offerings.current
        : offerings.getOffering(_offeringId) ?? offerings.current;
    final List<Package> packages =
        offering?.availablePackages ?? const <Package>[];
    appDebugLog(
      'Billing',
      'RevenueCat products loaded offering=${_offeringId.isEmpty ? 'current' : _offeringId} '
          'resolvedOffering=${offering?.identifier ?? 'none'} packages=${packages.length}',
    );
    return packages
        .map((Package package) {
          return BillingProduct(
            productId: package.storeProduct.identifier,
            credits: 0,
            displayRank: 999,
            price: package.storeProduct.priceString,
            packageIdentifier: package.identifier,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<BillingPurchaseOutcome> purchaseProduct(BillingProduct product) async {
    if (!isPurchaseAvailable) {
      return const BillingPurchaseFailed('Purchases are not available.');
    }
    try {
      await _ensureConfigured(_configuredUserId);
      final Package package = await _findPackage(product);
      await _client.purchase(PurchaseParams.package(package));
      return const BillingPurchaseCompleted();
    } on PlatformException catch (error) {
      final PurchasesErrorCode code = PurchasesErrorHelper.getErrorCode(error);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const BillingPurchaseCancelled();
      }
      return BillingPurchaseFailed(error);
    } on Object catch (error) {
      return BillingPurchaseFailed(error);
    }
  }

  @override
  Future<void> restorePurchases() async {
    if (!isPurchaseAvailable) {
      return;
    }
    await _ensureConfigured(_configuredUserId);
    await _client.restorePurchases();
  }

  Future<void> _ensureConfigured(String? appUserId) async {
    if (!isPurchaseAvailable) {
      return;
    }
    if (_configured) {
      return;
    }
    final Future<void>? existingConfiguration = _configurationFuture;
    if (existingConfiguration != null) {
      await existingConfiguration;
      return;
    }
    final Future<void> configuration = _configure(appUserId);
    _configurationFuture = configuration;
    try {
      await configuration;
    } finally {
      if (identical(_configurationFuture, configuration)) {
        _configurationFuture = null;
      }
    }
  }

  Future<void> _configure(String? appUserId) async {
    await _client.setLogLevel(kReleaseMode ? LogLevel.warn : LogLevel.debug);
    final PurchasesConfiguration configuration = PurchasesConfiguration(
      _iosPublicSdkKey,
    );
    if (appUserId != null && appUserId.isNotEmpty) {
      configuration.appUserID = appUserId;
    }
    await _client.configure(configuration);
    _configured = true;
    _configuredUserId = appUserId;
  }

  Future<Package> _findPackage(BillingProduct product) async {
    final Offerings offerings = await _client.getOfferings();
    final Offering? offering = _offeringId.isEmpty
        ? offerings.current
        : offerings.getOffering(_offeringId) ?? offerings.current;
    final List<Package> packages =
        offering?.availablePackages ?? const <Package>[];
    for (final Package package in packages) {
      if (package.storeProduct.identifier == product.productId ||
          package.identifier == product.packageIdentifier) {
        return package;
      }
    }
    throw StateError('RevenueCat package not found: ${product.productId}');
  }
}

class NoopBillingGateway implements BillingGateway {
  const NoopBillingGateway();

  @override
  bool get isPurchaseAvailable => false;

  @override
  Future<List<BillingProduct>> fetchProducts() async {
    return const <BillingProduct>[];
  }

  @override
  Future<void> logIn(String appUserId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<BillingPurchaseOutcome> purchaseProduct(BillingProduct product) async {
    return const BillingPurchaseFailed('Purchases are not configured.');
  }

  @override
  Future<void> restorePurchases() async {}
}

BillingGateway buildBillingGateway() {
  if (AppConfig.hasRevenueCatIosConfig) {
    return RevenueCatBillingGateway(
      iosPublicSdkKey: AppConfig.revenueCatIosPublicSdkKey,
      offeringId: AppConfig.revenueCatOfferingId,
    );
  }
  return const NoopBillingGateway();
}
