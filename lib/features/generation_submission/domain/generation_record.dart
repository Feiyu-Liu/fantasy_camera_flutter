enum GenerationRecordPipelineStatus {
  awaitingConfirmation,
  awaitingRetry,
  localOriginalSaveFailed,
  preparingUploadImage,
  creatingUpload,
  uploading,
  completingUpload,
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
      GenerationRecordPipelineStatus.completingUpload,
      GenerationRecordPipelineStatus.creatingTask,
      GenerationRecordPipelineStatus.submitted,
      GenerationRecordPipelineStatus.pollingTask,
      GenerationRecordPipelineStatus.completed,
      GenerationRecordPipelineStatus.processingResultImage,
      GenerationRecordPipelineStatus.resultSaveFailed,
    };

const Set<GenerationRecordPipelineStatus>
clearableCameraOriginalPipelineStatuses = <GenerationRecordPipelineStatus>{
  GenerationRecordPipelineStatus.resultSaved,
  GenerationRecordPipelineStatus.canceled,
};
