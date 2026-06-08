import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';

import '../../../config/app_config.dart';
import '../../backend_api/data/backend_repositories.dart';
import '../../backend_api/domain/api_failure.dart';
import '../../backend_api/domain/feedback.dart';
import '../../backend_api/domain/generation_task.dart';
import '../../backend_api/domain/prompt_config.dart';
import '../../backend_api/domain/upload_session.dart';
import '../data/generation_record_database.dart';
import '../data/generation_record_repository.dart';
import '../data/generation_image_processor.dart';
import '../data/generation_original_file_store.dart';
import '../data/generation_submission_adapters.dart';
import '../domain/generation_record.dart';
import '../domain/generation_submission_job.dart';

class GenerationSubmissionService extends ChangeNotifier {
  GenerationSubmissionService({
    required UploadRepository uploadRepository,
    required GenerationTaskRepository generationTaskRepository,
    required FeedbackRepository feedbackRepository,
    required GenerationRecordRepository generationRecordRepository,
    required GenerationOriginalFileStore originalFileStore,
    required PhotoLibraryAssetStore photoLibraryAssetStore,
    required GenerationImageProcessor imageProcessor,
  }) : _uploadRepository = uploadRepository,
       _generationTaskRepository = generationTaskRepository,
       _feedbackRepository = feedbackRepository,
       _generationRecordRepository = generationRecordRepository,
       _originalFileStore = originalFileStore,
       _photoLibraryAssetStore = photoLibraryAssetStore,
       _imageProcessor = imageProcessor;

  static const Duration _taskPollInterval = Duration(seconds: 3);

  final UploadRepository _uploadRepository;
  final GenerationTaskRepository _generationTaskRepository;
  final FeedbackRepository _feedbackRepository;
  final GenerationRecordRepository _generationRecordRepository;
  final GenerationOriginalFileStore _originalFileStore;
  final PhotoLibraryAssetStore _photoLibraryAssetStore;
  final GenerationImageProcessor _imageProcessor;
  final Map<String, Timer> _pollingTimers = <String, Timer>{};
  final Map<String, _RuntimeGenerationRecordState> _runtimeState =
      <String, _RuntimeGenerationRecordState>{};

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

