class RegisteredNotificationDevice {
  const RegisteredNotificationDevice({
    required this.id,
    required this.installationId,
    required this.platform,
    required this.environment,
    required this.topic,
    required this.permissionEnabled,
    this.locale,
  });

  final String id;
  final String installationId;
  final String platform;
  final String environment;
  final String topic;
  final bool permissionEnabled;
  final String? locale;

  factory RegisteredNotificationDevice.fromJson(Map<String, Object?> json) {
    return RegisteredNotificationDevice(
      id: _readString(json, 'id'),
      installationId: _readString(json, 'installationId'),
      platform: _readString(json, 'platform'),
      environment: _readString(json, 'environment'),
      topic: _readString(json, 'topic'),
      permissionEnabled: _readBool(json, 'permissionEnabled'),
      locale: json['locale'] as String?,
    );
  }
}

class RegisterNotificationDeviceInput {
  const RegisterNotificationDeviceInput({
    required this.installationId,
    required this.deviceToken,
    required this.environment,
    required this.topic,
    required this.permissionEnabled,
    this.locale,
  });

  final String installationId;
  final String deviceToken;
  final String environment;
  final String topic;
  final bool permissionEnabled;
  final String? locale;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'installationId': installationId,
      'deviceToken': deviceToken,
      'environment': environment,
      'topic': topic,
      if (locale != null && locale!.isNotEmpty) 'locale': locale,
      'permissionEnabled': permissionEnabled,
    };
  }
}

class UpdateNotificationPermissionInput {
  const UpdateNotificationPermissionInput({required this.permissionEnabled});

  final bool permissionEnabled;

  Map<String, Object?> toJson() {
    return <String, Object?>{'permissionEnabled': permissionEnabled};
  }
}

class UnregisteredNotificationDevice {
  const UnregisteredNotificationDevice({
    required this.deviceId,
    required this.unregistered,
  });

  final String deviceId;
  final bool unregistered;

  factory UnregisteredNotificationDevice.fromJson(Map<String, Object?> json) {
    return UnregisteredNotificationDevice(
      deviceId: _readString(json, 'deviceId'),
      unregistered: _readBool(json, 'unregistered'),
    );
  }
}

String _readString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Expected non-empty string field "$key".');
}

bool _readBool(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected boolean field "$key".');
}
