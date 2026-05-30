import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart' hide XFile;

import '../../backend_api/data/backend_repositories.dart';
import '../../backend_api/domain/api_failure.dart';
import '../../backend_api/domain/generation_task.dart';
import '../../backend_api/domain/upload_session.dart';
import '../../backend_api/presentation/backend_api_providers.dart';
import '../domain/generation_submission_job.dart';

final capturedFileReaderProvider = Provider<CapturedFileReader>((Ref ref) {
  return const XFileCapturedFileReader();
}, dependencies: const <ProviderOrFamily>[]);

final galleryImagePickerProvider = Provider<GalleryImagePicker>((Ref ref) {
  return ImagePickerGalleryImagePicker(ImagePicker());
}, dependencies: const <ProviderOrFamily>[]);

final photoLibrarySaverProvider = Provider<PhotoLibrarySaver>((Ref ref) {
  return const GalPhotoLibrarySaver();
}, dependencies: const <ProviderOrFamily>[]);

abstract interface class CapturedFileReader {
  Future<Uint8List> readAsBytes(XFile file);
}

abstract interface class GalleryImagePicker {
  Future<XFile?> pickImageFromGallery();
}

abstract interface class PhotoLibrarySaver {
  Future<void> saveImage(String path, {required String album});
}

class XFileCapturedFileReader implements CapturedFileReader {
  const XFileCapturedFileReader();

  @override
  Future<Uint8List> readAsBytes(XFile file) {
    return file.readAsBytes();
  }
}

class ImagePickerGalleryImagePicker implements GalleryImagePicker {
  const ImagePickerGalleryImagePicker(this._imagePicker);

  final ImagePicker _imagePicker;

  @override
  Future<XFile?> pickImageFromGallery() {
    return _imagePicker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: true,
    );
  }
}

class GalPhotoLibrarySaver implements PhotoLibrarySaver {
  const GalPhotoLibrarySaver();

  @override
  Future<void> saveImage(String path, {required String album}) {
    return Gal.putImage(path, album: album);
  }
}

final generationSubmissionControllerProvider =
    NotifierProvider<GenerationSubmissionController, GenerationSubmissionState>(
      GenerationSubmissionController.new,
      dependencies: <ProviderOrFamily>[
        capturedFileReaderProvider,
        photoLibrarySaverProvider,
        uploadRepositoryProvider,
        generationTaskRepositoryProvider,
      ],
    );

