import '../../features/backend_api/domain/json_value.dart';

class CreditProduct {
  const CreditProduct({
    required this.productId,
    required this.displayNameKey,
    required this.credits,
    required this.displayRank,
  });

  final String productId;
  final String displayNameKey;
  final int credits;
  final int displayRank;

  factory CreditProduct.fromJson(JsonObject json) {
    return CreditProduct(
      productId: _readString(json, 'productId'),
      displayNameKey: _readString(json, 'displayNameKey'),
      credits: _readInt(json, 'credits'),
      displayRank: _readInt(json, 'displayRank'),
    );
  }
}

class CreditPurchaseSyncResult {
  const CreditPurchaseSyncResult({
    required this.grantedCredits,
    required this.processedPurchases,
    required this.balance,
    required this.products,
  });

  final int grantedCredits;
  final int processedPurchases;
  final int? balance;
  final List<CreditProduct> products;

  factory CreditPurchaseSyncResult.fromJson(JsonObject json) {
    return CreditPurchaseSyncResult(
      grantedCredits: _readInt(json, 'grantedCredits'),
      processedPurchases: _readInt(json, 'processedPurchases'),
      balance: _readOptionalInt(json, 'balance'),
      products: _readProducts(json['products']),
    );
  }
}

String _readString(JsonObject json, String key) {
  final Object? value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected $key to be a string.');
}

int _readInt(JsonObject json, String key) {
  final Object? value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Expected $key to be an int.');
}

int? _readOptionalInt(JsonObject json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  throw FormatException('Expected $key to be an int.');
}

List<CreditProduct> _readProducts(Object? value) {
  if (value is! List) {
    throw const FormatException('Expected products to be a list.');
  }
  return value
      .map((Object? item) {
        if (item is Map<String, Object?>) {
          return CreditProduct.fromJson(item);
        }
        if (item is Map) {
          return CreditProduct.fromJson(Map<String, Object?>.from(item));
        }
        throw const FormatException('Expected product to be an object.');
      })
      .toList(growable: false);
}
