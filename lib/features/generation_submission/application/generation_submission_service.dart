import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';

import '../../../config/app_config.dart';
import '../../backend_api/data/backend_repositories.dart';
import '../../backend_api/domain/api_failure.dart';
import '../../backend_api/domain/feedback.dart';
import '../../backend_api/domain/generation_task.dart';
import '../../backend_api/domain/prompt_config.dart';
import '../../backend_api/domain/upload_session.dart';
import 'background_r2_upload_service.dart';
import '../data/generation_record_database.dart';
import '../data/generation_record_repository.dart';
import '../data/generation_image_processor.dart';
import '../data/generation_original_file_store.dart';
import '../data/generation_submission_adapters.dart';
import '../domain/generation_record.dart';
import '../domain/generation_submission_job.dart';

abstract interface class NotificationDeviceCoordinator {
  Future<String?> ensureRegisteredForGeneration();
}

class NoopNotificationDeviceCoordinator
    implements NotificationDeviceCoordinator {
  const NoopNotificationDeviceCoordinator();

  @override
  Future<String?> ensureRegisteredForGeneration() async {
    return null;
  }
}

class GenerationSubmissionService extends ChangeNotifier {
  GenerationSubmissionService({
    required UploadRepository uploadRepository,
    required GenerationTaskRepository generationTaskRepository,
    required FeedbackRepository feedbackRepository,
    required GenerationRecordRepository generationRecordRepository,
    required GenerationOriginalFileStore originalFileStore,
    required PhotoLibraryAssetStore photoLibraryAssetStore,
    required GenerationImageProcessor imageProcessor,
    BackgroundR2UploadService backgroundR2UploadService =
        const ForegroundFallbackR2UploadService(),
    NotificationDeviceCoordinator notificationDeviceCoordinator =
        const NoopNotificationDeviceCoordinator(),
  }) : _uploadRepository = uploadRepository,
       _generationTaskRepository = generationTaskRepository,
       _feedbackRepository = feedbackRepository,
       _generationRecordRepository = generationRecordRepository,
       _originalFileStore = originalFileStore,
       _photoLibraryAssetStore = photoLibraryAssetStore,
       _imageProcessor = imageProcessor,
       _backgroundR2UploadService = backgroundR2UploadService,
       _notificationDeviceCoordinator = notificationDeviceCoordinator;

  static const Duration _taskPollInterval = Duration(seconds: 3);

  final UploadRepository _uploadRepository;
  final GenerationTaskRepository _generationTaskRepository;
  final FeedbackRepository _feedbackRepository;
  final GenerationRecordRepository _generationRecordRepository;
  final GenerationOriginalFileStore _originalFileStore;
  final PhotoLibraryAssetStore _photoLibraryAssetStore;
  final GenerationImageProcessor _imageProcessor;
  final BackgroundR2UploadService _backgroundR2UploadService;
  final NotificationDeviceCoordinator _notificationDeviceCoordinator;
  final Map<String, Future<void>> _submissionOperations =
      <String, Future<void>>{};
  Timer? _batchPollingTimer;
  Future<void>? _batchPollingOperation;
  final Map<String, Future<void>> _pollingOperations = <String, Future<void>>{};
  final Map<String, Timer> _resultRetryTimers = <String, Timer>{};
  final Map<String, Future<String?>> _resultUrlOperations =
      <String, Future<String?>>{};
  final Map<String, Future<void>> _resultProcessingOperations =
      <String, Future<void>>{};
  final Map<String, _RuntimeGenerationRecordState> _runtimeState =
      <String, _RuntimeGenerationRecordState>{};
  Future<void>? _resumeActiveRecordsOperation;

  int _nextJobId = 0;

  Future<GenerationSubmissionState> stateForRecords(
    List<GenerationRecord> records,
  ) async {
    final List<GenerationSubmissionJob?> jobs = await Future.wait(
      records.map(_jobForRecord),
    );
    return GenerationSubmissionState(
      jobs: jobs.whereType<GenerationSubmissionJob>().toList(growable: false),
    );
  }

  Future<String?> queueCapturedFile(
    XFile file, {
    PromptSelectionSnapshot? promptSelection,
  }) async {
    final DateTime now = DateTime.now();
    final String recordId = _nextRecordId(now);
    final PromptSelectionSnapshot snapshot =
        promptSelection ?? PromptSelectionSnapshot.fallback;
    _debugLog('queue captured record=$recordId sourcePath=${file.path}');

    try {
      final StoredOriginalFile stored = await _originalFileStore
          .storeCameraOriginal(
            recordId: recordId,
            sourcePath: file.path,
            capturedAt: now,
          );
      await _generationRecordRepository.createCameraRecord(
        recordId: recordId,
        originalLocalPath: stored.path,
        createdAt: now,
        originalCapturedAt: now,
        originalFormat: stored.format,
        promptStyle: snapshot.promptStyle,
        captureMode: snapshot.captureMode,
        appInputContractId: snapshot.appInputContractId,
        userInputJson: jsonEncode(snapshot.userInput),
      );
      _runtimeState[recordId] = _RuntimeGenerationRecordState(
        promptSelection: snapshot,
      );
      _debugLog(
        'queue captured success record=$recordId storedPath=${stored.path}',
      );
      notifyListeners();
      return recordId;
    } on Object catch (error) {
      _debugLog('queue captured failure record=$recordId error=$error');
      await _generationRecordRepository.createLocalOriginalSaveFailedRecord(
        recordId: recordId,
        createdAt: now,
        errorCode: 'local_original_save_failed',
        errorMessage: error.toString(),
        promptStyle: snapshot.promptStyle,
        captureMode: snapshot.captureMode,
        appInputContractId: snapshot.appInputContractId,
        userInputJson: jsonEncode(snapshot.userInput),
      );
      _runtimeState[recordId] = _RuntimeGenerationRecordState(
        promptSelection: snapshot,
      );
      notifyListeners();
      return recordId;
    }
  }

  Future<String> queueGalleryFile(
    XFile file, {
    String? originalAssetId,
    PromptSelectionSnapshot? promptSelection,
  }) async {
    final DateTime now = DateTime.now();
    final String recordId = _nextRecordId(now);
    final PromptSelectionSnapshot snapshot =
        promptSelection ?? PromptSelectionSnapshot.fallback;
    _debugLog(
      'queue gallery record=$recordId path=${file.path} asset=${originalAssetId ?? 'none'}',
    );
    await _generationRecordRepository.createGalleryRecord(
      recordId: recordId,
      createdAt: now,
      originalAssetId: originalAssetId,
      promptStyle: snapshot.promptStyle,
      captureMode: snapshot.captureMode,
      appInputContractId: snapshot.appInputContractId,
      userInputJson: jsonEncode(snapshot.userInput),
    );
    _runtimeState[recordId] = _RuntimeGenerationRecordState(
      originalPath: file.path,
      promptSelection: snapshot,
    );
    notifyListeners();
    return recordId;
  }

  Future<void> submitCapturedFile(
    XFile file, {
    PromptSelectionSnapshot? promptSelection,
  }) async {
    final String? recordId = await queueCapturedFile(
      file,
      promptSelection: promptSelection,
    );
    if (recordId != null) {
      await confirmJob(recordId);
    }
  }

  Future<void> confirmJob(String recordId) async {
    final GenerationRecord? record = await _generationRecordRepository.findById(
      recordId,
    );
    if (record == null) {
      _debugLog('confirm skipped record=$recordId reason=missing-record');
      return;
    }
    if (record.pipelineStatus !=
        GenerationRecordPipelineStatus.awaitingConfirmation.name) {
      _debugLog(
        'confirm skipped record=$recordId reason=status-${record.pipelineStatus}',
      );
      return;
    }

    _debugLog(
      'confirm record=$recordId path=${await _sourcePathForRecord(record)}',
    );
    await _submitRecord(record);
  }

  Future<void> cancelJob(String recordId) async {
    final GenerationRecord? record = await _generationRecordRepository.findById(
      recordId,
    );
    if (record == null) {
      _debugLog('cancel skipped record=$recordId reason=missing-record');
      return;
    }
    if (record.pipelineStatus !=
        GenerationRecordPipelineStatus.awaitingConfirmation.name) {
      _debugLog(
        'cancel skipped record=$recordId reason=status-${record.pipelineStatus}',
      );
      return;
    }
    _debugLog('cancel record=$recordId');
    _stopTaskPolling(recordId);
    _cancelResultRetry(recordId);
    if (record.originalSourceType ==
            GenerationRecordOriginalSourceType.camera.name &&
        record.originalLocalPath != null) {
      await _originalFileStore.deleteOriginal(record.originalLocalPath!);
    }
    _runtimeState.remove(recordId);
    await _generationRecordRepository.deleteRecord(recordId);
    notifyListeners();
  }

