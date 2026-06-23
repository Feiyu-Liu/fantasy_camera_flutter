import 'json_value.dart';

class CreditBalance {
  const CreditBalance({
    required this.balance,
    required this.reservedBalance,
    required this.lifetimeEarned,
    required this.lifetimeSpent,
    required this.updatedAt,
  });

  final int balance;
  final int reservedBalance;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final DateTime updatedAt;

  factory CreditBalance.fromJson(JsonObject json) {
    return CreditBalance(
      balance: _readInt(json, 'balance'),
      reservedBalance: _readInt(json, 'reservedBalance'),
      lifetimeEarned: _readInt(json, 'lifetimeEarned'),
      lifetimeSpent: _readInt(json, 'lifetimeSpent'),
      updatedAt: DateTime.parse(_readString(json, 'updatedAt')),
    );
  }

  JsonObject toJson() {
    return <String, Object?>{
      'balance': balance,
      'reservedBalance': reservedBalance,
      'lifetimeEarned': lifetimeEarned,
      'lifetimeSpent': lifetimeSpent,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
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

String _readString(JsonObject json, String key) {
  final Object? value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected string field "$key".');
}
