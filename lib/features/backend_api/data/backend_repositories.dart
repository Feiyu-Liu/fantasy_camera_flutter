import 'dart:typed_data';

import 'checksum.dart';
import 'fantasy_api_client.dart';
import '../domain/app_input_contract.dart';
import '../domain/credit_balance.dart';
import '../domain/feedback.dart';
import '../domain/generation_task.dart';
import '../domain/json_value.dart';
import '../domain/upload_session.dart';
import '../../notifications/domain/notification_device.dart';

abstract interface class AppConfigRepository {
  Future<AppInputContract> fetchAppInputContract({String? contractKey});
}

class WorkerAppConfigRepository implements AppConfigRepository {
  const WorkerAppConfigRepository(this._client);

  final FantasyApiClient _client;

  @override
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

abstract interface class CreditsRepository {
  Future<CreditBalance> fetchBalance();
}

class WorkerCreditsRepository implements CreditsRepository {
  const WorkerCreditsRepository(this._client);

  final FantasyApiClient _client;

  @override
  Future<CreditBalance> fetchBalance() {
    return _client.get<CreditBalance>(
      '/v1/credits/balance',
      decode: (Object? data) => decodeJsonObject(data, CreditBalance.fromJson),
    );
  }
}

abstract interface class UploadRepository {
  Future<UploadSession> createUpload({
    required String contentType,
    required Uint8List bytes,
  });

  Future<void> uploadBytes({
    required UploadSession uploadSession,
    required Uint8List bytes,
  });

  Future<JsonObject> completeUpload(String uploadSessionId);
}

class WorkerUploadRepository implements UploadRepository {
  const WorkerUploadRepository(this._client);

  final FantasyApiClient _client;

  @override
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

  @override
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

  @override
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

abstract interface class GenerationTaskRepository {
  Future<CreatedGenerationTask> createTask(CreateGenerationTaskInput input);

  Future<GenerationTask> fetchTask(String taskId);

  Future<GenerationTasksBatchResult> fetchTasksBatch(List<String> taskIds);

  Future<List<GenerationTask>> listTasks({int limit = 20});

  Future<GenerationTask> cancelTask(String taskId);

  Future<ResultUrl> createResultUrl(String taskId);
}

class WorkerGenerationTaskRepository implements GenerationTaskRepository {
  const WorkerGenerationTaskRepository(this._client);

  final FantasyApiClient _client;

  @override
  Future<CreatedGenerationTask> createTask(CreateGenerationTaskInput input) {
    return _client.post<CreatedGenerationTask>(
      '/v1/generation-tasks',
      data: input.toJson(),
      decode: (Object? data) {
        return decodeJsonObject(data, CreatedGenerationTask.fromJson);
      },
    );
  }

  @override
  Future<GenerationTask> fetchTask(String taskId) {
    return _client.get<GenerationTask>(
      '/v1/generation-tasks/$taskId',
      decode: (Object? data) => decodeJsonObject(data, GenerationTask.fromJson),
    );
  }

  @override
  Future<GenerationTasksBatchResult> fetchTasksBatch(List<String> taskIds) {
    return _client.post<GenerationTasksBatchResult>(
      '/v1/generation-tasks/batch',
      data: <String, Object?>{'taskIds': taskIds},
      decode: (Object? data) {
        return decodeJsonObject(data, GenerationTasksBatchResult.fromJson);
      },
    );
  }

  @override
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

  @override
  Future<GenerationTask> cancelTask(String taskId) {
    return _client.post<GenerationTask>(
      '/v1/generation-tasks/$taskId/cancel',
      decode: (Object? data) => decodeJsonObject(data, GenerationTask.fromJson),
    );
  }

  @override
  Future<ResultUrl> createResultUrl(String taskId) {
    return _client.post<ResultUrl>(
      '/v1/generation-tasks/$taskId/result-url',
      decode: (Object? data) => decodeJsonObject(data, ResultUrl.fromJson),
    );
  }
}

abstract interface class NotificationDeviceRepository {
  Future<RegisteredNotificationDevice> registerDevice(
    RegisterNotificationDeviceInput input,
  );

  Future<UnregisteredNotificationDevice> unregisterDevice(String deviceId);

  Future<RegisteredNotificationDevice> updatePermission({
    required String deviceId,
    required bool permissionEnabled,
  });
}

class WorkerNotificationDeviceRepository
    implements NotificationDeviceRepository {
  const WorkerNotificationDeviceRepository(this._client);

  final FantasyApiClient _client;

  @override
  Future<RegisteredNotificationDevice> registerDevice(
    RegisterNotificationDeviceInput input,
  ) {
    return _client.post<RegisteredNotificationDevice>(
      '/v1/notifications/devices',
      data: input.toJson(),
      decode: (Object? data) {
        return decodeJsonObject(data, RegisteredNotificationDevice.fromJson);
      },
    );
  }

  @override
  Future<UnregisteredNotificationDevice> unregisterDevice(String deviceId) {
    return _client.delete<UnregisteredNotificationDevice>(
      '/v1/notifications/devices/$deviceId',
      decode: (Object? data) {
        return decodeJsonObject(data, UnregisteredNotificationDevice.fromJson);
      },
    );
  }

  @override
  Future<RegisteredNotificationDevice> updatePermission({
    required String deviceId,
    required bool permissionEnabled,
  }) {
    return _client.patch<RegisteredNotificationDevice>(
      '/v1/notifications/devices/$deviceId/permission',
      data: UpdateNotificationPermissionInput(
        permissionEnabled: permissionEnabled,
      ).toJson(),
      decode: (Object? data) {
        return decodeJsonObject(data, RegisteredNotificationDevice.fromJson);
      },
    );
  }
}

abstract interface class FeedbackRepository {
  Future<FeedbackSubmission> submitFeedback(FeedbackInput input);
}

class WorkerFeedbackRepository implements FeedbackRepository {
  const WorkerFeedbackRepository(this._client);

  final FantasyApiClient _client;

  @override
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
