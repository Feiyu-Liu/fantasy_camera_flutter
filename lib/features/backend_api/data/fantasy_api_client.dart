import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../auth/domain/access_token_provider.dart';
import '../domain/api_failure.dart';
import '../domain/json_value.dart';

typedef JsonDecoder<T> = T Function(Object? data);

class FantasyApiClient {
  FantasyApiClient({
    required Dio dio,
    required AccessTokenProvider accessTokenProvider,
  }) : _dio = dio,
       _accessTokenProvider = accessTokenProvider;

  final Dio _dio;
  final AccessTokenProvider _accessTokenProvider;

  Future<T> get<T>(
    String path, {
    Map<String, Object?>? queryParameters,
    required JsonDecoder<T> decode,
  }) {
    return _send<T>(
      () => _authorizedRequest<Object?>(
        () => _dio.get<Object?>(path, queryParameters: queryParameters),
      ),
      decode: decode,
    );
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    required JsonDecoder<T> decode,
  }) {
    return _send<T>(
      () => _authorizedRequest<Object?>(
        () => _dio.post<Object?>(
          path,
          data: data,
          queryParameters: queryParameters,
        ),
      ),
      decode: decode,
    );
  }

  Future<void> putBytes(
    String url, {
    required Uint8List bytes,
    required Map<String, String> headers,
  }) async {
    final Map<String, String> uploadHeaders = <String, String>{...headers};
    try {
      await _putBytesWithHttpClient(url, bytes: bytes, headers: uploadHeaders);
    } on DioException catch (error) {
      throw _failureFromDioException(error);
    } on BackendApiFailure {
      rethrow;
    } on Object catch (error) {
      throw BackendApiFailure(code: 'network_error', message: error.toString());
    }
  }

  Future<T> _send<T>(
    Future<Response<Object?>> Function() request, {
    required JsonDecoder<T> decode,
  }) async {
    try {
      final Response<Object?> response = await request();
      return decode(_readEnvelopeData(response.data));
    } on DioException catch (error) {
      throw _failureFromDioException(error);
    }
  }

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function() request,
  ) async {
    await _attachAccessToken(refresh: false);
    try {
      return await request();
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) {
        rethrow;
      }
      await _attachAccessToken(refresh: true);
      return request();
    }
  }

  Future<void> _attachAccessToken({required bool refresh}) async {
    final String? token = refresh
        ? await _accessTokenProvider.refreshAccessToken()
        : await _accessTokenProvider.ensureValidAccessToken();
    if (token == null || token.isEmpty) {
      throw const BackendApiFailure(
        code: 'unauthorized',
        message: 'Sign in is required.',
        statusCode: 401,
      );
    }
    _dio.options.headers['authorization'] = 'Bearer $token';
  }

  Object? _readEnvelopeData(Object? body) {
    final JsonObject envelope = _asJsonObject(body);
    if (!envelope.containsKey('data')) {
      throw const BackendApiFailure(
        code: 'invalid_response',
        message: 'API response is missing data.',
      );
    }
    return envelope['data'];
  }
}

Future<void> _putBytesWithHttpClient(
  String url, {
  required Uint8List bytes,
  required Map<String, String> headers,
}) async {
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest request = await client.putUrl(Uri.parse(url));
    request.contentLength = bytes.length;
    for (final MapEntry<String, String> header in headers.entries) {
      request.headers.set(header.key, header.value);
    }
    request.add(bytes);
    final HttpClientResponse response = await request.close();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await response.drain<void>();
      return;
    }
    final String body = await utf8.decodeStream(response);
    throw BackendApiFailure(
      code: 'http_error',
      message: body.trim().isEmpty ? 'Upload failed.' : body.trim(),
      statusCode: response.statusCode,
    );
  } finally {
    client.close(force: true);
  }
}

Dio buildFantasyApiDio(String baseUrl) {
  if (baseUrl.isEmpty) {
    throw const BackendApiConfigurationException(
      'WORKER_API_BASE_URL dart-define is required.',
    );
  }

  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: <String, Object?>{'accept': 'application/json'},
    ),
  );
}

T decodeJsonObject<T>(Object? data, T Function(JsonObject json) fromJson) {
  return fromJson(_asJsonObject(data));
}

List<T> decodeJsonObjectList<T>(
  Object? data,
  T Function(JsonObject json) fromJson,
) {
  if (data is! List) {
    throw const FormatException('Expected JSON array.');
  }
  return data
      .map<T>((Object? item) => fromJson(_asJsonObject(item)))
      .toList(growable: false);
}

JsonObject _asJsonObject(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  if (value is String && value.isNotEmpty) {
    final Object? decoded = jsonDecode(value);
    return _asJsonObject(decoded);
  }
  throw const FormatException('Expected JSON object.');
}

BackendApiFailure _failureFromDioException(DioException error) {
  final Object? body = error.response?.data;
  final int? statusCode = error.response?.statusCode;
  if (body != null) {
    try {
      final JsonObject envelope = _asJsonObject(body);
      final Object? rawError = envelope['error'];
      if (rawError is Map || rawError is Map<String, Object?>) {
        final JsonObject apiError = _asJsonObject(rawError);
        return BackendApiFailure(
          code: _stringOrDefault(apiError['code'], 'api_error'),
          message: _stringOrDefault(apiError['message'], 'Request failed.'),
          statusCode: statusCode,
          requestId: envelope['requestId'] as String?,
          details: apiError['details'],
        );
      }
    } on Object {
      if (body is String && body.trim().isNotEmpty) {
        return BackendApiFailure(
          code: 'http_error',
          message: body.trim(),
          statusCode: statusCode,
        );
      }
    }
  }

  return BackendApiFailure(
    code:
        error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout
        ? 'network_timeout'
        : 'network_error',
    message: error.message ?? 'Network request failed.',
    statusCode: statusCode,
  );
}

String _stringOrDefault(Object? value, String fallback) {
  return value is String && value.isNotEmpty ? value : fallback;
}
