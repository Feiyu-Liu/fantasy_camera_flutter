enum GenerationRecordPipelineStatus {
  awaitingConfirmation,
  awaitingRetry,
  localOriginalSaveFailed,
  submissionFailed,
  preparingUploadImage,
  creatingUpload,
  uploading,
  uploadedWaitingTask,
  creatingTask,
  submitted,
  pollingTask,
  completed,
  processingResultImage,
  resultSaved,
  resultSaveFailed,
  generationFailed,
  canceled,
}

enum GenerationRecordFailureStage {
  originalUnavailable,
  preparingUploadImage,
  creatingUpload,
  uploading,
  creatingTask,
  pollingTask,
  backendGeneration,
  processingResult,
  resultSaving,
  local,
}

enum GenerationRecordOriginalSourceType { camera, gallery }

enum GenerationRecordOriginalAvailability {
  available,
  external,
  cleared,
  missing,
}

enum GenerationRecordResultAvailability {
  none,
  localCache,
  savedToPhotoLibrary,
  missing,
}

enum GenerationRecordHashStatus { pending, completed, failed }

GenerationRecordPipelineStatus generationRecordPipelineStatusFromName(
  String name,
) {
  return GenerationRecordPipelineStatus.values.byName(name);
}

GenerationRecordFailureStage generationRecordFailureStageFromName(String name) {
  return GenerationRecordFailureStage.values.byName(name);
}

GenerationRecordFailureStage? generationRecordFailureStageFromNullableName(
  String? name,
) {
  return name == null ? null : generationRecordFailureStageFromName(name);
}

GenerationRecordOriginalSourceType generationRecordOriginalSourceTypeFromName(
  String name,
) {
  return GenerationRecordOriginalSourceType.values.byName(name);
}

GenerationRecordOriginalAvailability
generationRecordOriginalAvailabilityFromName(String name) {
  return GenerationRecordOriginalAvailability.values.byName(name);
}

GenerationRecordResultAvailability generationRecordResultAvailabilityFromName(
  String name,
) {
  return GenerationRecordResultAvailability.values.byName(name);
}

GenerationRecordHashStatus generationRecordHashStatusFromName(String name) {
  return GenerationRecordHashStatus.values.byName(name);
}

const Set<GenerationRecordPipelineStatus> activeGenerationRecordStatuses =
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
    };

const Set<GenerationRecordPipelineStatus> clearableOriginalPipelineStatuses =
    <GenerationRecordPipelineStatus>{
      GenerationRecordPipelineStatus.resultSaved,
      GenerationRecordPipelineStatus.canceled,
    };
