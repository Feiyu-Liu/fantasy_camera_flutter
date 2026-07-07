import 'credit_product.dart';

class BillingProduct {
  const BillingProduct({
    required this.productId,
    required this.credits,
    required this.displayRank,
    required this.price,
    required this.packageIdentifier,
    this.displayNameKey = '',
    this.savingsPercent,
  });

  final String productId;
  final int credits;
  final int displayRank;
  final String price;
  final String packageIdentifier;
  final String displayNameKey;
  final int? savingsPercent;

  BillingProduct copyWithCreditProduct(CreditProduct product) {
    return BillingProduct(
      productId: productId,
      displayNameKey: product.displayNameKey,
      savingsPercent: product.savingsPercent,
      credits: product.credits,
      displayRank: product.displayRank,
      price: price,
      packageIdentifier: packageIdentifier,
    );
  }
}
