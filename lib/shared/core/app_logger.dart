import 'package:flutter/foundation.dart';

void appDebugLog(String component, String message) {
  if (kReleaseMode) {
    return;
  }
  debugPrint('[$component] ${sanitizeLogMessage(message)}');
}

void logAppError(String code, Object? message, [StackTrace? stackTrace]) {
  if (kReleaseMode) {
    return;
  }
  debugPrint(
    'Error: ${sanitizeLogMessage(code)}'
    '${message == null ? '' : '\nError Message: ${sanitizeLogMessage(message.toString())}'}',
  );
  if (stackTrace != null) {
    debugPrint(sanitizeLogMessage(stackTrace.toString()));
  }
}

@visibleForTesting
String sanitizeLogMessage(String message) {
  return _redactLongBase64LikeChunks(
    _redactSensitiveKeyValues(_redactLocalPaths(_redactUrlQueries(message))),
  );
}

String _redactUrlQueries(String message) {
  return message.replaceAllMapped(RegExp("https?:\\/\\/[^\\s\"'<>]+"), (match) {
    final String raw = match.group(0)!;
    final String suffix = _trailingPunctuation(raw);
    final String candidate = suffix.isEmpty
        ? raw
        : raw.substring(0, raw.length - suffix.length);
    final Uri? uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasQuery) {
      return raw;
    }
    return '${_urlWithoutQuery(uri)}?[redacted]$suffix';
  });
}

String _urlWithoutQuery(Uri uri) {
  final StringBuffer buffer = StringBuffer()
    ..write(uri.scheme)
    ..write('://')
    ..write(uri.authority)
    ..write(uri.path);
  if (uri.hasFragment) {
    buffer
      ..write('#')
      ..write(uri.fragment);
  }
  return buffer.toString();
}

String _redactLocalPaths(String message) {
  return message.replaceAll(
    RegExp(
      "((?:/private)?/var/mobile/Containers/[^\\s,\"')]+|/Users/[^\\s,\"')]+)",
    ),
    '[local-path]',
  );
}

String _redactSensitiveKeyValues(String message) {
  return message.replaceAllMapped(
    RegExp(
      r'\b(authorization|token|secret|password|cookie|signature|x-amz-signature)=([^\s,&;]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}=[redacted]',
  );
}

String _redactLongBase64LikeChunks(String message) {
  return message.replaceAll(
    RegExp(r'\b[A-Za-z0-9+/]{160,}={0,2}\b'),
    '[base64-redacted]',
  );
}

String _trailingPunctuation(String value) {
  final Match? match = RegExp(r'[),.;:]+$').firstMatch(value);
  return match?.group(0) ?? '';
}
