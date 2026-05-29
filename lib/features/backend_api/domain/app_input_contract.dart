import 'json_value.dart';

class AppInputContract {
  const AppInputContract({
    required this.id,
    required this.contractKey,
    required this.version,
    required this.config,
    required this.costRules,
    required this.publicMetadata,
    this.minAppVersion,
    this.activatedAt,
  });

  final String id;
  final String contractKey;
  final String version;
  final String? minAppVersion;
  final JsonObject config;
  final JsonObject costRules;
  final JsonObject publicMetadata;
  final DateTime? activatedAt;

  factory AppInputContract.fromJson(JsonObject json) {
    return AppInputContract(
      id: _readString(json, 'id'),
      contractKey: _readString(json, 'contractKey'),
      version: _readString(json, 'version'),
      minAppVersion: json['minAppVersion'] as String?,
      config: _readObject(json, 'config'),
      costRules: _readObject(json, 'costRules'),
      publicMetadata: _readObject(json, 'publicMetadata'),
      activatedAt: _readDateTime(json, 'activatedAt'),
    );
  }
}

String _readString(JsonObject json, String key) {
  final Object? value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected string field "$key".');
}

JsonObject _readObject(JsonObject json, String key) {
  final Object? value = json[key];
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  throw FormatException('Expected object field "$key".');
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
