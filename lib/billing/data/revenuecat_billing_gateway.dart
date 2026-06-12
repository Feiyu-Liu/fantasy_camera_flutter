import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../config/app_config.dart';
import '../domain/billing_product.dart';

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

class RevenueCatBillingGateway implements BillingGateway {
  RevenueCatBillingGateway({
    required String iosPublicSdkKey,
    required String offeringId,
  }) : _iosPublicSdkKey = iosPublicSdkKey,
       _offeringId = offeringId;

  final String _iosPublicSdkKey;
  final String _offeringId;
  bool _configured = false;
  String? _configuredUserId;

  @override
  bool get isPurchaseAvailable {
    return !kIsWeb && Platform.isIOS && _iosPublicSdkKey.isNotEmpty;
  }

  @override
  Future<void> logIn(String appUserId) async {
    if (!isPurchaseAvailable) {
      return;
    }
    await _ensureConfigured(appUserId);
    if (_configuredUserId != appUserId) {
      await Purchases.logIn(appUserId);
      _configuredUserId = appUserId;
    }
  }

  @override
  Future<void> logOut() async {
    _configured = false;
    _configuredUserId = null;
  }

  @override
  Future<List<BillingProduct>> fetchProducts() async {
    if (!isPurchaseAvailable) {
      return const <BillingProduct>[];
    }
    await _ensureConfigured(_configuredUserId);
    final Offerings offerings = await Purchases.getOfferings();
    final Offering? offering = _offeringId.isEmpty
        ? offerings.current
        : offerings.getOffering(_offeringId) ?? offerings.current;
    final List<Package> packages =
        offering?.availablePackages ?? const <Package>[];
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
      await Purchases.purchase(PurchaseParams.package(package));
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
    await Purchases.restorePurchases();
  }

  Future<void> _ensureConfigured(String? appUserId) async {
    if (!isPurchaseAvailable) {
      return;
    }
    if (_configured) {
      return;
    }
    await Purchases.setLogLevel(kReleaseMode ? LogLevel.warn : LogLevel.debug);
    final PurchasesConfiguration configuration = PurchasesConfiguration(
      _iosPublicSdkKey,
    );
    if (appUserId != null && appUserId.isNotEmpty) {
      configuration.appUserID = appUserId;
    }
    await Purchases.configure(configuration);
    _configured = true;
    _configuredUserId = appUserId;
  }

  Future<Package> _findPackage(BillingProduct product) async {
    final Offerings offerings = await Purchases.getOfferings();
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
