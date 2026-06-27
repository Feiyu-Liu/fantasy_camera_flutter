import 'json_value.dart';

class CreditRedemptionResult {
  const CreditRedemptionResult({
    required this.grantedCredits,
    required this.balance,
    required this.reservedBalance,
    required this.campaignId,
    required this.codeId,
  });

  final int grantedCredits;
  final int balance;
  final int reservedBalance;
  final String campaignId;
  final String codeId;

  factory CreditRedemptionResult.fromJson(JsonObject json) {
    return CreditRedemptionResult(
      grantedCredits: _readInt(json, 'grantedCredits'),
      balance: _readInt(json, 'balance'),
      reservedBalance: _readInt(json, 'reservedBalance'),
      campaignId: _readString(json, 'campaignId'),
      codeId: _readString(json, 'codeId'),
    );
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
