import 'json_value.dart';

class UploadSession {
  const UploadSession({
    required this.uploadSessionId,
    required this.sourceImageObjectId,
    required this.provider,
    required this.bucket,
    required this.expiresAt,
    required this.requiredHeaders,
    required this.url,
    required this.expiresInSeconds,
  });

  final String uploadSessionId;
  final String sourceImageObjectId;
  final String provider;
  final String bucket;
  final DateTime expiresAt;
  final Map<String, String> requiredHeaders;
  final String url;
  final int expiresInSeconds;

  factory UploadSession.fromJson(JsonObject json) {
    return UploadSession(
      uploadSessionId: _readString(json, 'uploadSessionId'),
      sourceImageObjectId: _readString(json, 'sourceImageObjectId'),
      provider: _readString(json, 'provider'),
      bucket: _readString(json, 'bucket'),
      expiresAt: DateTime.parse(_readString(json, 'expiresAt')),
      requiredHeaders: _readStringMap(json, 'requiredHeaders'),
      url: _readString(json, 'url'),
      expiresInSeconds: _readInt(json, 'expiresInSeconds'),
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

Map<String, String> _readStringMap(JsonObject json, String key) {
  final Object? value = json[key];
  if (value is Map<String, Object?>) {
    return value.map((String key, Object? value) {
      if (value is! String) {
        throw FormatException('Expected string value in "$key".');
      }
      return MapEntry<String, String>(key, value);
    });
  }
  if (value is Map) {
    return value.map((Object? key, Object? value) {
      if (key is! String || value is! String) {
        throw FormatException('Expected string map field "$key".');
      }
      return MapEntry<String, String>(key, value);
    });
  }
  throw FormatException('Expected string map field "$key".');
}
