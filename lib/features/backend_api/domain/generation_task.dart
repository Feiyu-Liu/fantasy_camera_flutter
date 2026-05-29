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
  });

  final String uploadSessionId;
  final String promptStyle;
  final String captureMode;
  final JsonObject userInput;
  final String? appInputContractId;

  JsonObject toJson() {
    return <String, Object?>{
      'uploadSessionId': uploadSessionId,
      'promptStyle': promptStyle,
      'captureMode': captureMode,
      if (userInput.isNotEmpty) 'userInput': userInput,
      if (appInputContractId != null) 'appInputContractId': appInputContractId,
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
