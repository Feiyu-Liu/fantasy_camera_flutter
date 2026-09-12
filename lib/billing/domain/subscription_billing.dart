import '../../features/backend_api/domain/json_value.dart';
import 'billing_product.dart';

enum SubscriptionTier {
  mini,
  plus,
  pro;

  factory SubscriptionTier.fromWire(String value) {
    return SubscriptionTier.values.firstWhere(
      (SubscriptionTier tier) => tier.name == value,
      orElse: () => throw FormatException('Unknown subscription tier: $value'),
    );
  }
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.productIdentifier,
    required this.tier,
    required this.displayOrder,
    required this.fullAllowanceUnits,
    required this.overflowAllowanceUnits,
    required this.maxEnabled,
    required this.revision,
  });

  final String productIdentifier;
  final SubscriptionTier tier;
  final int displayOrder;
  final int fullAllowanceUnits;
  final int overflowAllowanceUnits;
  final bool maxEnabled;
  final int revision;

  factory SubscriptionPlan.fromJson(JsonObject json) {
    return SubscriptionPlan(
      productIdentifier: _readString(json, 'productIdentifier'),
      tier: SubscriptionTier.fromWire(_readString(json, 'tier')),
      displayOrder: _readInt(json, 'displayOrder'),
      fullAllowanceUnits: _readInt(json, 'fullAllowanceUnits'),
      overflowAllowanceUnits: _readInt(json, 'overflowAllowanceUnits'),
      maxEnabled: _readBool(json, 'maxEnabled'),
      revision: _readInt(json, 'revision'),
    );
  }
}

class QualityTierCost {
  const QualityTierCost({
    required this.qualityTier,
    required this.allowanceUnits,
    required this.revision,
  });

  final String qualityTier;
  final int allowanceUnits;
  final int revision;

  factory QualityTierCost.fromJson(JsonObject json) {
    return QualityTierCost(
      qualityTier: _readString(json, 'qualityTier'),
      allowanceUnits: _readInt(json, 'allowanceUnits'),
      revision: _readInt(json, 'revision'),
    );
  }
}

class SubscriptionAccess {
  const SubscriptionAccess({
    required this.active,
    required this.tier,
    required this.productIdentifier,
    required this.willRenew,
    required this.accessEndIsFinal,
    required this.syncFreshness,
    this.accessEndAt,
  });

  final bool active;
  final SubscriptionTier tier;
  final String productIdentifier;
  final bool willRenew;
  final DateTime? accessEndAt;
  final bool accessEndIsFinal;
  final String syncFreshness;

  factory SubscriptionAccess.fromJson(JsonObject json) {
    return SubscriptionAccess(
      active: _readBool(json, 'active'),
      tier: SubscriptionTier.fromWire(_readString(json, 'tier')),
      productIdentifier: _readString(json, 'productIdentifier'),
      willRenew: _readBool(json, 'willRenew'),
      accessEndAt: _readDateTime(json, 'accessEndAt'),
      accessEndIsFinal: _readBool(json, 'accessEndIsFinal'),
      syncFreshness: _readString(json, 'syncFreshness'),
    );
  }
}

class AllowanceWindow {
  const AllowanceWindow({
    required this.windowStart,
    required this.windowEnd,
    required this.nextResetAt,
    required this.fullUsed,
    required this.fullReserved,
    required this.fullRemaining,
    required this.overflowUsed,
    required this.overflowReserved,
    required this.overflowRemaining,
  });

  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime nextResetAt;
  final int fullUsed;
  final int fullReserved;
  final int fullRemaining;
  final int overflowUsed;
  final int overflowReserved;
  final int overflowRemaining;

  int get fullLimit => fullUsed + fullReserved + fullRemaining;

  double get fullUsageFraction {
    final int limit = fullLimit;
    return limit <= 0 ? 1 : (fullUsed + fullReserved) / limit;
  }

  factory AllowanceWindow.fromJson(JsonObject json) {
    return AllowanceWindow(
      windowStart: _readRequiredDateTime(json, 'windowStart'),
      windowEnd: _readRequiredDateTime(json, 'windowEnd'),
      nextResetAt: _readRequiredDateTime(json, 'nextResetAt'),
      fullUsed: _readInt(json, 'fullUsed'),
      fullReserved: _readInt(json, 'fullReserved'),
      fullRemaining: _readInt(json, 'fullRemaining'),
      overflowUsed: _readInt(json, 'overflowUsed'),
      overflowReserved: _readInt(json, 'overflowReserved'),
      overflowRemaining: _readInt(json, 'overflowRemaining'),
    );
  }
}