  Future<void> submitCapturedFile(XFile file) async {
    final String? recordId = await queueCapturedFile(file);
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

    return _loadResultUrlForRecord(record);
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

  @override
  void dispose() {
    _cancelAllPolling();
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

  Future<void> _submitRecord(GenerationRecord record) async {
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
      _debugLog('create upload start record=$recordId bytes=${bytes.length}');
      final UploadSession uploadSession = await _uploadRepository.createUpload(
        contentType: 'image/jpeg',
        bytes: bytes,
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
      await _uploadRepository.uploadBytes(
        uploadSession: uploadSession,
        bytes: bytes,
      );
      _debugLog('upload bytes success record=$recordId');

      stage = 'completingUpload';
      await _markPipelineStatus(
        recordId,
        GenerationRecordPipelineStatus.completingUpload,
      );
      _debugLog(
        'complete upload start record=$recordId uploadSession=${uploadSession.uploadSessionId}',
      );
      await _uploadRepository.completeUpload(uploadSession.uploadSessionId);
      _debugLog('complete upload success record=$recordId');

      stage = 'creatingTask';
      await _markPipelineStatus(
        recordId,
        GenerationRecordPipelineStatus.creatingTask,
      );
      final PromptSelectionSnapshot promptSelection = _promptSelectionForRecord(
        record,
      );
      _debugLog(
        'create task start record=$recordId prompt=${promptSelection.promptStyle}/${promptSelection.captureMode} switches=${promptSelection.switches}',
      );
      final CreatedGenerationTask createdTask = await _generationTaskRepository
          .createTask(
            CreateGenerationTaskInput(
              uploadSessionId: uploadSession.uploadSessionId,
              promptStyle: promptSelection.promptStyle,
              captureMode: promptSelection.captureMode,
              appInputContractId: promptSelection.appInputContractId,
              userInput: promptSelection.userInput,
            ),
          );
      _debugLog(
        'create task success record=$recordId task=${createdTask.taskId} status=${createdTask.status.wireValue} credits=${createdTask.costCredits}',
      );

      await _generationRecordRepository.updatePipelineStatus(
        recordId: recordId,
        status: GenerationRecordPipelineStatus.submitted,
        updatedAt: DateTime.now(),
        clearError: true,
      );
      await _generationRecordRepository.updateTaskFields(
        recordId: recordId,
        updatedAt: DateTime.now(),
        taskId: createdTask.taskId,
        taskStatus: createdTask.status.wireValue,
      );
      await _markPipelineStatus(
        recordId,
        GenerationRecordPipelineStatus.pollingTask,
      );
      _startTaskPolling(recordId: recordId, taskId: createdTask.taskId);
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
    _pollingTimers.remove(recordId)?.cancel();
    _debugLog('polling start record=$recordId task=$taskId');
    unawaited(_pollTask(recordId: recordId, taskId: taskId));
    _pollingTimers[recordId] = Timer.periodic(_taskPollInterval, (_) {
      unawaited(_pollTask(recordId: recordId, taskId: taskId));
    });
  }

  Future<void> _pollTask({
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
      _stopTaskPolling(recordId);
      return;
    }

    try {
      _debugLog('poll request start record=$recordId task=$taskId');
      final GenerationTask task = await _generationTaskRepository.fetchTask(
        taskId,
      );
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
          _stopTaskPolling(recordId);
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
          _stopTaskPolling(recordId);
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
          _stopTaskPolling(recordId);
          await _failRecord(
            recordId: recordId,
            errorCode: 'unknown_task_status',
            errorMessage: 'Generation task returned an unknown status.',
          );
      }
    } on BackendApiFailure catch (error) {
      _debugLog(
        'poll backend failure record=$recordId task=$taskId code=${error.code} status=${error.statusCode} message=${error.message}',
      );
      _stopTaskPolling(recordId);
      await _failRecord(
        recordId: recordId,
        errorCode: error.code,
        errorMessage: error.message,
      );
    } on Object catch (error) {
      _debugLog(
        'poll local failure record=$recordId task=$taskId error=$error',
      );
      _stopTaskPolling(recordId);
      await _failRecord(
        recordId: recordId,
        errorCode: 'task_poll_error',
        errorMessage: error.toString(),
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
    final GenerationRecord? record = await _generationRecordRepository.findById(
      recordId,
    );
    if (record == null) {
      _debugLog(
        'process result skipped record=$recordId reason=missing-record',
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
      final String? resultUrl = await loadResultUrl(recordId);
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
      await _generationRecordRepository.markResultSaved(
        recordId: recordId,
        updatedAt: savedAt,
        resultAssetId: savedImage.assetId,
        resultSavedAt: savedAt,
        resultSizeBytes: result.bytes.length,
      );
      await _deleteTemporaryResultFile(recordId: recordId, path: result.path);
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
    final Timer? timer = _pollingTimers.remove(jobId);
    timer?.cancel();
    if (timer != null) {
      _debugLog('polling stop job=$jobId');
    }
  }

  void _cancelAllPolling() {
    if (_pollingTimers.isNotEmpty) {
      _debugLog('dispose cancel polling count=${_pollingTimers.length}');
    }
    for (final Timer timer in _pollingTimers.values) {
      timer.cancel();
    }
    _pollingTimers.clear();
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
        resultAssetId: record.resultAssetId,
        isResultFavorite: record.resultIsFavorite,
        resultFavoriteFeedbackSubmittedAt:
            record.resultFavoriteFeedbackSubmittedAt,
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
      resultAssetId: record.resultAssetId,
      isResultFavorite: record.resultIsFavorite,
      resultFavoriteFeedbackSubmittedAt:
          record.resultFavoriteFeedbackSubmittedAt,
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
        record.resultAvailability ==
            GenerationRecordResultAvailability.savedToPhotoLibrary.name) {
      try {
        final String? resolvedPath = await _photoLibraryAssetStore
            .resolveImagePath(resultAssetId);
        if (resolvedPath != null && resolvedPath.isNotEmpty) {
          _runtimeFor(record.recordId).processedResultPath = resolvedPath;
          return resolvedPath;
        }
        _debugLog(
          'result asset unresolved record=${record.recordId} asset=$resultAssetId',
        );
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
      GenerationRecordPipelineStatus.completingUpload =>
        GenerationSubmissionStatus.completingUpload,
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

  bool get hasFreshResultUrl {
    final String? url = resultUrl;
    final DateTime? expiresAt = resultUrlExpiresAt;
    return url != null &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now());
  }
}
