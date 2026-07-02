import 'generation_record.dart';
import 'generation_submission_job.dart';

enum GenerationRecordRetryPlan {
  none,
  processResultOnly,
  refreshTask,
  recoverUploadSession,
  resubmitFromOriginal,
}

class GenerationRecordRetryDecision {
  const GenerationRecordRetryDecision({
    required this.plan,
    required this.reason,
  });

  final GenerationRecordRetryPlan plan;
  final String reason;
}

class GenerationRecordStateMachine {
  const GenerationRecordStateMachine._();

  static const Set<GenerationRecordPipelineStatus> activeStatuses =
      <GenerationRecordPipelineStatus>{
        GenerationRecordPipelineStatus.preparingUploadImage,
        GenerationRecordPipelineStatus.creatingUpload,
        GenerationRecordPipelineStatus.uploading,
        GenerationRecordPipelineStatus.uploadedWaitingTask,
        GenerationRecordPipelineStatus.creatingTask,
        GenerationRecordPipelineStatus.submitted,
        GenerationRecordPipelineStatus.pollingTask,
        GenerationRecordPipelineStatus.completed,
        GenerationRecordPipelineStatus.processingResultImage,
        GenerationRecordPipelineStatus.resultSaveFailed,
      };

  static const Set<GenerationRecordPipelineStatus> clearableOriginalStatuses =
      <GenerationRecordPipelineStatus>{
        GenerationRecordPipelineStatus.resultSaved,
        GenerationRecordPipelineStatus.canceled,
      };

  static const Set<GenerationRecordPipelineStatus>
  notificationTerminalStatuses = <GenerationRecordPipelineStatus>{
    GenerationRecordPipelineStatus.resultSaved,
    GenerationRecordPipelineStatus.submissionFailed,
    GenerationRecordPipelineStatus.generationFailed,
    GenerationRecordPipelineStatus.resultSaveFailed,
  };

  static GenerationRecordPipelineStatus pipelineStatusFromRecordName(
    String name,
  ) {
    return generationRecordPipelineStatusFromName(name);
  }

  static bool isActive(GenerationRecordPipelineStatus status) {
    return activeStatuses.contains(status);
  }

  static bool isTerminalFailure(GenerationRecordPipelineStatus status) {
    return status == GenerationRecordPipelineStatus.localOriginalSaveFailed ||
        status == GenerationRecordPipelineStatus.submissionFailed ||
        status == GenerationRecordPipelineStatus.generationFailed ||
        status == GenerationRecordPipelineStatus.resultSaveFailed;
  }

  static bool isTerminalSuccess(GenerationRecordPipelineStatus status) {
    return status == GenerationRecordPipelineStatus.resultSaved;
  }

  static bool isUserCanceled(GenerationRecordPipelineStatus status) {
    return status == GenerationRecordPipelineStatus.canceled;
  }

  static bool shouldResume(GenerationRecordPipelineStatus status) {
    return isActive(status) ||
        status == GenerationRecordPipelineStatus.resultSaveFailed;
  }

  static bool shouldPollBatch(GenerationRecordPipelineStatus status) {
    return status == GenerationRecordPipelineStatus.submitted ||
        status == GenerationRecordPipelineStatus.pollingTask ||
        status == GenerationRecordPipelineStatus.uploadedWaitingTask ||
        status == GenerationRecordPipelineStatus.uploading ||
        status == GenerationRecordPipelineStatus.creatingTask;
  }

  static bool canLoadResultUrl(GenerationSubmissionStatus status) {
    return status == GenerationSubmissionStatus.completed ||
        status == GenerationSubmissionStatus.processingResultImage ||
        status == GenerationSubmissionStatus.resultSaved ||
        status == GenerationSubmissionStatus.resultProcessingFailed;
  }

  static bool isTerminalSubmissionStatus(GenerationSubmissionStatus status) {
    return status == GenerationSubmissionStatus.resultSaved ||
        status == GenerationSubmissionStatus.resultProcessingFailed ||
        status == GenerationSubmissionStatus.failed;
  }

  static bool isCreditAffectingTerminalStatus(
    GenerationSubmissionStatus status,
  ) {
    return status == GenerationSubmissionStatus.resultSaved ||
        status == GenerationSubmissionStatus.failed ||
        status == GenerationSubmissionStatus.resultProcessingFailed;
  }

