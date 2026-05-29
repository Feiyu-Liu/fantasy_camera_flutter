class BackendApiFailure implements Exception {
  const BackendApiFailure({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
    this.details,
  });

  final String code;
  final String message;
  final int? statusCode;
  final String? requestId;
  final Object? details;

  bool get isUnauthorized => statusCode == 401 || code == 'unauthorized';

  @override
  String toString() {
    final String status = statusCode == null ? '' : ' statusCode=$statusCode';
    final String request = requestId == null ? '' : ' requestId=$requestId';
    return 'BackendApiFailure($code$status$request): $message';
  }
}

class BackendApiConfigurationException implements Exception {
  const BackendApiConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'BackendApiConfigurationException: $message';
}
