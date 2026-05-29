import '../../backend_api/domain/generation_task.dart';

enum GenerationSubmissionStatus {
  queued,
  readingFile,
  creatingUpload,
  uploading,
  completingUpload,
  creatingTask,
  submitted,
  pollingTask,
  completed,
  failed,
}

class GenerationSubmissionJob {
  const GenerationSubmissionJob({
    required this.id,
    required this.imagePath,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.uploadSessionId,
    this.taskId,
    this.taskStatus,
    this.resultImageObjectId,
    this.resultUrl,
    this.resultUrlExpiresAt,
    this.errorCode,
    this.errorMessage,
  });

  final String id;
  final String imagePath;
  final GenerationSubmissionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? uploadSessionId;
  final String? taskId;
  final GenerationTaskStatus? taskStatus;
  final String? resultImageObjectId;
  final String? resultUrl;
  final DateTime? resultUrlExpiresAt;
  final String? errorCode;
  final String? errorMessage;

  bool get isTerminal =>
      status == GenerationSubmissionStatus.completed ||
      status == GenerationSubmissionStatus.failed;

  bool get hasFreshResultUrl {
    final String? url = resultUrl;
    final DateTime? expiresAt = resultUrlExpiresAt;
    return url != null &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now());
  }

  GenerationSubmissionJob copyWith({
    GenerationSubmissionStatus? status,
    DateTime? updatedAt,
    String? uploadSessionId,
    String? taskId,
    GenerationTaskStatus? taskStatus,
    String? resultImageObjectId,
    String? resultUrl,
    DateTime? resultUrlExpiresAt,
    String? errorCode,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GenerationSubmissionJob(
      id: id,
      imagePath: imagePath,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      uploadSessionId: uploadSessionId ?? this.uploadSessionId,
      taskId: taskId ?? this.taskId,
      taskStatus: taskStatus ?? this.taskStatus,
      resultImageObjectId: resultImageObjectId ?? this.resultImageObjectId,
      resultUrl: resultUrl ?? this.resultUrl,
      resultUrlExpiresAt: resultUrlExpiresAt ?? this.resultUrlExpiresAt,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class GenerationSubmissionState {
  const GenerationSubmissionState({
    this.jobs = const <GenerationSubmissionJob>[],
  });

  final List<GenerationSubmissionJob> jobs;

  GenerationSubmissionJob? get latestJob => jobs.firstOrNull;

  List<GenerationSubmissionJob> get activeJobs {
    return jobs
        .where((GenerationSubmissionJob job) => !job.isTerminal)
        .toList(growable: false);
  }
}
