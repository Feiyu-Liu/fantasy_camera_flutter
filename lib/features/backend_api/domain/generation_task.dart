import '../../../config/app_config.dart';
import 'json_value.dart';

enum GenerationTaskStatus {
  pending,
  processing,
  modelRunning,
  completed,
  failed,
  canceled,
  unknown;

  factory GenerationTaskStatus.fromWire(String value) {
    return switch (value) {
      'pending' => GenerationTaskStatus.pending,
      'processing' => GenerationTaskStatus.processing,
      'model_running' => GenerationTaskStatus.modelRunning,
      'completed' => GenerationTaskStatus.completed,
      'failed' => GenerationTaskStatus.failed,
      'canceled' => GenerationTaskStatus.canceled,
      _ => GenerationTaskStatus.unknown,
    };
  }

  String get wireValue {
    return switch (this) {
      GenerationTaskStatus.pending => 'pending',
      GenerationTaskStatus.processing => 'processing',
      GenerationTaskStatus.modelRunning => 'model_running',
      GenerationTaskStatus.completed => 'completed',
      GenerationTaskStatus.failed => 'failed',
      GenerationTaskStatus.canceled => 'canceled',
      GenerationTaskStatus.unknown => 'unknown',
    };
  }
}

class CreateGenerationTaskInput {
  const CreateGenerationTaskInput({
    required this.uploadSessionId,
    required this.promptStyle,
    required this.captureMode,
    this.userInput = const <String, Object?>{},
    this.appInputContractId,
    this.originDeviceId,
  });

  final String uploadSessionId;
  final String promptStyle;
  final String captureMode;
  final JsonObject userInput;
  final String? appInputContractId;
  final String? originDeviceId;

  JsonObject toJson({bool includeUploadSessionId = true}) {
    final JsonObject requestUserInput = <String, Object?>{
      'promptConfigVersion': AppConfig.promptConfigVersion,
      ...userInput,
    };
    return <String, Object?>{
      if (includeUploadSessionId) 'uploadSessionId': uploadSessionId,
      'promptStyle': promptStyle,
      'captureMode': captureMode,
      'userInput': requestUserInput,
      if (appInputContractId != null) 'appInputContractId': appInputContractId,
      if (originDeviceId != null) 'originDeviceId': originDeviceId,
    };
  }
}

class CreatedGenerationTask {
  const CreatedGenerationTask({
    required this.taskId,
    required this.status,
    required this.creditReservationId,
    required this.costCredits,
  });

  final String taskId;
  final GenerationTaskStatus status;
  final String creditReservationId;
  final int costCredits;

  factory CreatedGenerationTask.fromJson(JsonObject json) {
    return CreatedGenerationTask(
      taskId: _readString(json, 'taskId'),
      status: GenerationTaskStatus.fromWire(_readString(json, 'status')),
      creditReservationId: _readString(json, 'creditReservationId'),
      costCredits: _readInt(json, 'costCredits'),
    );
  }
}

class GenerationTask {
  const GenerationTask({
    required this.id,
    required this.status,
    required this.promptStyle,
    required this.captureMode,
    required this.sourceImageObjectId,
    required this.costCredits,
    required this.attemptCount,
    required this.maxAttempts,
    required this.createdAt,
    this.resultImageObjectId,
    this.lastErrorCode,
    this.lastErrorMessage,
    this.completedAt,
    this.failedAt,
    this.canceledAt,
  });

  final String id;
  final GenerationTaskStatus status;
  final String promptStyle;
  final String captureMode;
  final String sourceImageObjectId;
  final String? resultImageObjectId;
  final int costCredits;
  final int attemptCount;
  final int maxAttempts;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? failedAt;
  final DateTime? canceledAt;

  bool get canCancel =>
      status == GenerationTaskStatus.pending ||
      status == GenerationTaskStatus.processing;

  bool get isTerminal =>
      status == GenerationTaskStatus.completed ||
      status == GenerationTaskStatus.failed ||
      status == GenerationTaskStatus.canceled;

  factory GenerationTask.fromJson(JsonObject json) {
    return GenerationTask(
      id: _readString(json, 'id'),
      status: GenerationTaskStatus.fromWire(_readString(json, 'status')),
      promptStyle: _readString(json, 'promptStyle'),
      captureMode: _readString(json, 'captureMode'),
      sourceImageObjectId: _readString(json, 'sourceImageObjectId'),
      resultImageObjectId: json['resultImageObjectId'] as String?,
      costCredits: _readInt(json, 'costCredits'),
      attemptCount: _readInt(json, 'attemptCount'),
      maxAttempts: _readInt(json, 'maxAttempts'),
      lastErrorCode: json['lastErrorCode'] as String?,
      lastErrorMessage: json['lastErrorMessage'] as String?,
      createdAt: DateTime.parse(_readString(json, 'createdAt')),
      completedAt: _readNullableDateTime(json, 'completedAt'),
      failedAt: _readNullableDateTime(json, 'failedAt'),
      canceledAt: _readNullableDateTime(json, 'canceledAt'),
    );
  }
}

class GenerationTasksBatchResult {
  const GenerationTasksBatchResult({
    required this.tasks,
    required this.missingIds,
  });

  final List<GenerationTask> tasks;
  final List<String> missingIds;

  factory GenerationTasksBatchResult.fromJson(JsonObject json) {
    return GenerationTasksBatchResult(
      tasks: _readGenerationTaskList(json, 'tasks'),
      missingIds: _readStringList(json, 'missingIds'),
    );
  }
}

class ResultUrl {
  const ResultUrl({required this.url, required this.expiresInSeconds});

  final String url;
  final int expiresInSeconds;

  factory ResultUrl.fromJson(JsonObject json) {
    return ResultUrl(
      url: _readString(json, 'url'),
      expiresInSeconds: _readInt(json, 'expiresInSeconds'),
    );
  }
}

List<GenerationTask> _readGenerationTaskList(JsonObject json, String key) {
  final Object? value = json[key];
  if (value is List) {
    return value
        .map((Object? item) {
          if (item is Map<String, Object?>) {
            return GenerationTask.fromJson(item);
          }
          if (item is Map) {
            return GenerationTask.fromJson(Map<String, Object?>.from(item));
          }
          throw FormatException('Expected object item in "$key".');
        })
        .toList(growable: false);
  }
  throw FormatException('Expected object list field "$key".');
}

List<String> _readStringList(JsonObject json, String key) {
  final Object? value = json[key];
  if (value is List) {
    return value
        .map((Object? item) {
          if (item is String) {
            return item;
          }
          throw FormatException('Expected string item in "$key".');
        })
        .toList(growable: false);
  }
  throw FormatException('Expected string list field "$key".');
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

DateTime? _readNullableDateTime(JsonObject json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return DateTime.parse(value);
  }
  throw FormatException('Expected date-time field "$key".');
}
