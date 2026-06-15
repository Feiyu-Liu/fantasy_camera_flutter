import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredNotificationDevice {
  const StoredNotificationDevice({
    required this.deviceId,
    required this.tokenHash,
    required this.environment,
    required this.topic,
    required this.permissionEnabled,
  });

  final String deviceId;
  final String tokenHash;
  final String environment;
  final String topic;
  final bool permissionEnabled;
}

abstract interface class NotificationDeviceStore {
  Future<String> installationId();

  Future<StoredNotificationDevice?> loadDevice();

  Future<void> saveDevice(StoredNotificationDevice device);

  Future<void> clearDevice();
}

class SharedPreferencesNotificationDeviceStore
    implements NotificationDeviceStore {
  const SharedPreferencesNotificationDeviceStore();

  static const String _installationIdKey =
      'notifications.installation_id.v1';
  static const String _deviceIdKey = 'notifications.device_id.v1';
  static const String _tokenHashKey = 'notifications.token_hash.v1';
  static const String _environmentKey = 'notifications.environment.v1';
  static const String _topicKey = 'notifications.topic.v1';
  static const String _permissionEnabledKey =
      'notifications.permission_enabled.v1';

  @override
  Future<String> installationId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? existing = prefs.getString(_installationIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final String created = _randomIdentifier();
    await prefs.setString(_installationIdKey, created);
    return created;
  }

  @override
  Future<StoredNotificationDevice?> loadDevice() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? deviceId = prefs.getString(_deviceIdKey);
    final String? tokenHash = prefs.getString(_tokenHashKey);
    final String? environment = prefs.getString(_environmentKey);
    final String? topic = prefs.getString(_topicKey);
    if (deviceId == null ||
        deviceId.isEmpty ||
        tokenHash == null ||
        tokenHash.isEmpty ||
        environment == null ||
        environment.isEmpty ||
        topic == null ||
        topic.isEmpty) {
      return null;
    }
    return StoredNotificationDevice(
      deviceId: deviceId,
      tokenHash: tokenHash,
      environment: environment,
      topic: topic,
      permissionEnabled: prefs.getBool(_permissionEnabledKey) ?? false,
    );
  }

  @override
  Future<void> saveDevice(StoredNotificationDevice device) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      prefs.setString(_deviceIdKey, device.deviceId),
      prefs.setString(_tokenHashKey, device.tokenHash),
      prefs.setString(_environmentKey, device.environment),
      prefs.setString(_topicKey, device.topic),
      prefs.setBool(_permissionEnabledKey, device.permissionEnabled),
    ]);
  }

  @override
  Future<void> clearDevice() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      prefs.remove(_deviceIdKey),
      prefs.remove(_tokenHashKey),
      prefs.remove(_environmentKey),
      prefs.remove(_topicKey),
      prefs.remove(_permissionEnabledKey),
    ]);
  }
}

String notificationTokenHash(String token) {
  return sha256.convert(token.codeUnits).toString();
}

String _randomIdentifier() {
  final Random random = Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final String hex = bytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