  Future<String?> loadResultUrl(String recordId) async {
    final GenerationRecord? record = await _generationRecordRepository.findById(
      recordId,
    );
    final GenerationSubmissionStatus? status = record == null
        ? null
        : _submissionStatusForRecord(record);
    if (record == null ||
        status == null ||
        !_canLoadResultUrl(status) ||
        record.taskId == null) {
      _debugLog(
        'result url skipped record=$recordId reason=not-completed-or-missing-task',
      );
      return null;
    }

    try {
      return await _loadResultUrlForRecord(record);
    } on _ResultUrlNotReadyException {
      _debugLog(
        'result url deferred record=$recordId task=${record.taskId} reason=result-not-ready',
      );
      return null;
    }
  }

  Future<void> pollTaskNowForDebug(String recordId) async {
    final GenerationRecord? record = await _generationRecordRepository.findById(
      recordId,
    );
    final String? taskId = record?.taskId;
    if (taskId == null) {
      return;
    }
    await _pollTask(recordId: recordId, taskId: taskId);
  }

  Future<void> resumeActiveRecords() async {
    final Future<void>? running = _resumeActiveRecordsOperation;
    if (running != null) {
      _debugLog('resume active records skipped reason=in-flight');
      return running;
    }
    final Future<void> operation = _resumeActiveRecordsOnce();
    _resumeActiveRecordsOperation = operation;
    try {
      await operation;
    } finally {
      _resumeActiveRecordsOperation = null;
    }
  }

  Future<void> _resumeActiveRecordsOnce() async {
    final List<GenerationRecord> records = await _generationRecordRepository
        .listActiveRecords();
    _debugLog('resume active records count=${records.length}');
    var shouldPollActiveTasks = false;
    for (final GenerationRecord record in records) {
      final GenerationRecordPipelineStatus status =
          generationRecordPipelineStatusFromName(record.pipelineStatus);
      if ((status == GenerationRecordPipelineStatus.submitted ||
              status == GenerationRecordPipelineStatus.pollingTask) &&
          record.taskId != null &&
          record.taskId!.isNotEmpty) {
        shouldPollActiveTasks = true;
      }
      if (status == GenerationRecordPipelineStatus.uploadedWaitingTask ||
          status == GenerationRecordPipelineStatus.uploading ||
          status == GenerationRecordPipelineStatus.creatingTask) {
        shouldPollActiveTasks = true;
      }
      await _resumeRecord(record);
    }
    if (shouldPollActiveTasks) {
      await _pollActiveTasksBatch();
    }
    notifyListeners();
  }

  Future<void> retryJob(String recordId) async {
    final GenerationRecord? record = await _generationRecordRepository.findById(
      recordId,
    );
    if (record == null) {
      _debugLog('retry skipped record=$recordId reason=missing-record');
      return;
    }

    final GenerationRecordPipelineStatus status =
        generationRecordPipelineStatusFromName(record.pipelineStatus);
    if (status != GenerationRecordPipelineStatus.generationFailed &&
        status != GenerationRecordPipelineStatus.resultSaveFailed) {
      _debugLog(
        'retry skipped record=$recordId reason=status-${record.pipelineStatus}',
      );
      return;
    }

    _debugLog('retry start record=$recordId status=${record.pipelineStatus}');
    _stopTaskPolling(recordId);
    _cancelResultRetry(recordId);
    _runtimeState[recordId]?.clearSubmissionAttempt();

    if (status == GenerationRecordPipelineStatus.resultSaveFailed &&
        record.taskId != null) {
      await _generationRecordRepository.updatePipelineStatus(
        recordId: recordId,
        status: GenerationRecordPipelineStatus.completed,
        updatedAt: DateTime.now(),
        clearError: true,
      );
      await _processCompletedResult(recordId: recordId, taskId: record.taskId!);
      notifyListeners();
      return;
    }

    await _generationRecordRepository.resetForRetry(
      recordId: recordId,
      updatedAt: DateTime.now(),
    );
    final GenerationRecord? retryRecord = await _generationRecordRepository
        .findById(recordId);
    if (retryRecord == null) {
      _debugLog('retry aborted record=$recordId reason=missing-after-reset');
      notifyListeners();
      return;
    }
    await _submitRecord(retryRecord);
    notifyListeners();
  }

  Future<void> toggleResultFavorite(String recordId) async {
    final GenerationRecord? record = await _generationRecordRepository.findById(
      recordId,
    );
    if (record == null) {
      _debugLog('favorite skipped record=$recordId reason=missing-record');
      return;
    }
    final String? resultAssetId = record.resultAssetId;
    if (record.pipelineStatus !=
            GenerationRecordPipelineStatus.resultSaved.name ||
        record.resultAvailability !=
            GenerationRecordResultAvailability.savedToPhotoLibrary.name ||
        resultAssetId == null ||
        resultAssetId.isEmpty) {
      _debugLog(
        'favorite skipped record=$recordId reason=not-saved-result status=${record.pipelineStatus} asset=${resultAssetId ?? 'none'}',
      );
      return;
    }

    final bool nextFavorite = !record.resultIsFavorite;
    _debugLog(
      'favorite photo start record=$recordId asset=$resultAssetId favorite=$nextFavorite',
    );
    await _photoLibraryAssetStore.setFavorite(
      resultAssetId,
      isFavorite: nextFavorite,
    );
    final DateTime updatedAt = DateTime.now();
    await _generationRecordRepository.updateResultFavorite(
      recordId: recordId,
      updatedAt: updatedAt,
      isFavorite: nextFavorite,
      favoritedAt: nextFavorite ? updatedAt : null,
    );
    _debugLog(
      'favorite photo success record=$recordId asset=$resultAssetId favorite=$nextFavorite',
    );

    if (nextFavorite && record.resultFavoriteFeedbackSubmittedAt == null) {
      await _submitFavoriteFeedback(recordId: recordId, taskId: record.taskId);
    }
    notifyListeners();
  }

  Future<void> openPhotoLibrary(String recordId) async {
    final GenerationRecord? record = await _generationRecordRepository.findById(
      recordId,
    );
    if (record == null) {
      _debugLog(
        'open photo library skipped record=$recordId reason=missing-record',
      );
      return;
    }
    _debugLog(
      'open photo library start record=$recordId resultAsset=${record.resultAssetId ?? 'none'} originalAsset=${record.originalAssetId ?? 'none'}',
    );
    await _photoLibraryAssetStore.openPhotoLibrary();
    _debugLog('open photo library success record=$recordId');
  }

  Future<void> saveOriginalToPhotoLibrary(String recordId) async {
    final GenerationRecord? record = await _generationRecordRepository.findById(
      recordId,
    );
    if (record == null) {
      _debugLog('save original skipped record=$recordId reason=missing-record');
      return;
    }
    if (!_canSaveOriginalToPhotoLibrary(record)) {
      _debugLog(
        'save original skipped record=$recordId reason=not-camera-local source=${record.originalSourceType} availability=${record.originalAvailability}',
      );
      return;
    }

    final String? sourcePath = await _sourcePathForRecord(record);
    if (sourcePath == null || sourcePath.isEmpty) {
      _debugLog('save original skipped record=$recordId reason=missing-source');
      return;
    }

    try {
      _debugLog('save original start record=$recordId path=$sourcePath');
      final SavedPhotoLibraryImage savedImage = await _photoLibraryAssetStore
          .saveImageToLibrary(
            sourcePath,
            fileName: AppConfig.generationOriginalFileName(
              recordId,
              sourcePath,
            ),
          );
      _debugLog(
        'save original success record=$recordId asset=${savedImage.assetId}',
      );
    } on Object catch (error) {
      _debugLog('save original failure record=$recordId error=$error');
      rethrow;
    }
  }