class BillingCapabilities {
  const BillingCapabilities({
    required this.maxEnabled,
    required this.qualityTiers,
  });

  final bool maxEnabled;
  final Set<String> qualityTiers;

  factory BillingCapabilities.fromJson(JsonObject json) {
    return BillingCapabilities(
      maxEnabled: _readBool(json, 'maxEnabled'),
      qualityTiers: Set<String>.unmodifiable(
        _readList(json, 'qualityTiers').map((Object? value) {
          if (value is String) {
            return value;
          }
          throw const FormatException('Expected quality tier string.');
        }),
      ),
    );
  }
}

class SubscriptionBillingStatus {
  const SubscriptionBillingStatus({
    required this.billingEnvironment,
    required this.capabilities,
    required this.plans,
    required this.qualityTiers,
    this.subscription,
    this.window,
    this.pendingChange,
  });

  final String billingEnvironment;
  final SubscriptionAccess? subscription;
  final AllowanceWindow? window;
  final BillingCapabilities capabilities;
  final List<SubscriptionPlan> plans;
  final List<QualityTierCost> qualityTiers;
  final JsonObject? pendingChange;

  bool get isActive => subscription?.active == true;

  int? allowanceUnitsFor(String qualityTier) {
    for (final QualityTierCost tier in qualityTiers) {
      if (tier.qualityTier == qualityTier) {
        return tier.allowanceUnits;
      }
    }
    return null;
  }

  factory SubscriptionBillingStatus.fromJson(JsonObject json) {
    final JsonObject? subscription = _readObject(json['subscription']);
    final JsonObject? window = _readObject(json['window']);
    return SubscriptionBillingStatus(
      billingEnvironment: _readString(json, 'billingEnvironment'),
      subscription: subscription == null
          ? null
          : SubscriptionAccess.fromJson(subscription),
      window: window == null ? null : AllowanceWindow.fromJson(window),
      capabilities: BillingCapabilities.fromJson(
        _readRequiredObject(json, 'capabilities'),
      ),
      plans: _readObjectList(json, 'plans', SubscriptionPlan.fromJson),
      qualityTiers: _readObjectList(
        json,
        'qualityTiers',
        QualityTierCost.fromJson,
      ),
      pendingChange: _readObject(json['pendingChange']),
    );
  }
}

class SubscriptionProduct {
  const SubscriptionProduct({required this.plan, required this.storeProduct});

  final SubscriptionPlan plan;
  final BillingProduct storeProduct;
}

class SubscriptionCatalog {
  const SubscriptionCatalog({required this.status, required this.products});

  final SubscriptionBillingStatus status;
  final List<SubscriptionProduct> products;
}

String _readString(JsonObject json, String key) {
  final Object? value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected string field "$key".');
}

int _readInt(JsonObject json, String key) {
  final Object? value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('Expected integer field "$key".');
}

bool _readBool(JsonObject json, String key) {
  final Object? value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected boolean field "$key".');
}

DateTime? _readDateTime(JsonObject json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return DateTime.parse(value);
  }
  throw FormatException('Expected date-time field "$key".');
}

DateTime _readRequiredDateTime(JsonObject json, String key) {
  return _readDateTime(json, key) ??
      (throw FormatException('Expected date-time field "$key".'));
}

JsonObject? _readObject(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  throw const FormatException('Expected JSON object.');
}

JsonObject _readRequiredObject(JsonObject json, String key) {
  return _readObject(json[key]) ??
      (throw FormatException('Expected object field "$key".'));
}

List<Object?> _readList(JsonObject json, String key) {
  final Object? value = json[key];
  if (value is List) {
    return value;
  }
  throw FormatException('Expected list field "$key".');
}

List<T> _readObjectList<T>(
  JsonObject json,
  String key,
  T Function(JsonObject json) decode,
) {
  return _readList(
    json,
    key,
  ).map((Object? value) => decode(_readObject(value)!)).toList(growable: false);
}
