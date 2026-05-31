import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';

import '../../../config/app_config.dart';
import '../../backend_api/data/backend_repositories.dart';
import '../../backend_api/domain/api_failure.dart';
import '../../backend_api/domain/generation_task.dart';
import '../../backend_api/domain/prompt_config.dart';
import '../../backend_api/domain/upload_session.dart';
import '../data/generation_image_processor.dart';
import '../data/generation_submission_adapters.dart';
import '../domain/generation_submission_job.dart';

class GenerationSubmissionService extends ChangeNotifier {
  GenerationSubmissionService({
    required UploadRepository uploadRepository,
    required GenerationTaskRepository generationTaskRepository,
    required PhotoLibrarySaver photoLibrarySaver,
    required GenerationImageProcessor imageProcessor,
    GenerationSubmissionState initialState = const GenerationSubmissionState(),
  }) : _uploadRepository = uploadRepository,
       _generationTaskRepository = generationTaskRepository,
       _photoLibrarySaver = photoLibrarySaver,
       _imageProcessor = imageProcessor,
       _state = initialState;

  static const int _maxJobs = 20;
  static const Duration _taskPollInterval = Duration(seconds: 3);

  final UploadRepository _uploadRepository;
  final GenerationTaskRepository _generationTaskRepository;
  final PhotoLibrarySaver _photoLibrarySaver;
  final GenerationImageProcessor _imageProcessor;
  final Map<String, Timer> _pollingTimers = <String, Timer>{};

  int _nextJobId = 0;
  GenerationSubmissionState _state;

  GenerationSubmissionState get state => _state;

  String queueCapturedFile(
    XFile file, {
    PromptSelectionSnapshot? promptSelection,
  }) {
    final GenerationSubmissionJob job = _createAwaitingConfirmationJob(
      file,
      promptSelection: promptSelection,
    );
    _debugLog('queue captured job=${job.id} path=${file.path}');
    _upsertJob(job);
    unawaited(_saveCapturedFileToPhotoLibrary(job.id, file.path));
    return job.id;
  }

  String queueGalleryFile(
    XFile file, {
    PromptSelectionSnapshot? promptSelection,
  }) {
    final GenerationSubmissionJob job = _createAwaitingConfirmationJob(
      file,
      promptSelection: promptSelection,
    );
    _debugLog('queue gallery job=${job.id} path=${file.path}');
    _upsertJob(job);
    return job.id;
  }

  Future<void> submitCapturedFile(XFile file) async {
    final String jobId = queueCapturedFile(file);
    await confirmJob(jobId);
  }

  Future<void> confirmJob(String jobId) async {
    final GenerationSubmissionJob? job = _findJob(jobId);
    if (job == null) {
      _debugLog('confirm skipped job=$jobId reason=missing-job');
      return;
    }
    if (job.status != GenerationSubmissionStatus.awaitingConfirmation) {
      _debugLog('confirm skipped job=$jobId reason=status-${job.status.name}');
      return;
    }

    _debugLog('confirm job=$jobId path=${job.imagePath}');
    await _submitJob(job);
  }

  void cancelJob(String jobId) {
    final GenerationSubmissionJob? job = _findJob(jobId);
    if (job == null) {
      _debugLog('cancel skipped job=$jobId reason=missing-job');
      return;
    }
    if (job.status != GenerationSubmissionStatus.awaitingConfirmation) {
      _debugLog('cancel skipped job=$jobId reason=status-${job.status.name}');
      return;
    }
    _debugLog('cancel job=$jobId');
    _stopTaskPolling(jobId);
    _setState(
      GenerationSubmissionState(
        jobs: _state.jobs
            .where((GenerationSubmissionJob current) => current.id != jobId)
            .toList(growable: false),
      ),
    );
  }

  Future<String?> loadResultUrl(String jobId) async {
    final GenerationSubmissionJob? job = _findJob(jobId);
    if (job == null || !_canLoadResultUrl(job.status) || job.taskId == null) {
      _debugLog(
        'result url skipped job=$jobId reason=not-completed-or-missing-task',
      );
      return null;
    }

    return _loadResultUrlForJob(job);
  }

