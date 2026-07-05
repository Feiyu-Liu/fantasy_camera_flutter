import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/credit_balance.dart';
import '../domain/json_value.dart';

abstract interface class CreditBalanceCacheRepository {
  Future<CreditBalance?> loadBalance(String userId);

  Future<void> saveBalance(String userId, CreditBalance balance);

  Future<void> clearBalance(String userId);
}

class SharedPreferencesCreditBalanceCacheRepository
    implements CreditBalanceCacheRepository {
  const SharedPreferencesCreditBalanceCacheRepository();

  static const String _keyPrefix = 'credits.balance.';

  @override
  Future<CreditBalance?> loadBalance(String userId) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? encoded = preferences.getString(_keyFor(userId));
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    final Object? decoded = jsonDecode(encoded);
    final JsonObject json = decoded is Map<String, Object?>
        ? decoded
        : Map<String, Object?>.from(decoded as Map);
    return CreditBalance.fromJson(json);
  }

  @override
  Future<void> saveBalance(String userId, CreditBalance balance) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_keyFor(userId), jsonEncode(balance.toJson()));
  }

  @override
  Future<void> clearBalance(String userId) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(_keyFor(userId));
  }

  String _keyFor(String userId) => '$_keyPrefix$userId';
}
