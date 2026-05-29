enum GenerationSubmissionStatus {
  queued,
  readingFile,
  creatingUpload,
  uploading,
  completingUpload,
  creatingTask,
  submitted,
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
  final String? errorCode;
  final String? errorMessage;

  bool get isTerminal =>
      status == GenerationSubmissionStatus.submitted ||
      status == GenerationSubmissionStatus.failed;

  GenerationSubmissionJob copyWith({
    GenerationSubmissionStatus? status,
    DateTime? updatedAt,
    String? uploadSessionId,
    String? taskId,
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
