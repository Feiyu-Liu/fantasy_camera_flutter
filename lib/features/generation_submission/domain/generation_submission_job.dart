import '../../backend_api/domain/generation_task.dart';
import '../../backend_api/domain/prompt_config.dart';

enum GenerationSubmissionStatus {
  awaitingConfirmation,
  queued,
  preparingUploadImage,
  readingFile,
  creatingUpload,
  uploading,
  uploadedWaitingTask,
  creatingTask,
  submitted,
  pollingTask,
  completed,
  processingResultImage,
  resultSaved,
  resultProcessingFailed,
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
    this.promptSelection,
    this.taskId,
    this.taskStatus,
    this.resultImageObjectId,
    this.resultUrl,
    this.resultUrlExpiresAt,
    this.uploadImagePath,
    this.uploadImageSizeBytes,
    this.sourceExif,
    this.processedResultPath,
    this.resultAssetId,
    this.resultNotificationSeenAt,
    this.canSaveOriginalToPhotoLibrary = false,
    this.isResultFavorite = false,
    this.resultFavoriteFeedbackSubmittedAt,
    this.resultNegativeFeedbackSubmittedAt,
    this.resultSaveErrorCode,
    this.resultSaveErrorMessage,
    this.errorCode,
    this.errorMessage,
  });

  final String id;
  final String imagePath;
  final GenerationSubmissionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? uploadSessionId;
  final PromptSelectionSnapshot? promptSelection;
  final String? taskId;
  final GenerationTaskStatus? taskStatus;
  final String? resultImageObjectId;
  final String? resultUrl;
  final DateTime? resultUrlExpiresAt;
  final String? uploadImagePath;
  final int? uploadImageSizeBytes;
  final Map<String, Object>? sourceExif;
  final String? processedResultPath;
  final String? resultAssetId;
  final DateTime? resultNotificationSeenAt;
  final bool canSaveOriginalToPhotoLibrary;
  final bool isResultFavorite;
  final DateTime? resultFavoriteFeedbackSubmittedAt;
  final DateTime? resultNegativeFeedbackSubmittedAt;
  final String? resultSaveErrorCode;
  final String? resultSaveErrorMessage;
  final String? errorCode;
  final String? errorMessage;

  bool get isTerminal =>
      status == GenerationSubmissionStatus.completed ||
      status == GenerationSubmissionStatus.resultSaved ||
      status == GenerationSubmissionStatus.resultProcessingFailed ||
      status == GenerationSubmissionStatus.failed;

  bool get hasFreshResultUrl {
    final String? url = resultUrl;
    final DateTime? expiresAt = resultUrlExpiresAt;
    return url != null &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now());
  }

  bool get hasSubmittedNegativeFeedback =>
      resultNegativeFeedbackSubmittedAt != null;

  GenerationSubmissionJob copyWith({
    GenerationSubmissionStatus? status,
    DateTime? updatedAt,
    String? uploadSessionId,
    PromptSelectionSnapshot? promptSelection,
    String? taskId,
    GenerationTaskStatus? taskStatus,
    String? resultImageObjectId,
    String? resultUrl,
    DateTime? resultUrlExpiresAt,
    String? uploadImagePath,
    int? uploadImageSizeBytes,
    Map<String, Object>? sourceExif,
    String? processedResultPath,
    String? resultAssetId,
    DateTime? resultNotificationSeenAt,
    bool? canSaveOriginalToPhotoLibrary,
    bool? isResultFavorite,
    DateTime? resultFavoriteFeedbackSubmittedAt,
    DateTime? resultNegativeFeedbackSubmittedAt,
    String? resultSaveErrorCode,
    String? resultSaveErrorMessage,
    String? errorCode,
    String? errorMessage,
    bool clearError = false,
    bool clearResultSaveError = false,
  }) {
    return GenerationSubmissionJob(
      id: id,
      imagePath: imagePath,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      uploadSessionId: uploadSessionId ?? this.uploadSessionId,
      promptSelection: promptSelection ?? this.promptSelection,
      taskId: taskId ?? this.taskId,
      taskStatus: taskStatus ?? this.taskStatus,
      resultImageObjectId: resultImageObjectId ?? this.resultImageObjectId,
      resultUrl: resultUrl ?? this.resultUrl,
      resultUrlExpiresAt: resultUrlExpiresAt ?? this.resultUrlExpiresAt,
      uploadImagePath: uploadImagePath ?? this.uploadImagePath,
      uploadImageSizeBytes: uploadImageSizeBytes ?? this.uploadImageSizeBytes,
      sourceExif: sourceExif ?? this.sourceExif,
      processedResultPath: processedResultPath ?? this.processedResultPath,
      resultAssetId: resultAssetId ?? this.resultAssetId,
      resultNotificationSeenAt:
          resultNotificationSeenAt ?? this.resultNotificationSeenAt,
      canSaveOriginalToPhotoLibrary:
          canSaveOriginalToPhotoLibrary ?? this.canSaveOriginalToPhotoLibrary,
      isResultFavorite: isResultFavorite ?? this.isResultFavorite,
      resultFavoriteFeedbackSubmittedAt:
          resultFavoriteFeedbackSubmittedAt ??
          this.resultFavoriteFeedbackSubmittedAt,
      resultNegativeFeedbackSubmittedAt:
          resultNegativeFeedbackSubmittedAt ??
          this.resultNegativeFeedbackSubmittedAt,
      resultSaveErrorCode: clearResultSaveError
          ? null
          : resultSaveErrorCode ?? this.resultSaveErrorCode,
      resultSaveErrorMessage: clearResultSaveError
          ? null
          : resultSaveErrorMessage ?? this.resultSaveErrorMessage,
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