  Future<void> submitNegativeFeedback(String recordId, {String? note}) async {
    final GenerationRecord? record = await _generationRecordRepository.findById(
      recordId,
    );
    if (record == null) {
      _debugLog(
        'negative feedback skipped record=$recordId reason=missing-record',
      );
      return;
    }
    final String? taskId = record.taskId;
    if (taskId == null || taskId.isEmpty) {
      _debugLog(
        'negative feedback skipped record=$recordId reason=missing-task',
      );
      return;
    }
    if (record.resultNegativeFeedbackSubmittedAt != null) {
      _debugLog(
        'negative feedback skipped record=$recordId reason=already-submitted',
      );
      return;
    }
    try {
      _debugLog('negative feedback start record=$recordId task=$taskId');
      await _feedbackRepository.submitFeedback(
        FeedbackInput(
          taskId: taskId,
          rating: FeedbackRating.negative,
          tags: const <String>['dislike_result'],
          note: _normalizedOptionalNote(note),
          metadata: const <String, Object?>{'entry': 'gallery_more_menu'},
        ),
      );
      final DateTime submittedAt = DateTime.now();
      await _generationRecordRepository.markNegativeFeedbackSubmitted(
        recordId: recordId,
        submittedAt: submittedAt,
      );
      _debugLog('negative feedback success record=$recordId task=$taskId');
    } on BackendApiFailure catch (error) {
      _debugLog(
        'negative feedback backend failure record=$recordId task=$taskId code=${error.code} status=${error.statusCode} message=${error.message}',
      );
      rethrow;
    } on Object catch (error) {
      _debugLog(
        'negative feedback local failure record=$recordId task=$taskId error=$error',
      );
      rethrow;
    }
  }