class GenerationSubmissionController
    extends Notifier<GenerationSubmissionState> {
  static const int _maxJobs = 20;
  static const Duration _taskPollInterval = Duration(seconds: 3);
  static const String _photoLibraryAlbumName = 'TesserCam';
  int _nextJobId = 0;
  final Map<String, Timer> _pollingTimers = <String, Timer>{};

  UploadRepository get _uploadRepository => ref.read(uploadRepositoryProvider);

  GenerationTaskRepository get _generationTaskRepository =>
      ref.read(generationTaskRepositoryProvider);

  CapturedFileReader get _capturedFileReader =>
      ref.read(capturedFileReaderProvider);

  PhotoLibrarySaver get _photoLibrarySaver =>
      ref.read(photoLibrarySaverProvider);

  @override
  GenerationSubmissionState build() {
    ref.onDispose(_cancelAllPolling);
    return const GenerationSubmissionState();
  }

  String queueCapturedFile(XFile file) {
    final GenerationSubmissionJob job = _createAwaitingConfirmationJob(file);
    _debugLog('queue captured job=${job.id} path=${file.path}');
    _upsertJob(job);
    unawaited(_saveCapturedFileToPhotoLibrary(job.id, file.path));
    return job.id;
  }

  String queueGalleryFile(XFile file) {
    final GenerationSubmissionJob job = _createAwaitingConfirmationJob(file);
    _debugLog('queue gallery job=${job.id} path=${file.path}');
    _upsertJob(job);
    return job.id;
  }

  Future<void> submitCapturedFile(XFile file) async {
    final String jobId = queueGalleryFile(file);
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
    state = GenerationSubmissionState(
      jobs: state.jobs
          .where((GenerationSubmissionJob current) => current.id != jobId)
          .toList(growable: false),
    );
  }

  GenerationSubmissionJob _createAwaitingConfirmationJob(XFile file) {
    final DateTime now = DateTime.now();
    final String jobId = 'local-${now.microsecondsSinceEpoch}-${_nextJobId++}';
    return GenerationSubmissionJob(
      id: jobId,
      imagePath: file.path,
      status: GenerationSubmissionStatus.awaitingConfirmation,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _saveCapturedFileToPhotoLibrary(
    String jobId,
    String imagePath,
  ) async {
    try {
      _debugLog(
        'photo library save start job=$jobId path=$imagePath album=$_photoLibraryAlbumName',
      );
      await _photoLibrarySaver.saveImage(
        imagePath,
        album: _photoLibraryAlbumName,
      );
      _debugLog(
        'photo library save success job=$jobId album=$_photoLibraryAlbumName',
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
      stage = 'readingFile';
      _markStatus(jobId, GenerationSubmissionStatus.readingFile);
      _debugLog('read file start job=$jobId');
      final Uint8List bytes = await _capturedFileReader.readAsBytes(
        XFile(job.imagePath),
      );
      _debugLog('read file success job=$jobId bytes=${bytes.length}');

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
      _debugLog('create task start job=$jobId');
      final CreatedGenerationTask createdTask = await _generationTaskRepository
          .createTask(
            CreateGenerationTaskInput(
              uploadSessionId: uploadSession.uploadSessionId,
              promptStyle: 'realistic',
              captureMode: 'portrait',
              userInput: const <String, Object?>{
                'switches': <String, Object?>{
                  'recompose': false,
                  'beautifyFace': false,
                  'cleanFrame': false,
                },
              },
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

  Future<String?> loadResultUrl(String jobId) async {
    final GenerationSubmissionJob? job = _findJob(jobId);
    if (job == null ||
        job.status != GenerationSubmissionStatus.completed ||
        job.taskId == null) {
      _debugLog(
        'result url skipped job=$jobId reason=not-completed-or-missing-task',
      );
      return null;
    }

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

  Future<void> pollTaskNowForDebug(String jobId) async {
    final GenerationSubmissionJob? job = _findJob(jobId);
    final String? taskId = job?.taskId;
    if (taskId == null) {
      return;
    }
    await _pollTask(jobId: jobId, taskId: taskId);
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
  }) {
    _updateJob(
      jobId,
      (GenerationSubmissionJob job) => job.copyWith(
        status: status,
        updatedAt: DateTime.now(),
        clearError: clearError,
      ),
    );
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

  void _debugLog(String message) {
    debugPrint('[GenerationSubmission] $message');
  }

  GenerationSubmissionJob? _findJob(String jobId) {
    for (final GenerationSubmissionJob job in state.jobs) {
      if (job.id == jobId) {
        return job;
      }
    }
    return null;
  }

  void _upsertJob(GenerationSubmissionJob job) {
    final List<GenerationSubmissionJob> nextJobs = <GenerationSubmissionJob>[
      job,
      ...state.jobs.where((GenerationSubmissionJob current) {
        return current.id != job.id;
      }),
    ];
    state = GenerationSubmissionState(
      jobs: nextJobs.take(_maxJobs).toList(growable: false),
    );
  }

  void _updateJob(
    String jobId,
    GenerationSubmissionJob Function(GenerationSubmissionJob job) update,
  ) {
    state = GenerationSubmissionState(
      jobs: state.jobs
          .map((GenerationSubmissionJob job) {
            return job.id == jobId ? update(job) : job;
          })
          .toList(growable: false),
    );
  }
}