  Future<void> pollTaskNowForDebug(String jobId) async {
    final GenerationSubmissionJob? job = _findJob(jobId);
    final String? taskId = job?.taskId;
    if (taskId == null) {
      return;
    }
    await _pollTask(jobId: jobId, taskId: taskId);
  }

  @override
  void dispose() {
    _cancelAllPolling();
    super.dispose();
  }

  GenerationSubmissionJob _createAwaitingConfirmationJob(
    XFile file, {
    PromptSelectionSnapshot? promptSelection,
  }) {
    final DateTime now = DateTime.now();
    final String jobId = 'local-${now.microsecondsSinceEpoch}-${_nextJobId++}';
    return GenerationSubmissionJob(
      id: jobId,
      imagePath: file.path,
      status: GenerationSubmissionStatus.awaitingConfirmation,
      createdAt: now,
      updatedAt: now,
      promptSelection: promptSelection ?? PromptSelectionSnapshot.fallback,
    );
  }

  Future<void> _saveCapturedFileToPhotoLibrary(
    String jobId,
    String imagePath,
  ) async {
    try {
      _debugLog(
        'photo library save start job=$jobId path=$imagePath album=${AppConfig.generationPhotoAlbumName}',
      );
      await _photoLibrarySaver.saveImage(
        imagePath,
        album: AppConfig.generationPhotoAlbumName,
      );
      _debugLog(
        'photo library save success job=$jobId album=${AppConfig.generationPhotoAlbumName}',
      );
    } on Object catch (error) {
      _debugLog('photo library save failure job=$jobId error=$error');
      _updateJob(jobId, (GenerationSubmissionJob current) {
        if (current.status != GenerationSubmissionStatus.awaitingConfirmation) {
          return current;
        }
        return current.copyWith(
          errorCode: 'photo_library_save_failed',
          errorMessage: error.toString(),
          updatedAt: DateTime.now(),
        );
      });
    }
  }