  static bool isNotificationFailureStatus(GenerationSubmissionStatus status) {
    return status == GenerationSubmissionStatus.failed ||
        status == GenerationSubmissionStatus.resultProcessingFailed;
  }

  static GenerationSubmissionStatus? submissionStatusForPipelineStatus(
    GenerationRecordPipelineStatus status,
  ) {
    return switch (status) {
      GenerationRecordPipelineStatus.awaitingConfirmation =>
        GenerationSubmissionStatus.awaitingConfirmation,
      GenerationRecordPipelineStatus.awaitingRetry =>
        GenerationSubmissionStatus.queued,
      GenerationRecordPipelineStatus.localOriginalSaveFailed =>
        GenerationSubmissionStatus.failed,
      GenerationRecordPipelineStatus.submissionFailed =>
        GenerationSubmissionStatus.failed,
      GenerationRecordPipelineStatus.preparingUploadImage =>
        GenerationSubmissionStatus.preparingUploadImage,
      GenerationRecordPipelineStatus.creatingUpload =>
        GenerationSubmissionStatus.creatingUpload,
      GenerationRecordPipelineStatus.uploading =>
        GenerationSubmissionStatus.uploading,
      GenerationRecordPipelineStatus.uploadedWaitingTask =>
        GenerationSubmissionStatus.uploadedWaitingTask,
      GenerationRecordPipelineStatus.creatingTask =>
        GenerationSubmissionStatus.creatingTask,
      GenerationRecordPipelineStatus.submitted =>
        GenerationSubmissionStatus.submitted,
      GenerationRecordPipelineStatus.pollingTask =>
        GenerationSubmissionStatus.pollingTask,
      GenerationRecordPipelineStatus.completed =>
        GenerationSubmissionStatus.completed,
      GenerationRecordPipelineStatus.processingResultImage =>
        GenerationSubmissionStatus.processingResultImage,
      GenerationRecordPipelineStatus.resultSaved =>
        GenerationSubmissionStatus.resultSaved,
      GenerationRecordPipelineStatus.resultSaveFailed =>
        GenerationSubmissionStatus.resultProcessingFailed,
      GenerationRecordPipelineStatus.generationFailed =>
        GenerationSubmissionStatus.failed,
      GenerationRecordPipelineStatus.canceled => null,
    };
  }

  static GenerationRecordFailureStage failureStageForSubmitStage(String stage) {
    return switch (stage) {
      'preparingUploadImage' ||
      'readingFile' => GenerationRecordFailureStage.preparingUploadImage,
      'creatingUpload' => GenerationRecordFailureStage.creatingUpload,
      'uploading' => GenerationRecordFailureStage.uploading,
      'uploadedWaitingTask' => GenerationRecordFailureStage.creatingTask,
      _ => GenerationRecordFailureStage.local,
    };
  }

  static GenerationRecordRetryDecision retryDecision({
    required GenerationRecordPipelineStatus status,
    required String? taskId,
    required String? uploadSessionId,
  }) {
    if (!isTerminalFailure(status)) {
      return const GenerationRecordRetryDecision(
        plan: GenerationRecordRetryPlan.none,
        reason: 'not-terminal-failure',
      );
    }
    if (status == GenerationRecordPipelineStatus.resultSaveFailed &&
        taskId != null &&
        taskId.isNotEmpty) {
      return const GenerationRecordRetryDecision(
        plan: GenerationRecordRetryPlan.processResultOnly,
        reason: 'retry-result-save',
      );
    }
    if (taskId != null && taskId.isNotEmpty) {
      return const GenerationRecordRetryDecision(
        plan: GenerationRecordRetryPlan.refreshTask,
        reason: 'retry-existing-task',
      );
    }
    if (uploadSessionId != null && uploadSessionId.isNotEmpty) {
      return const GenerationRecordRetryDecision(
        plan: GenerationRecordRetryPlan.recoverUploadSession,
        reason: 'retry-upload-session',
      );
    }
    return const GenerationRecordRetryDecision(
      plan: GenerationRecordRetryPlan.resubmitFromOriginal,
      reason: 'retry-from-original',
    );
  }
}