  String? _normalizedOptionalNote(String? note) {
    final String? trimmed = note?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<void> removeRecord(String recordId) async {
    final GenerationRecord? record = await _generationRecordRepository.findById(
      recordId,
    );
    if (record == null) {
      _debugLog('remove skipped record=$recordId reason=missing-record');
      return;
    }

    _debugLog(
      'remove start record=$recordId status=${record.pipelineStatus} resultAsset=${record.resultAssetId ?? 'none'}',
    );
    _stopTaskPolling(recordId);
    _cancelResultRetry(recordId);
    _submissionOperations.remove(recordId);
    _resultUrlOperations.remove(recordId);
    _resultProcessingOperations.remove(recordId);

    if (record.originalSourceType ==
            GenerationRecordOriginalSourceType.camera.name &&
        record.originalLocalPath != null) {
      await _originalFileStore.deleteOriginal(record.originalLocalPath!);
    }
    final String? resultLocalCachePath = record.resultLocalCachePath;
    if (resultLocalCachePath != null && resultLocalCachePath.isNotEmpty) {
      await _deleteTemporaryResultFile(
        recordId: recordId,
        path: resultLocalCachePath,
      );
    }
    final String? runtimeResultPath =
        _runtimeState[recordId]?.processedResultPath;
    if (runtimeResultPath != null &&
        runtimeResultPath.isNotEmpty &&
        runtimeResultPath != resultLocalCachePath &&
        record.resultAssetId == null) {
      await _deleteTemporaryResultFile(
        recordId: recordId,
        path: runtimeResultPath,
      );
    }
    _runtimeState.remove(recordId);
    await _generationRecordRepository.deleteRecord(recordId);
    _debugLog('remove success record=$recordId');
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelAllPolling();
    _cancelAllResultRetries();
    super.dispose();
  }

  String _nextRecordId(DateTime now) {
    return 'local-${now.microsecondsSinceEpoch}-${_nextJobId++}';
  }

  Future<void> _submitFavoriteFeedback({
    required String recordId,
    required String? taskId,
  }) async {
    if (taskId == null || taskId.isEmpty) {
      _debugLog(
        'favorite feedback skipped record=$recordId reason=missing-task',
      );
      return;
    }
    try {
      _debugLog('favorite feedback start record=$recordId task=$taskId');
      await _feedbackRepository.submitFeedback(
        FeedbackInput(
          taskId: taskId,
          rating: FeedbackRating.positive,
          tags: const <String>['ios_favorite'],
          metadata: const <String, Object?>{'entry': 'gallery_hero_toolbar'},
        ),
      );
      final DateTime submittedAt = DateTime.now();
      await _generationRecordRepository.updateResultFavorite(
        recordId: recordId,
        updatedAt: submittedAt,
        isFavorite: true,
        favoritedAt: submittedAt,
        feedbackSubmittedAt: submittedAt,
      );
      _debugLog('favorite feedback success record=$recordId task=$taskId');
    } on BackendApiFailure catch (error) {
      _debugLog(
        'favorite feedback backend failure record=$recordId task=$taskId code=${error.code} status=${error.statusCode} message=${error.message}',
      );
    } on Object catch (error) {
      _debugLog(
        'favorite feedback local failure record=$recordId task=$taskId error=$error',
      );
    }
  }

  bool _canSaveOriginalToPhotoLibrary(GenerationRecord record) {
    return record.originalSourceType ==
            GenerationRecordOriginalSourceType.camera.name &&
        record.originalAvailability ==
            GenerationRecordOriginalAvailability.available.name &&
        record.originalLocalPath != null &&
        record.originalLocalPath!.isNotEmpty;
  }

  Future<void> _submitRecord(GenerationRecord record) async {
    final String recordId = record.recordId;
    final Future<void>? running = _submissionOperations[recordId];
    if (running != null) {
      _debugLog('submit skipped record=$recordId reason=in-flight');
      return running;
    }
    final Future<void> operation = _submitRecordOnce(record);
    _submissionOperations[recordId] = operation;
    try {
      await operation;
    } finally {
      _submissionOperations.remove(recordId);
    }
  }

  Future<void> _submitRecordOnce(GenerationRecord record) async {
    final String recordId = record.recordId;
    String stage = 'queued';
    final String? sourcePath = await _sourcePathForRecord(record);
    if (sourcePath == null) {
      _debugLog('submit skipped record=$recordId reason=missing-source-path');
      await _failRecord(
        recordId: recordId,
        errorCode: 'original_unavailable',
        errorMessage: 'Original image is not available.',
      );
      return;
    }

    _debugLog('submit start record=$recordId path=$sourcePath');
    await _markPipelineStatus(
      recordId,
      GenerationRecordPipelineStatus.awaitingRetry,
      clearError: true,
    );

    try {
      stage = 'preparingUploadImage';
      await _markPipelineStatus(
        recordId,
        GenerationRecordPipelineStatus.preparingUploadImage,
        clearError: true,
      );
      _debugLog('prepare upload image start record=$recordId');
      final PreparedUploadImage uploadImage = await _imageProcessor
          .prepareUploadImage(jobId: recordId, sourcePath: sourcePath);
      _debugLog(
        'prepare upload image success record=$recordId path=${uploadImage.path} bytes=${uploadImage.bytes.length} exifKeys=${uploadImage.sourceExif.length}',
      );
      _runtimeFor(recordId).uploadImagePath = uploadImage.path;
      _runtimeFor(recordId).sourceExif = uploadImage.sourceExif;

      stage = 'readingFile';
      final Uint8List bytes = uploadImage.bytes;
      _debugLog(
        'read cleaned file success record=$recordId bytes=${bytes.length}',
      );

      stage = 'creatingUpload';
      await _markPipelineStatus(
        recordId,
        GenerationRecordPipelineStatus.creatingUpload,
      );
      final PromptSelectionSnapshot promptSelection = _promptSelectionForRecord(
        record,
      );
      _debugLog(
        'create upload generation request record=$recordId prompt=${promptSelection.promptStyle}/${promptSelection.captureMode} switches=${promptSelection.switches}',
      );
      final String? originDeviceId = await _notificationDeviceCoordinator
          .ensureRegisteredForGeneration();
      _debugLog('create upload start record=$recordId bytes=${bytes.length}');
      final UploadSession uploadSession = await _uploadRepository.createUpload(
        contentType: 'image/jpeg',
        bytes: bytes,
        generationRequest: CreateGenerationTaskInput(
          uploadSessionId: '',
          promptStyle: promptSelection.promptStyle,
          captureMode: promptSelection.captureMode,
          appInputContractId: promptSelection.appInputContractId,
          userInput: promptSelection.userInput,
          originDeviceId: originDeviceId,
        ),
      );
      _debugLog(
        'create upload success record=$recordId uploadSession=${uploadSession.uploadSessionId} source=${uploadSession.sourceImageObjectId}',
      );
      await _generationRecordRepository.updateUploadFields(
        recordId: recordId,
        updatedAt: DateTime.now(),
        uploadSessionId: uploadSession.uploadSessionId,
        sourceImageObjectId: uploadSession.sourceImageObjectId,
        uploadContentType: 'image/jpeg',
        uploadSizeBytes: bytes.length,
      );

      stage = 'uploading';
      await _markPipelineStatus(
        recordId,
        GenerationRecordPipelineStatus.uploading,
      );
      _debugLog(
        'upload bytes start record=$recordId uploadSession=${uploadSession.uploadSessionId}',
      );
      final BackgroundR2UploadResult uploadResult =
          await _backgroundR2UploadService.uploadFile(
            uploadSession: uploadSession,
            filePath: uploadImage.path,
            contentType: 'image/jpeg',
            displayName: 'TesserCam Upload',
          );
      _debugLog(
        'upload bytes terminal record=$recordId uploadSession=${uploadSession.uploadSessionId} downloaderTask=${uploadResult.downloaderTaskId} status=${uploadResult.status.name} http=${uploadResult.responseStatusCode ?? 'none'}',
      );
      if (uploadResult.status != TaskStatus.complete) {
        throw BackendApiFailure(
          code: 'upload_failed',
          message:
              uploadResult.responseBody ??
              uploadResult.exception?.toString() ??
              'Upload failed.',
          statusCode: uploadResult.responseStatusCode,
        );
      }
      _debugLog('upload bytes success record=$recordId');

      stage = 'uploadedWaitingTask';
      await _markPipelineStatus(
        recordId,
        GenerationRecordPipelineStatus.uploadedWaitingTask,
        clearError: true,
      );
      await _recoverUploadedTask(
        recordId: recordId,
        uploadSessionId: uploadSession.uploadSessionId,
        sourceImageObjectId: uploadSession.sourceImageObjectId,
      );
      final GenerationRecord? recoveredRecord =
          await _generationRecordRepository.findById(recordId);
      final String? recoveredTaskId = recoveredRecord?.taskId;
      if (recoveredTaskId == null || recoveredTaskId.isEmpty) {
        _ensureBatchPollingStarted();
        unawaited(_pollActiveTasksBatch());
        return;
      }
      _startTaskPolling(recordId: recordId, taskId: recoveredTaskId);
    } on BackendApiFailure catch (error) {
      _debugLog(
        'submit backend failure record=$recordId stage=$stage code=${error.code} status=${error.statusCode} requestId=${error.requestId ?? 'none'} message=${error.message} details=${error.details ?? 'none'}',
      );
      await _failRecord(
        recordId: recordId,
        errorCode: error.code,
        errorMessage: error.message,
      );
    } on Object catch (error) {
      _debugLog('submit local failure record=$recordId error=$error');
      await _failRecord(
        recordId: recordId,
        errorCode: 'local_error',
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> _resumeRecord(GenerationRecord record) async {
    final GenerationRecordPipelineStatus status =
        generationRecordPipelineStatusFromName(record.pipelineStatus);
    final String recordId = record.recordId;
    _debugLog(
      'resume record=$recordId status=${record.pipelineStatus} task=${record.taskId ?? 'none'}',
    );

    switch (status) {
      case GenerationRecordPipelineStatus.submitted:
      case GenerationRecordPipelineStatus.pollingTask:
        final String? taskId = record.taskId;
        if (taskId == null || taskId.isEmpty) {
          _debugLog('resume resubmit record=$recordId reason=missing-task');
          await _generationRecordRepository.resetForRetry(
            recordId: recordId,
            updatedAt: DateTime.now(),
          );
          final GenerationRecord? retryRecord =
              await _generationRecordRepository.findById(recordId);
          if (retryRecord != null) {
            await _submitRecord(retryRecord);
          }
          return;
        }
        await _resumeTaskPolling(recordId: recordId, taskId: taskId);
        return;
      case GenerationRecordPipelineStatus.uploadedWaitingTask:
      case GenerationRecordPipelineStatus.uploading:
      case GenerationRecordPipelineStatus.creatingTask:
        final String? taskId = record.taskId;
        if (taskId != null && taskId.isNotEmpty) {
          await _resumeTaskPolling(recordId: recordId, taskId: taskId);
          return;
        }
        final String? uploadSessionId = record.uploadSessionId;
        if (uploadSessionId == null || uploadSessionId.isEmpty) {
          _debugLog(
            'resume resubmit record=$recordId reason=uploaded-missing-upload-session',
          );
          await _generationRecordRepository.resetForRetry(
            recordId: recordId,
            updatedAt: DateTime.now(),
          );
          final GenerationRecord? retryRecord =
              await _generationRecordRepository.findById(recordId);
          if (retryRecord != null) {
            await _submitRecord(retryRecord);
          }
          return;
        }
        try {
          await _recoverUploadedTask(
            recordId: recordId,
            uploadSessionId: uploadSessionId,
            sourceImageObjectId: record.sourceImageObjectId,
          );
        } on BackendApiFailure catch (error) {
          _debugLog(
            'resume uploaded task backend failure record=$recordId code=${error.code} status=${error.statusCode} message=${error.message}',
          );
          await _failRecord(
            recordId: recordId,
            errorCode: error.code,
            errorMessage: error.message,
          );
        } on Object catch (error) {
          _debugLog(
            'resume uploaded task local failure record=$recordId error=$error',
          );
          await _failRecord(
            recordId: recordId,
            errorCode: 'task_recovery_failed',
            errorMessage: error.toString(),
          );
        }
        return;
      case GenerationRecordPipelineStatus.completed:
      case GenerationRecordPipelineStatus.processingResultImage:
      case GenerationRecordPipelineStatus.resultSaveFailed:
        final String? taskId = record.taskId;
        if (taskId == null || taskId.isEmpty) {
          _debugLog(
            'resume resubmit completed-like record=$recordId reason=missing-task',
          );
          await _generationRecordRepository.resetForRetry(
            recordId: recordId,
            updatedAt: DateTime.now(),
          );
          final GenerationRecord? retryRecord =
              await _generationRecordRepository.findById(recordId);
          if (retryRecord != null) {
            await _submitRecord(retryRecord);
          }
          return;
        }
        if (status != GenerationRecordPipelineStatus.completed) {
          await _generationRecordRepository.updatePipelineStatus(
            recordId: recordId,
            status: GenerationRecordPipelineStatus.completed,
            updatedAt: DateTime.now(),
            clearError: true,
          );
        }
        await _processCompletedResult(recordId: recordId, taskId: taskId);
        return;
      case GenerationRecordPipelineStatus.preparingUploadImage:
      case GenerationRecordPipelineStatus.creatingUpload:
        _debugLog(
          'resume resubmit record=$recordId reason=interrupted-${record.pipelineStatus}',
        );
        await _generationRecordRepository.resetForRetry(
          recordId: recordId,
          updatedAt: DateTime.now(),
        );
        final GenerationRecord? retryRecord = await _generationRecordRepository
            .findById(recordId);
        if (retryRecord != null) {
          await _submitRecord(retryRecord);
        }
      case GenerationRecordPipelineStatus.awaitingConfirmation:
      case GenerationRecordPipelineStatus.awaitingRetry:
      case GenerationRecordPipelineStatus.localOriginalSaveFailed:
      case GenerationRecordPipelineStatus.resultSaved:
      case GenerationRecordPipelineStatus.generationFailed:
      case GenerationRecordPipelineStatus.canceled:
        _debugLog(
          'resume skipped record=$recordId reason=${record.pipelineStatus}',
        );
    }
  }

  bool _canLoadResultUrl(GenerationSubmissionStatus status) {
    return status == GenerationSubmissionStatus.completed ||
        status == GenerationSubmissionStatus.processingResultImage ||
        status == GenerationSubmissionStatus.resultSaved ||
        status == GenerationSubmissionStatus.resultProcessingFailed;
  }

  Future<String?> _loadResultUrlForRecord(GenerationRecord record) async {
    final String recordId = record.recordId;
    final _RuntimeGenerationRecordState runtime = _runtimeFor(recordId);

    if (runtime.hasFreshResultUrl) {
      _debugLog('result url cache hit record=$recordId task=${record.taskId}');
      return runtime.resultUrl;
    }

    final Future<String?>? running = _resultUrlOperations[recordId];
    if (running != null) {
      _debugLog(
        'result url skipped record=$recordId task=${record.taskId} reason=in-flight',
      );
      return running;
    }
    final Future<String?> operation = _loadResultUrlForRecordOnce(record);
    _resultUrlOperations[recordId] = operation;
    try {
      return await operation;
    } finally {
      _resultUrlOperations.remove(recordId);
    }
  }

  Future<String?> _loadResultUrlForRecordOnce(GenerationRecord record) async {
    final String recordId = record.recordId;
    final _RuntimeGenerationRecordState runtime = _runtimeFor(recordId);

    try {
      _debugLog(
        'result url request start record=$recordId task=${record.taskId}',
      );
      final ResultUrl result = await _generationTaskRepository.createResultUrl(
        record.taskId!,
      );
      final DateTime expiresAt = DateTime.now().add(
        Duration(seconds: result.expiresInSeconds),
      );
      runtime.resultUrl = result.url;
      runtime.resultUrlExpiresAt = expiresAt;
      await _generationRecordRepository.updatePipelineStatus(
        recordId: recordId,
        status: generationRecordPipelineStatusFromName(record.pipelineStatus),
        updatedAt: DateTime.now(),
        clearError: true,
      );
      notifyListeners();
      _debugLog(
        'result url request success record=$recordId task=${record.taskId} expiresIn=${result.expiresInSeconds}s',
      );
      return result.url;
    } on BackendApiFailure catch (error) {
      _debugLog(
        'result url backend failure record=$recordId task=${record.taskId} code=${error.code} status=${error.statusCode} message=${error.message}',
      );
      if (_isResultNotReadyFailure(error)) {
        throw const _ResultUrlNotReadyException();
      }
      await _generationRecordRepository.updatePipelineStatus(
        recordId: recordId,
        status: generationRecordPipelineStatusFromName(record.pipelineStatus),
        updatedAt: DateTime.now(),
        errorCode: error.code,
        errorMessage: error.message,
      );
      return null;
    } on Object catch (error) {
      _debugLog(
        'result url local failure record=$recordId task=${record.taskId} error=$error',
      );
      await _generationRecordRepository.updatePipelineStatus(
        recordId: recordId,
        status: generationRecordPipelineStatusFromName(record.pipelineStatus),
        updatedAt: DateTime.now(),
        errorCode: 'result_url_error',
        errorMessage: error.toString(),
      );
      return null;
    }
  }

  void _startTaskPolling({required String recordId, required String taskId}) {
    _debugLog('batch polling observe record=$recordId task=$taskId');
    _ensureBatchPollingStarted();
    unawaited(_pollActiveTasksBatch());
  }

  Future<void> _resumeTaskPolling({
    required String recordId,
    required String taskId,
  }) async {
    _debugLog('batch polling resume observe record=$recordId task=$taskId');
    _ensureBatchPollingStarted();
  }

  Future<void> _recoverUploadedTask({
    required String recordId,
    required String uploadSessionId,
    required String? sourceImageObjectId,
  }) async {
    _debugLog(
      'recover uploaded task start record=$recordId uploadSession=$uploadSessionId source=${sourceImageObjectId ?? 'none'}',
    );
    final GenerationTask? matchedTask = await _generationTaskRepository
        .fetchTaskByUploadSession(uploadSessionId);
    if (matchedTask == null) {
      _debugLog(
        'recover uploaded task pending record=$recordId uploadSession=$uploadSessionId',
      );
      await _generationRecordRepository.updatePipelineStatus(
        recordId: recordId,
        status: GenerationRecordPipelineStatus.uploadedWaitingTask,
        updatedAt: DateTime.now(),
        clearError: true,
      );
      return;
    }
    if (sourceImageObjectId != null &&
        sourceImageObjectId.isNotEmpty &&
        matchedTask.sourceImageObjectId != sourceImageObjectId) {
      throw StateError(
        'Recovered task source mismatch for upload session $uploadSessionId.',
      );
    }
    _debugLog(
      'recover uploaded task success record=$recordId task=${matchedTask.id} status=${matchedTask.status.wireValue}',
    );
    await _generationRecordRepository.updateTaskFields(
      recordId: recordId,
      updatedAt: DateTime.now(),
      taskId: matchedTask.id,
      taskStatus: matchedTask.status.wireValue,
      resultImageObjectId: matchedTask.resultImageObjectId,
    );
    await _handlePolledTask(
      recordId: recordId,
      taskId: matchedTask.id,
      task: matchedTask,
    );
  }

  void _ensureBatchPollingStarted() {
    if (_batchPollingTimer != null) {
      return;
    }
    _debugLog('batch polling start');
    _batchPollingTimer = Timer.periodic(_taskPollInterval, (_) {
      unawaited(_pollActiveTasksBatch());
    });
  }

  Future<void> _pollActiveTasksBatch() async {
    final Future<void>? running = _batchPollingOperation;
    if (running != null) {
      _debugLog('batch poll skipped reason=in-flight');
      return running;
    }
    final Future<void> operation = _pollActiveTasksBatchOnce();
    _batchPollingOperation = operation;
    try {
      await operation;
    } finally {
      _batchPollingOperation = null;
    }
  }

  Future<void> _pollActiveTasksBatchOnce() async {
    final List<GenerationRecord> records = await _generationRecordRepository
        .listActiveRecords();
    final Map<String, GenerationRecord> recordsByTaskId =
        <String, GenerationRecord>{};
    var hasRecoverableUploadSession = false;

    for (final GenerationRecord record in records) {
      final GenerationRecordPipelineStatus status =
          generationRecordPipelineStatusFromName(record.pipelineStatus);
      if (status == GenerationRecordPipelineStatus.uploadedWaitingTask ||
          status == GenerationRecordPipelineStatus.uploading ||
          status == GenerationRecordPipelineStatus.creatingTask) {
        hasRecoverableUploadSession = true;
        final String? uploadSessionId = record.uploadSessionId;
        if (uploadSessionId != null && uploadSessionId.isNotEmpty) {
          try {
            await _recoverUploadedTask(
              recordId: record.recordId,
              uploadSessionId: uploadSessionId,
              sourceImageObjectId: record.sourceImageObjectId,
            );
          } on BackendApiFailure catch (error) {
            _debugLog(
              'recover uploaded task backend failure record=${record.recordId} code=${error.code} status=${error.statusCode} message=${error.message}',
            );
            await _failRecord(
              recordId: record.recordId,
              errorCode: error.code,
              errorMessage: error.message,
            );
            continue;
          } on Object catch (error) {
            _debugLog(
              'recover uploaded task local failure record=${record.recordId} error=$error',
            );
            await _failRecord(
              recordId: record.recordId,
              errorCode: 'task_recovery_failed',
              errorMessage: error.toString(),
            );
            continue;
          }
          final GenerationRecord? recoveredRecord =
              await _generationRecordRepository.findById(record.recordId);
          final String? recoveredTaskId = recoveredRecord?.taskId;
          if (recoveredRecord != null &&
              recoveredTaskId != null &&
              recoveredTaskId.isNotEmpty) {
            recordsByTaskId.putIfAbsent(recoveredTaskId, () => recoveredRecord);
          }
        }
        continue;
      }
      if (status != GenerationRecordPipelineStatus.submitted &&
          status != GenerationRecordPipelineStatus.pollingTask) {
        continue;
      }
      final String? taskId = record.taskId;
      if (taskId == null || taskId.isEmpty) {
        continue;
      }
      recordsByTaskId.putIfAbsent(taskId, () => record);
    }

    if (recordsByTaskId.isEmpty) {
      _debugLog(
        'batch poll skipped reason=${hasRecoverableUploadSession ? 'waiting-uploaded-task' : 'no-active-tasks'}',
      );
      if (!hasRecoverableUploadSession) {
        _stopBatchPolling();
      }
      return;
    }

    _debugLog('batch poll request start count=${recordsByTaskId.length}');
    try {
      for (final List<String> taskIds in _chunks(
        recordsByTaskId.keys.toList(growable: false),
        50,
      )) {
        final GenerationTasksBatchResult result =
            await _generationTaskRepository.fetchTasksBatch(taskIds);
        final Set<String> returnedTaskIds = <String>{};
        for (final GenerationTask task in result.tasks) {
          returnedTaskIds.add(task.id);
          final GenerationRecord? record = recordsByTaskId[task.id];
          if (record == null) {
            continue;
          }
          await _handlePolledTask(
            recordId: record.recordId,
            taskId: task.id,
            task: task,
          );
        }

        final Set<String> missingTaskIds = <String>{
          ...result.missingIds,
          ...taskIds.where(
            (String taskId) => !returnedTaskIds.contains(taskId),
          ),
        };
        for (final String missingTaskId in missingTaskIds) {
          final GenerationRecord? record = recordsByTaskId[missingTaskId];
          if (record == null) {
            continue;
          }
          _debugLog(
            'batch poll missing record=${record.recordId} task=$missingTaskId',
          );
          await _failRecord(
            recordId: record.recordId,
            errorCode: 'task_not_found',
            errorMessage: 'Generation task was not found.',
          );
        }
      }
    } on BackendApiFailure catch (error) {
      _debugLog(
        'batch poll backend failure code=${error.code} status=${error.statusCode} message=${error.message}',
      );
    } on Object catch (error) {
      _debugLog('batch poll local failure error=$error');
    }
  }

  Future<void> _pollTask({
    required String recordId,
    required String taskId,
  }) async {
    final Future<void>? running = _pollingOperations[recordId];
    if (running != null) {
      _debugLog('poll skipped record=$recordId task=$taskId reason=in-flight');
      return running;
    }
    final Future<void> operation = _pollTaskOnce(
      recordId: recordId,
      taskId: taskId,
    );
    _pollingOperations[recordId] = operation;
    try {
      await operation;
    } finally {
      _pollingOperations.remove(recordId);
    }
  }

  Future<void> _pollTaskOnce({
    required String recordId,
    required String taskId,
  }) async {
    final GenerationRecord? currentRecord = await _generationRecordRepository
        .findById(recordId);
    final GenerationSubmissionStatus? currentStatus = currentRecord == null
        ? null
        : _submissionStatusForRecord(currentRecord);
    if (currentRecord == null ||
        currentStatus == null ||
        _isTerminalStatus(currentStatus)) {
      final String reason = currentRecord == null
          ? 'missing-record'
          : 'terminal-${currentStatus?.name ?? 'unknown'}';
      _debugLog('poll skipped record=$recordId task=$taskId reason=$reason');
      return;
    }

    try {
      _debugLog('poll request start record=$recordId task=$taskId');
      final GenerationTask task = await _generationTaskRepository.fetchTask(
        taskId,
      );
      await _handlePolledTask(recordId: recordId, taskId: taskId, task: task);
    } on BackendApiFailure catch (error) {
      _debugLog(
        'poll backend failure record=$recordId task=$taskId code=${error.code} status=${error.statusCode} message=${error.message}',
      );
      await _failRecord(
        recordId: recordId,
        errorCode: error.code,
        errorMessage: error.message,
      );
    } on Object catch (error) {
      _debugLog(
        'poll local failure record=$recordId task=$taskId error=$error',
      );
      await _failRecord(
        recordId: recordId,
        errorCode: 'task_poll_error',
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> _handlePolledTask({
    required String recordId,
    required String taskId,
    required GenerationTask task,
  }) async {
    _debugLog(
      'poll response record=$recordId task=$taskId status=${task.status.wireValue} result=${task.resultImageObjectId ?? 'none'} errorCode=${task.lastErrorCode ?? 'none'} errorMessage=${task.lastErrorMessage ?? 'none'}',
    );
    switch (task.status) {
      case GenerationTaskStatus.pending:
      case GenerationTaskStatus.processing:
      case GenerationTaskStatus.modelRunning:
        await _generationRecordRepository.updatePipelineStatus(
          recordId: recordId,
          status: GenerationRecordPipelineStatus.pollingTask,
          updatedAt: DateTime.now(),
          clearError: true,
        );
        await _generationRecordRepository.updateTaskFields(
          recordId: recordId,
          updatedAt: DateTime.now(),
          taskStatus: task.status.wireValue,
          resultImageObjectId: task.resultImageObjectId,
        );
      case GenerationTaskStatus.completed:
        _debugLog('poll completed record=$recordId task=$taskId');
        await _generationRecordRepository.updatePipelineStatus(
          recordId: recordId,
          status: GenerationRecordPipelineStatus.completed,
          updatedAt: DateTime.now(),
          clearError: true,
        );
        await _generationRecordRepository.updateTaskFields(
          recordId: recordId,
          updatedAt: DateTime.now(),
          taskStatus: task.status.wireValue,
          resultImageObjectId: task.resultImageObjectId,
        );
        await _processCompletedResult(recordId: recordId, taskId: taskId);
      case GenerationTaskStatus.failed:
      case GenerationTaskStatus.canceled:
        _debugLog(
          'poll terminal failure record=$recordId task=$taskId status=${task.status.wireValue} code=${task.lastErrorCode ?? task.status.wireValue} message=${task.lastErrorMessage ?? 'none'}',
        );
        await _generationRecordRepository.updateTaskFields(
          recordId: recordId,
          updatedAt: DateTime.now(),
          taskStatus: task.status.wireValue,
          resultImageObjectId: task.resultImageObjectId,
        );
        await _generationRecordRepository.updatePipelineStatus(
          recordId: recordId,
          status: GenerationRecordPipelineStatus.generationFailed,
          updatedAt: DateTime.now(),
          errorCode: task.lastErrorCode ?? task.status.wireValue,
          errorMessage:
              task.lastErrorMessage ??
              'Generation task ${task.status.wireValue}.',
        );
      case GenerationTaskStatus.unknown:
        _debugLog('poll unknown status record=$recordId task=$taskId');
        await _failRecord(
          recordId: recordId,
          errorCode: 'unknown_task_status',
          errorMessage: 'Generation task returned an unknown status.',
        );
    }
  }

  Future<void> _markPipelineStatus(
    String recordId,
    GenerationRecordPipelineStatus status, {
    bool clearError = false,
  }) {
    return _generationRecordRepository.updatePipelineStatus(
      recordId: recordId,
      status: status,
      updatedAt: DateTime.now(),
      clearError: clearError,
    );
  }

  Future<void> _processCompletedResult({
    required String recordId,
    required String taskId,
  }) async {
    final Future<void>? running = _resultProcessingOperations[recordId];
    if (running != null) {
      _debugLog(
        'process result skipped record=$recordId task=$taskId reason=in-flight',
      );
      return running;
    }
    final Future<void> operation = _processCompletedResultOnce(
      recordId: recordId,
      taskId: taskId,
    );
    _resultProcessingOperations[recordId] = operation;
    try {
      await operation;
    } finally {
      _resultProcessingOperations.remove(recordId);
    }
  }

  Future<void> _processCompletedResultOnce({
    required String recordId,
    required String taskId,
  }) async {
    final GenerationRecord? record = await _generationRecordRepository.findById(
      recordId,
    );
    if (record == null) {
      _debugLog(
        'process result skipped record=$recordId reason=missing-record',
      );
      return;
    }
    if (record.pipelineStatus ==
            GenerationRecordPipelineStatus.resultSaved.name &&
        record.resultAssetId != null &&
        record.resultAssetId!.isNotEmpty) {
      _debugLog(
        'process result skipped record=$recordId reason=result-already-saved',
      );
      return;
    }
    if (record.pipelineStatus !=
        GenerationRecordPipelineStatus.completed.name) {
      _debugLog(
        'process result skipped record=$recordId reason=status-${record.pipelineStatus}',
      );
      return;
    }

    try {
      _debugLog('process result pipeline start record=$recordId task=$taskId');
      await _markPipelineStatus(
        recordId,
        GenerationRecordPipelineStatus.processingResultImage,
        clearError: true,
      );
      final String? resultUrl = await _loadResultUrlForRecord(record);
      if (resultUrl == null) {
        throw StateError('Result URL was not available.');
      }
      final Map<String, Object> sourceExif =
          _runtimeState[recordId]?.sourceExif ?? const <String, Object>{};
      final ProcessedResultImage result = await _imageProcessor
          .processResultImage(
            jobId: recordId,
            resultUrl: resultUrl,
            sourceExif: sourceExif,
          );
      _runtimeFor(recordId).processedResultPath = result.path;
      _debugLog(
        'save processed result start record=$recordId path=${result.path}',
      );
      final SavedPhotoLibraryImage savedImage = await _photoLibraryAssetStore
          .saveImage(
            result.path,
            album: AppConfig.generationPhotoAlbumName,
            fileName: AppConfig.generationResultFileName(recordId),
          );
      final DateTime savedAt = DateTime.now();
      _debugLog(
        'save processed result success record=$recordId bytes=${result.bytes.length} asset=${savedImage.assetId}',
      );
      final String? savedResultPath = await _photoLibraryAssetStore
          .resolveImagePath(savedImage.assetId);
      if (savedResultPath != null && savedResultPath.isNotEmpty) {
        _runtimeFor(recordId).processedResultPath = savedResultPath;
        _debugLog(
          'resolve saved result success record=$recordId asset=${savedImage.assetId} path=$savedResultPath',
        );
      } else {
        _debugLog(
          'resolve saved result unavailable record=$recordId asset=${savedImage.assetId}',
        );
      }
      await _generationRecordRepository.markResultSaved(
        recordId: recordId,
        updatedAt: savedAt,
        resultAssetId: savedImage.assetId,
        resultSavedAt: savedAt,
        resultSizeBytes: result.bytes.length,
      );
      _cancelResultRetry(recordId);
      await _deleteTemporaryResultFile(recordId: recordId, path: result.path);
    } on _ResultUrlNotReadyException {
      _debugLog(
        'process result deferred record=$recordId task=$taskId reason=result-not-ready',
      );
      await _generationRecordRepository.updatePipelineStatus(
        recordId: recordId,
        status: GenerationRecordPipelineStatus.completed,
        updatedAt: DateTime.now(),
        clearError: true,
      );
      _scheduleResultProcessingRetry(recordId: recordId, taskId: taskId);
    } on Object catch (error) {
      _debugLog(
        'process result pipeline failure record=$recordId error=$error',
      );
      final GenerationRecord? failedRecord = await _generationRecordRepository
          .findById(recordId);
      await _generationRecordRepository.updatePipelineStatus(
        recordId: recordId,
        status: GenerationRecordPipelineStatus.resultSaveFailed,
        updatedAt: DateTime.now(),
        errorCode: 'result_processing_failed',
        errorMessage: error.toString(),
      );
      final String? temporaryResultPath =
          _runtimeState[recordId]?.processedResultPath;
      if (temporaryResultPath != null &&
          failedRecord?.resultLocalCachePath != temporaryResultPath) {
        await _generationRecordRepository.updateResultFields(
          recordId: recordId,
          updatedAt: DateTime.now(),
          resultAvailability: GenerationRecordResultAvailability.localCache,
          resultLocalCachePath: temporaryResultPath,
        );
      }
    }
  }

  Future<void> _deleteTemporaryResultFile({
    required String recordId,
    required String path,
  }) async {
    try {
      final File file = File(path);
      if (await file.exists()) {
        await file.delete();
        _debugLog('delete temp result success record=$recordId path=$path');
      }
      if (_runtimeState[recordId]?.processedResultPath == path) {
        _runtimeState[recordId]?.processedResultPath = null;
      }
    } on Object catch (error) {
      _debugLog(
        'delete temp result failure record=$recordId path=$path error=$error',
      );
    }
  }

  Future<void> _failRecord({
    required String recordId,
    required String errorCode,
    required String errorMessage,
  }) {
    _debugLog(
      'mark failed record=$recordId code=$errorCode message=$errorMessage',
    );
    return _generationRecordRepository.updatePipelineStatus(
      recordId: recordId,
      status: GenerationRecordPipelineStatus.generationFailed,
      updatedAt: DateTime.now(),
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  void _stopTaskPolling(String jobId) {
    _debugLog('batch polling forget job=$jobId');
  }

  void _cancelAllPolling() {
    if (_batchPollingTimer != null) {
      _debugLog('dispose cancel batch polling');
    }
    _batchPollingTimer?.cancel();
    _batchPollingTimer = null;
    _batchPollingOperation = null;
  }

  void _stopBatchPolling() {
    final Timer? timer = _batchPollingTimer;
    if (timer == null) {
      return;
    }
    timer.cancel();
    _batchPollingTimer = null;
    _debugLog('batch polling stop');
  }

  void _scheduleResultProcessingRetry({
    required String recordId,
    required String taskId,
  }) {
    if (_resultRetryTimers.containsKey(recordId)) {
      _debugLog('result retry already scheduled record=$recordId task=$taskId');
      return;
    }
    _debugLog('result retry scheduled record=$recordId task=$taskId');
    _resultRetryTimers[recordId] = Timer(_taskPollInterval, () {
      _resultRetryTimers.remove(recordId);
      unawaited(
        _retryProcessCompletedResult(recordId: recordId, taskId: taskId),
      );
    });
  }

  Future<void> _retryProcessCompletedResult({
    required String recordId,
    required String taskId,
  }) async {
    final GenerationRecord? record = await _generationRecordRepository.findById(
      recordId,
    );
    if (record == null ||
        record.taskId != taskId ||
        record.pipelineStatus !=
            GenerationRecordPipelineStatus.completed.name) {
      _debugLog(
        'result retry skipped record=$recordId task=$taskId reason=status-${record?.pipelineStatus ?? 'missing'}',
      );
      return;
    }
    await _processCompletedResult(recordId: recordId, taskId: taskId);
    notifyListeners();
  }

  void _cancelResultRetry(String recordId) {
    final Timer? timer = _resultRetryTimers.remove(recordId);
    timer?.cancel();
  }

  void _cancelAllResultRetries() {
    if (_resultRetryTimers.isNotEmpty) {
      _debugLog(
        'dispose cancel result retries count=${_resultRetryTimers.length}',
      );
    }
    for (final Timer timer in _resultRetryTimers.values) {
      timer.cancel();
    }
    _resultRetryTimers.clear();
  }

  Future<GenerationSubmissionJob?> _jobForRecord(
    GenerationRecord record,
  ) async {
    final GenerationSubmissionStatus? status = _submissionStatusForRecord(
      record,
    );
    if (status == null) {
      return null;
    }
    final String? imagePath = await _sourcePathForRecord(record);
    final String? processedResultPath = await _resultPathForRecord(record);
    final GenerationRecordResultAvailability resultAvailability =
        _effectiveResultAvailabilityForRecord(record, processedResultPath);
    if (imagePath == null) {
      return GenerationSubmissionJob(
        id: record.recordId,
        imagePath: '',
        status: status,
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
        taskId: record.taskId,
        taskStatus: _taskStatusFromWire(record.taskStatus),
        resultImageObjectId: record.resultImageObjectId,
        errorCode: record.errorCode,
        errorMessage: record.errorMessage,
        promptSelection: _promptSelectionForRecord(record),
        processedResultPath: processedResultPath,
        resultAvailability: resultAvailability,
        resultAssetId: record.resultAssetId,
        resultNotificationSeenAt: record.resultNotificationSeenAt,
        canSaveOriginalToPhotoLibrary: _canSaveOriginalToPhotoLibrary(record),
        isResultFavorite: record.resultIsFavorite,
        resultFavoriteFeedbackSubmittedAt:
            record.resultFavoriteFeedbackSubmittedAt,
        resultNegativeFeedbackSubmittedAt:
            record.resultNegativeFeedbackSubmittedAt,
        resultSaveErrorCode:
            record.pipelineStatus ==
                GenerationRecordPipelineStatus.resultSaveFailed.name
            ? record.errorCode
            : null,
        resultSaveErrorMessage:
            record.pipelineStatus ==
                GenerationRecordPipelineStatus.resultSaveFailed.name
            ? record.errorMessage
            : null,
      );
    }
    final _RuntimeGenerationRecordState? runtime =
        _runtimeState[record.recordId];
    return GenerationSubmissionJob(
      id: record.recordId,
      imagePath: imagePath,
      status: status,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      uploadSessionId: record.uploadSessionId,
      promptSelection: _promptSelectionForRecord(record),
      taskId: record.taskId,
      taskStatus: _taskStatusFromWire(record.taskStatus),
      resultImageObjectId: record.resultImageObjectId,
      resultUrl: runtime?.resultUrl,
      resultUrlExpiresAt: runtime?.resultUrlExpiresAt,
      uploadImagePath: runtime?.uploadImagePath,
      uploadImageSizeBytes: record.uploadSizeBytes,
      sourceExif: runtime?.sourceExif,
      processedResultPath: processedResultPath,
      resultAvailability: resultAvailability,
      resultAssetId: record.resultAssetId,
      resultNotificationSeenAt: record.resultNotificationSeenAt,
      canSaveOriginalToPhotoLibrary: _canSaveOriginalToPhotoLibrary(record),
      isResultFavorite: record.resultIsFavorite,
      resultFavoriteFeedbackSubmittedAt:
          record.resultFavoriteFeedbackSubmittedAt,
      resultNegativeFeedbackSubmittedAt:
          record.resultNegativeFeedbackSubmittedAt,
      resultSaveErrorCode:
          status == GenerationSubmissionStatus.resultProcessingFailed
          ? record.errorCode
          : null,
      resultSaveErrorMessage:
          status == GenerationSubmissionStatus.resultProcessingFailed
          ? record.errorMessage
          : null,
      errorCode: record.errorCode,
      errorMessage: record.errorMessage,
    );
  }

  Future<String?> _sourcePathForRecord(GenerationRecord record) async {
    final String? originalLocalPath = record.originalLocalPath;
    if (originalLocalPath != null) {
      if (!await _originalFileStore.originalExists(originalLocalPath)) {
        _debugLog(
          'source path missing record=${record.recordId} path=$originalLocalPath',
        );
        return null;
      }
      return _originalFileStore.resolveOriginalPath(originalLocalPath);
    }
    final String? originalAssetId = record.originalAssetId;
    if (originalAssetId != null) {
      try {
        final String? resolvedPath = await _photoLibraryAssetStore
            .resolveImagePath(originalAssetId);
        if (resolvedPath != null && resolvedPath.isNotEmpty) {
          _runtimeFor(record.recordId).originalPath = resolvedPath;
          return resolvedPath;
        }
        _debugLog(
          'source asset unresolved record=${record.recordId} asset=$originalAssetId',
        );
      } on Object catch (error) {
        _debugLog(
          'source asset resolve failure record=${record.recordId} asset=$originalAssetId error=$error',
        );
      }
    }
    return _runtimeState[record.recordId]?.originalPath;
  }

  Future<String?> _resultPathForRecord(GenerationRecord record) async {
    final String? runtimeResultPath =
        _runtimeState[record.recordId]?.processedResultPath;
    if (runtimeResultPath != null && await File(runtimeResultPath).exists()) {
      return runtimeResultPath;
    }
    final String? resultAssetId = record.resultAssetId;
    if (resultAssetId != null &&
        (record.resultAvailability ==
                GenerationRecordResultAvailability.savedToPhotoLibrary.name ||
            record.resultAvailability ==
                GenerationRecordResultAvailability.missing.name)) {
      try {
        final String? resolvedPath = await _photoLibraryAssetStore
            .resolveImagePath(resultAssetId);
        if (resolvedPath != null && resolvedPath.isNotEmpty) {
          _runtimeFor(record.recordId).processedResultPath = resolvedPath;
          if (record.resultAvailability ==
              GenerationRecordResultAvailability.missing.name) {
            await _generationRecordRepository.updateResultFields(
              recordId: record.recordId,
              updatedAt: DateTime.now(),
              resultAvailability:
                  GenerationRecordResultAvailability.savedToPhotoLibrary,
            );
          }
          return resolvedPath;
        }
        _debugLog(
          'result asset unresolved record=${record.recordId} asset=$resultAssetId',
        );
        await _markPhotoLibraryResultMissing(record);
      } on Object catch (error) {
        _debugLog(
          'result asset resolve failure record=${record.recordId} asset=$resultAssetId error=$error',
        );
      }
    }
    final String? resultLocalCachePath = record.resultLocalCachePath;
    if (resultLocalCachePath == null) {
      return null;
    }
    if (!await File(resultLocalCachePath).exists()) {
      _debugLog(
        'result path missing record=${record.recordId} path=$resultLocalCachePath',
      );
      return null;
    }
    return resultLocalCachePath;
  }

  GenerationRecordResultAvailability _effectiveResultAvailabilityForRecord(
    GenerationRecord record,
    String? processedResultPath,
  ) {
    final GenerationRecordResultAvailability storedAvailability =
        generationRecordResultAvailabilityFromName(record.resultAvailability);
    final String? resultAssetId = record.resultAssetId;
    final bool hasResultAsset =
        resultAssetId != null && resultAssetId.isNotEmpty;
    if (!hasResultAsset) {
      return storedAvailability;
    }
    if (storedAvailability == GenerationRecordResultAvailability.missing &&
        processedResultPath != null &&
        processedResultPath.isNotEmpty) {
      return GenerationRecordResultAvailability.savedToPhotoLibrary;
    }
    if ((storedAvailability ==
                GenerationRecordResultAvailability.savedToPhotoLibrary ||
            storedAvailability == GenerationRecordResultAvailability.missing) &&
        (processedResultPath == null || processedResultPath.isEmpty)) {
      return GenerationRecordResultAvailability.missing;
    }
    return storedAvailability;
  }

  Future<void> _markPhotoLibraryResultMissing(GenerationRecord record) async {
    if (record.resultAvailability ==
        GenerationRecordResultAvailability.missing.name) {
      return;
    }
    await _generationRecordRepository.updateResultFields(
      recordId: record.recordId,
      updatedAt: DateTime.now(),
      resultAvailability: GenerationRecordResultAvailability.missing,
    );
  }

  PromptSelectionSnapshot _promptSelectionForRecord(GenerationRecord record) {
    final _RuntimeGenerationRecordState? runtime =
        _runtimeState[record.recordId];
    if (runtime?.promptSelection != null) {
      return runtime!.promptSelection!;
    }
    return PromptSelectionSnapshot(
      promptStyle: record.promptStyle ?? defaultPromptStyle,
      captureMode: record.captureMode ?? defaultCaptureMode,
      switches: _switchesFromUserInputJson(record.userInputJson),
      appInputContractId: record.appInputContractId,
    );
  }

  Map<String, bool> _switchesFromUserInputJson(String? userInputJson) {
    if (userInputJson == null) {
      return PromptSelectionSnapshot.fallback.switches;
    }
    try {
      final Object? decoded = jsonDecode(userInputJson);
      if (decoded is Map<String, Object?>) {
        final Object? rawSwitches = decoded['switches'];
        if (rawSwitches is Map) {
          return <String, bool>{
            for (final MapEntry<Object?, Object?> entry in rawSwitches.entries)
              if (entry.key is String && entry.value is bool)
                entry.key! as String: entry.value! as bool,
          };
        }
      }
    } on Object {
      return PromptSelectionSnapshot.fallback.switches;
    }
    return PromptSelectionSnapshot.fallback.switches;
  }

  GenerationSubmissionStatus? _submissionStatusForRecord(
    GenerationRecord record,
  ) {
    final GenerationRecordPipelineStatus status =
        generationRecordPipelineStatusFromName(record.pipelineStatus);
    return switch (status) {
      GenerationRecordPipelineStatus.awaitingConfirmation =>
        GenerationSubmissionStatus.awaitingConfirmation,
      GenerationRecordPipelineStatus.awaitingRetry =>
        GenerationSubmissionStatus.queued,
      GenerationRecordPipelineStatus.localOriginalSaveFailed =>
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
      GenerationRecordPipelineStatus.canceled =>
        GenerationSubmissionStatus.failed,
    };
  }

  GenerationTaskStatus? _taskStatusFromWire(String? value) {
    return value == null ? null : GenerationTaskStatus.fromWire(value);
  }

  bool _isTerminalStatus(GenerationSubmissionStatus status) {
    return status == GenerationSubmissionStatus.resultSaved ||
        status == GenerationSubmissionStatus.resultProcessingFailed ||
        status == GenerationSubmissionStatus.failed;
  }

  bool _isResultNotReadyFailure(BackendApiFailure error) {
    return error.code == 'result_not_ready';
  }

  _RuntimeGenerationRecordState _runtimeFor(String recordId) {
    return _runtimeState.putIfAbsent(
      recordId,
      _RuntimeGenerationRecordState.new,
    );
  }

  void _debugLog(String message) {
    debugPrint('[GenerationSubmissionService] $message');
  }
}

class _ResultUrlNotReadyException implements Exception {
  const _ResultUrlNotReadyException();
}

Iterable<List<T>> _chunks<T>(List<T> items, int size) sync* {
  for (var index = 0; index < items.length; index += size) {
    final int end = index + size > items.length ? items.length : index + size;
    yield items.sublist(index, end);
  }
}

class _RuntimeGenerationRecordState {
  _RuntimeGenerationRecordState({
    this.originalPath,
    this.promptSelection,
    this.resultUrl,
    this.resultUrlExpiresAt,
    this.uploadImagePath,
    this.sourceExif,
    this.processedResultPath,
  });

  String? originalPath;
  PromptSelectionSnapshot? promptSelection;
  String? resultUrl;
  DateTime? resultUrlExpiresAt;
  String? uploadImagePath;
  Map<String, Object>? sourceExif;
  String? processedResultPath;

  void clearSubmissionAttempt() {
    resultUrl = null;
    resultUrlExpiresAt = null;
    uploadImagePath = null;
    sourceExif = null;
    processedResultPath = null;
  }

  bool get hasFreshResultUrl {
    final String? url = resultUrl;
    final DateTime? expiresAt = resultUrlExpiresAt;
    return url != null &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now());
  }
}