  Future<void> _submitJob(GenerationSubmissionJob job) async {
    final String jobId = job.id;
    String stage = 'queued';
    _debugLog('submit start job=$jobId path=${job.imagePath}');
    _markStatus(jobId, GenerationSubmissionStatus.queued, clearError: true);

    try {
      stage = 'preparingUploadImage';
      _markStatus(
        jobId,
        GenerationSubmissionStatus.preparingUploadImage,
        clearResultSaveError: true,
      );
      _debugLog('prepare upload image start job=$jobId');
      final PreparedUploadImage uploadImage = await _imageProcessor
          .prepareUploadImage(jobId: jobId, sourcePath: job.imagePath);
      _debugLog(
        'prepare upload image success job=$jobId path=${uploadImage.path} bytes=${uploadImage.bytes.length} exifKeys=${uploadImage.sourceExif.length}',
      );
      _updateJob(
        jobId,
        (GenerationSubmissionJob current) => current.copyWith(
          uploadImagePath: uploadImage.path,
          uploadImageSizeBytes: uploadImage.bytes.length,
          sourceExif: uploadImage.sourceExif,
          updatedAt: DateTime.now(),
        ),
      );

      stage = 'readingFile';
      _markStatus(jobId, GenerationSubmissionStatus.readingFile);
      final Uint8List bytes = uploadImage.bytes;
      _debugLog('read cleaned file success job=$jobId bytes=${bytes.length}');

      stage = 'creatingUpload';
      _markStatus(jobId, GenerationSubmissionStatus.creatingUpload);
      _debugLog('create upload start job=$jobId bytes=${bytes.length}');
      final UploadSession uploadSession = await _uploadRepository.createUpload(
        contentType: 'image/jpeg',
        bytes: bytes,
      );
      _debugLog(
        'create upload success job=$jobId uploadSession=${uploadSession.uploadSessionId} source=${uploadSession.sourceImageObjectId}',
      );
      _updateJob(
        jobId,
        (GenerationSubmissionJob current) => current.copyWith(
          uploadSessionId: uploadSession.uploadSessionId,
          updatedAt: DateTime.now(),
        ),
      );

      stage = 'uploading';
      _markStatus(jobId, GenerationSubmissionStatus.uploading);
      _debugLog(
        'upload bytes start job=$jobId uploadSession=${uploadSession.uploadSessionId}',
      );
      await _uploadRepository.uploadBytes(
        uploadSession: uploadSession,
        bytes: bytes,
      );
      _debugLog('upload bytes success job=$jobId');

      stage = 'completingUpload';
      _markStatus(jobId, GenerationSubmissionStatus.completingUpload);
      _debugLog(
        'complete upload start job=$jobId uploadSession=${uploadSession.uploadSessionId}',
      );
      await _uploadRepository.completeUpload(uploadSession.uploadSessionId);
      _debugLog('complete upload success job=$jobId');

      stage = 'creatingTask';
      _markStatus(jobId, GenerationSubmissionStatus.creatingTask);
      final PromptSelectionSnapshot promptSelection =
          job.promptSelection ?? PromptSelectionSnapshot.fallback;
      _debugLog(
        'create task start job=$jobId prompt=${promptSelection.promptStyle}/${promptSelection.captureMode} switches=${promptSelection.switches}',
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
        'create task success job=$jobId task=${createdTask.taskId} status=${createdTask.status.wireValue} credits=${createdTask.costCredits}',
      );

      _updateJob(
        jobId,
        (GenerationSubmissionJob current) => current.copyWith(
          status: GenerationSubmissionStatus.submitted,
          taskId: createdTask.taskId,
          taskStatus: createdTask.status,
          updatedAt: DateTime.now(),
          clearError: true,
        ),
      );
      _startTaskPolling(jobId: jobId, taskId: createdTask.taskId);
    } on BackendApiFailure catch (error) {
      _debugLog(
        'submit backend failure job=$jobId stage=$stage code=${error.code} status=${error.statusCode} requestId=${error.requestId ?? 'none'} message=${error.message} details=${error.details ?? 'none'}',
      );
      _failJob(
        jobId: jobId,
        errorCode: error.code,
        errorMessage: error.message,
      );
    } on Object catch (error) {
      _debugLog('submit local failure job=$jobId error=$error');
      _failJob(
        jobId: jobId,
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

  Future<String?> _loadResultUrlForJob(GenerationSubmissionJob job) async {
    final String jobId = job.id;

    if (job.hasFreshResultUrl) {
      _debugLog('result url cache hit job=$jobId task=${job.taskId}');
      return job.resultUrl;
    }

    try {
      _debugLog('result url request start job=$jobId task=${job.taskId}');
      final ResultUrl result = await _generationTaskRepository.createResultUrl(
        job.taskId!,
      );
      final DateTime expiresAt = DateTime.now().add(
        Duration(seconds: result.expiresInSeconds),
      );
      _updateJob(
        jobId,
        (GenerationSubmissionJob current) => current.copyWith(
          resultUrl: result.url,
          resultUrlExpiresAt: expiresAt,
          updatedAt: DateTime.now(),
          clearError: true,
        ),
      );
      _debugLog(
        'result url request success job=$jobId task=${job.taskId} expiresIn=${result.expiresInSeconds}s',
      );
      return result.url;
    } on BackendApiFailure catch (error) {
      _debugLog(
        'result url backend failure job=$jobId task=${job.taskId} code=${error.code} status=${error.statusCode} message=${error.message}',
      );
      _updateJob(
        jobId,
        (GenerationSubmissionJob current) => current.copyWith(
          errorCode: error.code,
          errorMessage: error.message,
          updatedAt: DateTime.now(),
        ),
      );
      return null;
    } on Object catch (error) {
      _debugLog(
        'result url local failure job=$jobId task=${job.taskId} error=$error',
      );
      _updateJob(
        jobId,
        (GenerationSubmissionJob current) => current.copyWith(
          errorCode: 'result_url_error',
          errorMessage: error.toString(),
          updatedAt: DateTime.now(),
        ),
      );
      return null;
    }
  }

  void _startTaskPolling({required String jobId, required String taskId}) {
    _pollingTimers.remove(jobId)?.cancel();
    _markStatus(jobId, GenerationSubmissionStatus.pollingTask);
    _debugLog('polling start job=$jobId task=$taskId');
    unawaited(_pollTask(jobId: jobId, taskId: taskId));
    _pollingTimers[jobId] = Timer.periodic(_taskPollInterval, (_) {
      unawaited(_pollTask(jobId: jobId, taskId: taskId));
    });
  }

  Future<void> _pollTask({
    required String jobId,
    required String taskId,
  }) async {
    final GenerationSubmissionJob? currentJob = _findJob(jobId);
    if (currentJob == null || currentJob.isTerminal) {
      _debugLog(
        'poll skipped job=$jobId task=$taskId reason=${currentJob == null ? 'missing-job' : 'terminal-${currentJob.status.name}'}',
      );
      _stopTaskPolling(jobId);
      return;
    }

    try {
      _debugLog('poll request start job=$jobId task=$taskId');
      final GenerationTask task = await _generationTaskRepository.fetchTask(
        taskId,
      );
      _debugLog(
        'poll response job=$jobId task=$taskId status=${task.status.wireValue} result=${task.resultImageObjectId ?? 'none'} errorCode=${task.lastErrorCode ?? 'none'} errorMessage=${task.lastErrorMessage ?? 'none'}',
      );
      switch (task.status) {
        case GenerationTaskStatus.pending:
        case GenerationTaskStatus.processing:
        case GenerationTaskStatus.modelRunning:
          _updateJob(
            jobId,
            (GenerationSubmissionJob current) => current.copyWith(
              status: GenerationSubmissionStatus.pollingTask,
              taskStatus: task.status,
              resultImageObjectId: task.resultImageObjectId,
              updatedAt: DateTime.now(),
              clearError: true,
            ),
          );
        case GenerationTaskStatus.completed:
          _debugLog('poll completed job=$jobId task=$taskId');
          _stopTaskPolling(jobId);
          _updateJob(
            jobId,
            (GenerationSubmissionJob current) => current.copyWith(
              status: GenerationSubmissionStatus.completed,
              taskStatus: task.status,
              resultImageObjectId: task.resultImageObjectId,
              updatedAt: DateTime.now(),
              clearError: true,
            ),
          );
          await _processCompletedResult(jobId: jobId, taskId: taskId);
        case GenerationTaskStatus.failed:
        case GenerationTaskStatus.canceled:
          _debugLog(
            'poll terminal failure job=$jobId task=$taskId status=${task.status.wireValue} code=${task.lastErrorCode ?? task.status.wireValue} message=${task.lastErrorMessage ?? 'none'}',
          );
          _stopTaskPolling(jobId);
          _updateJob(
            jobId,
            (GenerationSubmissionJob current) => current.copyWith(
              status: GenerationSubmissionStatus.failed,
              taskStatus: task.status,
              resultImageObjectId: task.resultImageObjectId,
              errorCode: task.lastErrorCode ?? task.status.wireValue,
              errorMessage:
                  task.lastErrorMessage ??
                  'Generation task ${task.status.wireValue}.',
              updatedAt: DateTime.now(),
            ),
          );
        case GenerationTaskStatus.unknown:
          _debugLog('poll unknown status job=$jobId task=$taskId');
          _stopTaskPolling(jobId);
          _failJob(
            jobId: jobId,
            errorCode: 'unknown_task_status',
            errorMessage: 'Generation task returned an unknown status.',
          );
      }
    } on BackendApiFailure catch (error) {
      _debugLog(
        'poll backend failure job=$jobId task=$taskId code=${error.code} status=${error.statusCode} message=${error.message}',
      );
      _stopTaskPolling(jobId);
      _failJob(
        jobId: jobId,
        errorCode: error.code,
        errorMessage: error.message,
      );
    } on Object catch (error) {
      _debugLog('poll local failure job=$jobId task=$taskId error=$error');
      _stopTaskPolling(jobId);
      _failJob(
        jobId: jobId,
        errorCode: 'task_poll_error',
        errorMessage: error.toString(),
      );
    }
  }

  void _markStatus(
    String jobId,
    GenerationSubmissionStatus status, {
    bool clearError = false,
    bool clearResultSaveError = false,
  }) {
    _updateJob(
      jobId,
      (GenerationSubmissionJob job) => job.copyWith(
        status: status,
        updatedAt: DateTime.now(),
        clearError: clearError,
        clearResultSaveError: clearResultSaveError,
      ),
    );
  }

  Future<void> _processCompletedResult({
    required String jobId,
    required String taskId,
  }) async {
    final GenerationSubmissionJob? job = _findJob(jobId);
    if (job == null) {
      _debugLog('process result skipped job=$jobId reason=missing-job');
      return;
    }
    if (job.status != GenerationSubmissionStatus.completed) {
      _debugLog(
        'process result skipped job=$jobId reason=status-${job.status.name}',
      );
      return;
    }

    try {
      _debugLog('process result pipeline start job=$jobId task=$taskId');
      _markStatus(
        jobId,
        GenerationSubmissionStatus.processingResultImage,
        clearResultSaveError: true,
      );
      final String? resultUrl = await loadResultUrl(jobId);
      if (resultUrl == null) {
        throw StateError('Result URL was not available.');
      }
      final Map<String, Object> sourceExif =
          _findJob(jobId)?.sourceExif ?? const <String, Object>{};
      final ProcessedResultImage result = await _imageProcessor
          .processResultImage(
            jobId: jobId,
            resultUrl: resultUrl,
            sourceExif: sourceExif,
          );
      _debugLog('save processed result start job=$jobId path=${result.path}');
      await _photoLibrarySaver.saveImage(
        result.path,
        album: AppConfig.generationPhotoAlbumName,
      );
      _debugLog(
        'save processed result success job=$jobId bytes=${result.bytes.length}',
      );
      _updateJob(
        jobId,
        (GenerationSubmissionJob current) => current.copyWith(
          status: GenerationSubmissionStatus.resultSaved,
          processedResultPath: result.path,
          updatedAt: DateTime.now(),
          clearResultSaveError: true,
        ),
      );
    } on Object catch (error) {
      _debugLog('process result pipeline failure job=$jobId error=$error');
      _updateJob(
        jobId,
        (GenerationSubmissionJob current) => current.copyWith(
          status: GenerationSubmissionStatus.resultProcessingFailed,
          resultSaveErrorCode: 'result_processing_failed',
          resultSaveErrorMessage: error.toString(),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  void _failJob({
    required String jobId,
    required String errorCode,
    required String errorMessage,
  }) {
    _debugLog('mark failed job=$jobId code=$errorCode message=$errorMessage');
    _updateJob(
      jobId,
      (GenerationSubmissionJob job) => job.copyWith(
        status: GenerationSubmissionStatus.failed,
        errorCode: errorCode,
        errorMessage: errorMessage,
        updatedAt: DateTime.now(),
      ),
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

  GenerationSubmissionJob? _findJob(String jobId) {
    for (final GenerationSubmissionJob job in _state.jobs) {
      if (job.id == jobId) {
        return job;
      }
    }
    return null;
  }

  void _upsertJob(GenerationSubmissionJob job) {
    final List<GenerationSubmissionJob> nextJobs = <GenerationSubmissionJob>[
      job,
      ..._state.jobs.where((GenerationSubmissionJob current) {
        return current.id != job.id;
      }),
    ];
    _setState(
      GenerationSubmissionState(
        jobs: nextJobs.take(_maxJobs).toList(growable: false),
      ),
    );
  }

  void _updateJob(
    String jobId,
    GenerationSubmissionJob Function(GenerationSubmissionJob job) update,
  ) {
    _setState(
      GenerationSubmissionState(
        jobs: _state.jobs
            .map((GenerationSubmissionJob job) {
              return job.id == jobId ? update(job) : job;
            })
            .toList(growable: false),
      ),
    );
  }

  void _setState(GenerationSubmissionState nextState) {
    _state = nextState;
    notifyListeners();
  }

  void _debugLog(String message) {
    debugPrint('[GenerationSubmissionService] $message');
  }
}
