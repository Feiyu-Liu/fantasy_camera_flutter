import 'credit_product.dart';

class BillingProduct {
  const BillingProduct({
    required this.productId,
    required this.credits,
    required this.displayRank,
    required this.price,
    required this.packageIdentifier,
  });

  final String productId;
  final int credits;
  final int displayRank;
  final String price;
  final String packageIdentifier;

  BillingProduct copyWithCreditProduct(CreditProduct product) {
    return BillingProduct(
      productId: productId,
      credits: product.credits,
      displayRank: product.displayRank,
      price: price,
      packageIdentifier: packageIdentifier,
    );
  }
}
