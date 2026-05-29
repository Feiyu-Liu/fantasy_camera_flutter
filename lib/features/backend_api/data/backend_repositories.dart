import 'dart:typed_data';

import 'checksum.dart';
import 'fantasy_api_client.dart';
import '../domain/app_input_contract.dart';
import '../domain/credit_balance.dart';
import '../domain/feedback.dart';
import '../domain/generation_task.dart';
import '../domain/json_value.dart';
import '../domain/upload_session.dart';

class AppConfigRepository {
  const AppConfigRepository(this._client);

  final FantasyApiClient _client;

  Future<AppInputContract> fetchAppInputContract({String? contractKey}) {
    return _client.get<AppInputContract>(
      '/v1/app-config',
      queryParameters: <String, Object?>{
        if (contractKey case final String value) 'contractKey': value,
      },
      decode: (Object? data) {
        return decodeJsonObject(data, AppInputContract.fromJson);
      },
    );
  }
}

class CreditsRepository {
  const CreditsRepository(this._client);

  final FantasyApiClient _client;

  Future<CreditBalance> fetchBalance() {
    return _client.get<CreditBalance>(
      '/v1/credits/balance',
      decode: (Object? data) => decodeJsonObject(data, CreditBalance.fromJson),
    );
  }
}

class UploadRepository {
  const UploadRepository(this._client);

  final FantasyApiClient _client;

  Future<UploadSession> createUpload({
    required String contentType,
    required Uint8List bytes,
  }) {
    return _client.post<UploadSession>(
      '/v1/uploads',
      data: <String, Object?>{
        'contentType': contentType,
        'byteSize': bytes.length,
        'checksumSha256': sha256Base64(bytes),
      },
      decode: (Object? data) => decodeJsonObject(data, UploadSession.fromJson),
    );
  }

  Future<void> uploadBytes({
    required UploadSession uploadSession,
    required Uint8List bytes,
  }) {
    return _client.putBytes(
      uploadSession.url,
      bytes: bytes,
      headers: uploadSession.requiredHeaders,
    );
  }

  Future<JsonObject> completeUpload(String uploadSessionId) {
    return _client.post<JsonObject>(
      '/v1/uploads/$uploadSessionId/complete',
      decode: (Object? data) {
        if (data is Map<String, Object?>) {
          return data;
        }
        if (data is Map) {
          return Map<String, Object?>.from(data);
        }
        throw const FormatException('Expected upload completion object.');
      },
    );
  }
}

class GenerationTaskRepository {
  const GenerationTaskRepository(this._client);

  final FantasyApiClient _client;

  Future<CreatedGenerationTask> createTask(CreateGenerationTaskInput input) {
    return _client.post<CreatedGenerationTask>(
      '/v1/generation-tasks',
      data: input.toJson(),
      decode: (Object? data) {
        return decodeJsonObject(data, CreatedGenerationTask.fromJson);
      },
    );
  }

  Future<GenerationTask> fetchTask(String taskId) {
    return _client.get<GenerationTask>(
      '/v1/generation-tasks/$taskId',
      decode: (Object? data) => decodeJsonObject(data, GenerationTask.fromJson),
    );
  }

  Future<List<GenerationTask>> listTasks({int limit = 20}) {
    return _client.get<List<GenerationTask>>(
      '/v1/generation-tasks',
      queryParameters: <String, Object?>{'limit': limit},
      decode: (Object? data) {
        final JsonObject json = data is Map<String, Object?>
            ? data
            : Map<String, Object?>.from(data as Map);
        return decodeJsonObjectList(json['tasks'], GenerationTask.fromJson);
      },
    );
  }

  Future<GenerationTask> cancelTask(String taskId) {
    return _client.post<GenerationTask>(
      '/v1/generation-tasks/$taskId/cancel',
      decode: (Object? data) => decodeJsonObject(data, GenerationTask.fromJson),
    );
  }

  Future<ResultUrl> createResultUrl(String taskId) {
    return _client.post<ResultUrl>(
      '/v1/generation-tasks/$taskId/result-url',
      decode: (Object? data) => decodeJsonObject(data, ResultUrl.fromJson),
    );
  }
}

class FeedbackRepository {
  const FeedbackRepository(this._client);

  final FantasyApiClient _client;

  Future<FeedbackSubmission> submitFeedback(FeedbackInput input) {
    return _client.post<FeedbackSubmission>(
      '/v1/feedback',
      data: input.toJson(),
      decode: (Object? data) {
        return decodeJsonObject(data, FeedbackSubmission.fromJson);
      },
    );
  }
}
