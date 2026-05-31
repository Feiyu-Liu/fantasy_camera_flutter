import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/api_failure.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/generation_task.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/json_value.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/prompt_config.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/upload_session.dart';
import 'package:fantasy_camera_flutter/features/backend_api/presentation/backend_api_providers.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_image_processor.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_submission_adapters.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_submission_job.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_submission_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('submits captured file through the upload and task pipeline', () async {
    final _FakeGenerationImageProcessor imageProcessor =
        _FakeGenerationImageProcessor();
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final ProviderContainer container = _container(
      imageProcessor: imageProcessor,
      uploadRepository: uploadRepository,
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);

    final GenerationSubmissionController notifier = container.read(
      generationSubmissionControllerProvider.notifier,
    );
    final String jobId = notifier.queueGalleryFile(XFile('/tmp/photo.jpg'));

    expect(
      container.read(generationSubmissionControllerProvider).jobs.single.status,
      GenerationSubmissionStatus.awaitingConfirmation,
    );
    expect(uploadRepository.events, isEmpty);
    expect(taskRepository.createdInputs, isEmpty);

    await notifier.confirmJob(jobId);

    final GenerationSubmissionJob job = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single;
    expect(job.status, GenerationSubmissionStatus.pollingTask);
    expect(job.uploadSessionId, 'upload-1');
    expect(job.taskId, 'task-1');
    expect(job.taskStatus, GenerationTaskStatus.pending);
    expect(imageProcessor.preparedSourcePaths, <String>['/tmp/photo.jpg']);
    expect(job.uploadImagePath, '/tmp/photo.jpg.cleaned.jpg');
    expect(job.uploadImageSizeBytes, 4);
    expect(job.sourceExif, <String, Object>{
      'DateTimeOriginal': '2026:05:29 00:00:00',
    });
    expect(uploadRepository.events, <String>[
      'create:image/jpeg:4',
      'upload:upload-1:4',
      'complete:upload-1',
    ]);
    expect(taskRepository.createdInputs.single.promptStyle, 'realistic');
    expect(taskRepository.createdInputs.single.captureMode, 'portrait');
    expect(
      taskRepository.createdInputs.single.userInput['switches'],
      <String, Object?>{
        'recompose': false,
        'beautifyFace': false,
        'cleanFrame': false,
        'backgroundBlur': false,
      },
    );
  });

  test('uses queued prompt snapshot when confirming a job', () async {
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final ProviderContainer container = _container(
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);

    const PromptSelectionSnapshot snapshot = PromptSelectionSnapshot(
      promptStyle: 'realistic',
      captureMode: 'portrait',
      appInputContractId: 'contract-1',
      switches: <String, bool>{
        'recompose': true,
        'beautifyFace': false,
        'cleanFrame': true,
        'backgroundBlur': false,
      },
    );
    final GenerationSubmissionController notifier = container.read(
      generationSubmissionControllerProvider.notifier,
    );
    final String jobId = notifier.queueGalleryFile(
      XFile('/tmp/photo.jpg'),
      promptSelection: snapshot,
    );

    container.read(promptSelectionControllerProvider.notifier).toggleSwitch(
      'beautifyFace',
    );
    await notifier.confirmJob(jobId);

    final CreateGenerationTaskInput input = taskRepository.createdInputs.single;
    expect(input.appInputContractId, 'contract-1');
    expect(input.userInput['switches'], <String, Object?>{
      'recompose': true,
      'beautifyFace': false,
      'cleanFrame': true,
      'backgroundBlur': false,
    });
  });

  test('queues captured file and saves it to the TesserCam album', () async {
    final _FakePhotoLibrarySaver photoLibrarySaver = _FakePhotoLibrarySaver();
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final ProviderContainer container = _container(
      photoLibrarySaver: photoLibrarySaver,
      uploadRepository: uploadRepository,
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);

    container
        .read(generationSubmissionControllerProvider.notifier)
        .queueCapturedFile(XFile('/tmp/photo.jpg'));
    await Future<void>.delayed(Duration.zero);

    final GenerationSubmissionJob job = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single;
    expect(job.status, GenerationSubmissionStatus.awaitingConfirmation);
    expect(photoLibrarySaver.events, <String>['save:/tmp/photo.jpg:TesserCam']);
    expect(uploadRepository.events, isEmpty);
    expect(taskRepository.createdInputs, isEmpty);
  });

  test(
    'keeps captured file awaiting confirmation when album save fails',
    () async {
      final _FakePhotoLibrarySaver photoLibrarySaver = _FakePhotoLibrarySaver()
        ..failure = StateError('photos denied');
      final ProviderContainer container = _container(
        photoLibrarySaver: photoLibrarySaver,
      );
      addTearDown(container.dispose);

      container
          .read(generationSubmissionControllerProvider.notifier)
          .queueCapturedFile(XFile('/tmp/photo.jpg'));
      await Future<void>.delayed(Duration.zero);

      final GenerationSubmissionJob job = container
          .read(generationSubmissionControllerProvider)
          .jobs
          .single;
      expect(job.status, GenerationSubmissionStatus.awaitingConfirmation);
      expect(job.errorCode, 'photo_library_save_failed');
      expect(job.errorMessage, contains('photos denied'));
    },
  );

  test(
    'canceling awaiting confirmation job removes it without submitting',
    () async {
      final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
      final _FakeGenerationTaskRepository taskRepository =
          _FakeGenerationTaskRepository();
      final ProviderContainer container = _container(
        uploadRepository: uploadRepository,
        taskRepository: taskRepository,
      );
      addTearDown(container.dispose);
      final GenerationSubmissionController notifier = container.read(
        generationSubmissionControllerProvider.notifier,
      );

      final String jobId = notifier.queueGalleryFile(XFile('/tmp/photo.jpg'));
      notifier.cancelJob(jobId);

      expect(
        container.read(generationSubmissionControllerProvider).jobs,
        isEmpty,
      );
      expect(uploadRepository.events, isEmpty);
      expect(taskRepository.createdInputs, isEmpty);
    },
  );

  test('marks job failed when upload creation fails', () async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository()
      ..createUploadFailure = const BackendApiFailure(
        code: 'conflict',
        message: 'Insufficient credits',
        statusCode: 409,
      );
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final ProviderContainer container = _container(
      uploadRepository: uploadRepository,
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);

    await container
        .read(generationSubmissionControllerProvider.notifier)
        .submitCapturedFile(XFile('/tmp/photo.jpg'));

    final GenerationSubmissionJob job = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single;
    expect(job.status, GenerationSubmissionStatus.failed);
    expect(job.errorCode, 'conflict');
    expect(uploadRepository.events, <String>['create:image/jpeg:4']);
    expect(taskRepository.createdInputs, isEmpty);
  });

  test('marks job failed when signed upload fails', () async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository()
      ..uploadFailure = const BackendApiFailure(
        code: 'http_error',
        message: 'Signature mismatch',
        statusCode: 403,
      );
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final ProviderContainer container = _container(
      uploadRepository: uploadRepository,
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);

    await container
        .read(generationSubmissionControllerProvider.notifier)
        .submitCapturedFile(XFile('/tmp/photo.jpg'));

    final GenerationSubmissionJob job = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single;
    expect(job.status, GenerationSubmissionStatus.failed);
    expect(job.uploadSessionId, 'upload-1');
    expect(job.errorCode, 'http_error');
    expect(uploadRepository.events, <String>[
      'create:image/jpeg:4',
      'upload:upload-1:4',
    ]);
    expect(taskRepository.createdInputs, isEmpty);
  });

  test('marks job failed when task creation fails', () async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..createTaskFailure = const BackendApiFailure(
            code: 'task_create_failed',
            message: 'Generation task was not created',
            statusCode: 502,
          );
    final ProviderContainer container = _container(
      uploadRepository: uploadRepository,
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);

    await container
        .read(generationSubmissionControllerProvider.notifier)
        .submitCapturedFile(XFile('/tmp/photo.jpg'));

    final GenerationSubmissionJob job = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single;
    expect(job.status, GenerationSubmissionStatus.failed);
    expect(job.uploadSessionId, 'upload-1');
    expect(job.errorCode, 'task_create_failed');
    expect(uploadRepository.events, <String>[
      'create:image/jpeg:4',
      'upload:upload-1:4',
      'complete:upload-1',
    ]);
  });

  test('can submit multiple captured files without replacing jobs', () async {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);
    final GenerationSubmissionController notifier = container.read(
      generationSubmissionControllerProvider.notifier,
    );

    await Future.wait(<Future<void>>[
      notifier.submitCapturedFile(XFile('/tmp/first.jpg')),
      notifier.submitCapturedFile(XFile('/tmp/second.jpg')),
    ]);

    final List<GenerationSubmissionJob> jobs = container
        .read(generationSubmissionControllerProvider)
        .jobs;
    expect(jobs, hasLength(2));
    expect(
      jobs.map((GenerationSubmissionJob job) => job.imagePath).toSet(),
      <String>{'/tmp/first.jpg', '/tmp/second.jpg'},
    );
    expect(
      jobs.every(
        (GenerationSubmissionJob job) =>
            job.status == GenerationSubmissionStatus.pollingTask,
      ),
      isTrue,
    );
  });

  test('polling completed task processes and saves result image', () async {
    final _FakePhotoLibrarySaver photoLibrarySaver = _FakePhotoLibrarySaver();
    final _FakeGenerationImageProcessor imageProcessor =
        _FakeGenerationImageProcessor();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..fetchTaskResponses.add(
            _task(status: GenerationTaskStatus.processing),
          )
          ..fetchTaskResponses.add(
            _task(
              status: GenerationTaskStatus.completed,
              resultImageObjectId: 'result-1',
            ),
          );
    final ProviderContainer container = _container(
      photoLibrarySaver: photoLibrarySaver,
      imageProcessor: imageProcessor,
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);

    await container
        .read(generationSubmissionControllerProvider.notifier)
        .submitCapturedFile(XFile('/tmp/photo.jpg'));
    await Future<void>.delayed(Duration.zero);

    final GenerationSubmissionController notifier = container.read(
      generationSubmissionControllerProvider.notifier,
    );
    final String jobId = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single
        .id;

    await notifier.pollTaskNowForDebug(jobId);

    final GenerationSubmissionJob job = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single;
    expect(job.status, GenerationSubmissionStatus.resultSaved);
    expect(job.taskStatus, GenerationTaskStatus.completed);
    expect(job.resultImageObjectId, 'result-1');
    expect(job.resultUrl, 'https://example.com/result-1.jpg');
    expect(job.processedResultPath, '/tmp/photo.jpg.cleaned.jpg.result.heic');
    expect(imageProcessor.processedResultUrls, <String>[
      'https://example.com/result-1.jpg',
    ]);
    expect(imageProcessor.processedSourceExif.single, <String, Object>{
      'DateTimeOriginal': '2026:05:29 00:00:00',
    });
    expect(photoLibrarySaver.events, <String>[
      'save:/tmp/photo.jpg:TesserCam',
      'save:/tmp/photo.jpg.cleaned.jpg.result.heic:TesserCam',
    ]);
    expect(taskRepository.fetchTaskIds, <String>['task-1', 'task-1']);
  });

  test('result processing failure marks postprocess failure status', () async {
    final _FakeGenerationImageProcessor imageProcessor =
        _FakeGenerationImageProcessor()
          ..processFailure = StateError('heif unsupported');
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..fetchTaskResponses.add(
            _task(status: GenerationTaskStatus.completed),
          );
    final ProviderContainer container = _container(
      imageProcessor: imageProcessor,
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);

    await container
        .read(generationSubmissionControllerProvider.notifier)
        .submitCapturedFile(XFile('/tmp/photo.jpg'));
    await Future<void>.delayed(Duration.zero);

    final GenerationSubmissionJob job = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single;
    expect(job.status, GenerationSubmissionStatus.resultProcessingFailed);
    expect(job.taskStatus, GenerationTaskStatus.completed);
    expect(job.resultSaveErrorCode, 'result_processing_failed');
    expect(job.resultSaveErrorMessage, contains('heif unsupported'));
  });

  test('polling failed task marks job failed', () async {
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..fetchTaskResponses.add(
            _task(
              status: GenerationTaskStatus.failed,
              lastErrorCode: 'provider_error',
              lastErrorMessage: 'Provider failed',
            ),
          );
    final ProviderContainer container = _container(
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);

    await container
        .read(generationSubmissionControllerProvider.notifier)
        .submitCapturedFile(XFile('/tmp/photo.jpg'));
    await Future<void>.delayed(Duration.zero);

    final GenerationSubmissionJob job = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single;
    expect(job.status, GenerationSubmissionStatus.failed);
    expect(job.taskStatus, GenerationTaskStatus.failed);
    expect(job.errorCode, 'provider_error');
    expect(job.errorMessage, 'Provider failed');
  });

  test('completed job keeps cached result url after auto processing', () async {
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..fetchTaskResponses.add(
            _task(
              status: GenerationTaskStatus.completed,
              resultImageObjectId: 'result-1',
            ),
          );
    final ProviderContainer container = _container(
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);

    await container
        .read(generationSubmissionControllerProvider.notifier)
        .submitCapturedFile(XFile('/tmp/photo.jpg'));
    await Future<void>.delayed(Duration.zero);
    final GenerationSubmissionController notifier = container.read(
      generationSubmissionControllerProvider.notifier,
    );
    final String jobId = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single
        .id;

    final String? firstUrl = await notifier.loadResultUrl(jobId);
    final String? secondUrl = await notifier.loadResultUrl(jobId);

    expect(firstUrl, 'https://example.com/result-1.jpg');
    expect(secondUrl, 'https://example.com/result-1.jpg');
    expect(taskRepository.resultUrlTaskIds, <String>['task-1']);
    final GenerationSubmissionJob job = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single;
    expect(job.resultUrl, 'https://example.com/result-1.jpg');
    expect(job.resultUrlExpiresAt, isNotNull);
  });
}

ProviderContainer _container({
  _FakePhotoLibrarySaver? photoLibrarySaver,
  _FakeGenerationImageProcessor? imageProcessor,
  _FakeUploadRepository? uploadRepository,
  _FakeGenerationTaskRepository? taskRepository,
}) {
  return ProviderContainer(
    overrides: <Override>[
      photoLibrarySaverProvider.overrideWithValue(
        photoLibrarySaver ?? _FakePhotoLibrarySaver(),
      ),
      generationImageProcessorProvider.overrideWithValue(
        imageProcessor ?? _FakeGenerationImageProcessor(),
      ),
      uploadRepositoryProvider.overrideWithValue(
        uploadRepository ?? _FakeUploadRepository(),
      ),
      generationTaskRepositoryProvider.overrideWithValue(
        taskRepository ?? _FakeGenerationTaskRepository(),
      ),
    ],
  );
}

class _FakeGenerationImageProcessor implements GenerationImageProcessor {
  final List<String> preparedSourcePaths = <String>[];
  final List<String> processedResultUrls = <String>[];
  final List<Map<String, Object>> processedSourceExif = <Map<String, Object>>[];
  Object? prepareFailure;
  Object? processFailure;

  @override
  Future<PreparedUploadImage> prepareUploadImage({
    required String jobId,
    required String sourcePath,
  }) async {
    preparedSourcePaths.add(sourcePath);
    final Object? failure = prepareFailure;
    if (failure != null) {
      throw failure;
    }
    return PreparedUploadImage(
      path: '$sourcePath.cleaned.jpg',
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      sourceExif: const <String, Object>{
        'DateTimeOriginal': '2026:05:29 00:00:00',
      },
    );
  }

  @override
  Future<ProcessedResultImage> processResultImage({
    required String jobId,
    required String resultUrl,
    required Map<String, Object> sourceExif,
  }) async {
    processedResultUrls.add(resultUrl);
    processedSourceExif.add(sourceExif);
    final Object? failure = processFailure;
    if (failure != null) {
      throw failure;
    }
    return ProcessedResultImage(
      path: '/tmp/photo.jpg.cleaned.jpg.result.heic',
      bytes: Uint8List.fromList(<int>[9, 8, 7]),
    );
  }
}

class _FakePhotoLibrarySaver implements PhotoLibrarySaver {
  final List<String> events = <String>[];
  Object? failure;

  @override
  Future<void> saveImage(String path, {required String album}) async {
    events.add('save:$path:$album');
    final Object? failure = this.failure;
    if (failure != null) {
      throw failure;
    }
  }
}

class _FakeUploadRepository implements UploadRepository {
  final List<String> events = <String>[];
  BackendApiFailure? createUploadFailure;
  BackendApiFailure? uploadFailure;
  BackendApiFailure? completeUploadFailure;

  @override
  Future<UploadSession> createUpload({
    required String contentType,
    required Uint8List bytes,
  }) async {
    events.add('create:$contentType:${bytes.length}');
    final BackendApiFailure? failure = createUploadFailure;
    if (failure != null) {
      throw failure;
    }
    return UploadSession(
      uploadSessionId: 'upload-1',
      sourceImageObjectId: 'source-1',
      provider: 'r2',
      bucket: 'fantasy-camera',
      expiresAt: _fixedExpiresAt,
      requiredHeaders: <String, String>{
        'content-type': 'image/jpeg',
        'content-length': '${bytes.length}',
        'x-amz-checksum-sha256': 'checksum',
      },
      url: 'https://example.com/upload',
      expiresInSeconds: 600,
    );
  }

  @override
  Future<void> uploadBytes({
    required UploadSession uploadSession,
    required Uint8List bytes,
  }) async {
    events.add('upload:${uploadSession.uploadSessionId}:${bytes.length}');
    final BackendApiFailure? failure = uploadFailure;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<JsonObject> completeUpload(String uploadSessionId) async {
    events.add('complete:$uploadSessionId');
    final BackendApiFailure? failure = completeUploadFailure;
    if (failure != null) {
      throw failure;
    }
    return <String, Object?>{'id': uploadSessionId, 'status': 'uploaded'};
  }
}

class _FakeGenerationTaskRepository implements GenerationTaskRepository {
  final List<CreateGenerationTaskInput> createdInputs =
      <CreateGenerationTaskInput>[];
  final List<String> fetchTaskIds = <String>[];
  final List<GenerationTask> fetchTaskResponses = <GenerationTask>[];
  final List<String> resultUrlTaskIds = <String>[];
  BackendApiFailure? createTaskFailure;

  @override
  Future<CreatedGenerationTask> createTask(
    CreateGenerationTaskInput input,
  ) async {
    createdInputs.add(input);
    final BackendApiFailure? failure = createTaskFailure;
    if (failure != null) {
      throw failure;
    }
    return const CreatedGenerationTask(
      taskId: 'task-1',
      status: GenerationTaskStatus.pending,
      creditReservationId: 'reservation-1',
      costCredits: 2,
    );
  }

  @override
  Future<GenerationTask> cancelTask(String taskId) {
    throw UnimplementedError();
  }

  @override
  Future<ResultUrl> createResultUrl(String taskId) async {
    resultUrlTaskIds.add(taskId);
    return const ResultUrl(
      url: 'https://example.com/result-1.jpg',
      expiresInSeconds: 600,
    );
  }

  @override
  Future<GenerationTask> fetchTask(String taskId) async {
    fetchTaskIds.add(taskId);
    if (fetchTaskResponses.isEmpty) {
      return _task(status: GenerationTaskStatus.pending);
    }
    return fetchTaskResponses.removeAt(0);
  }

  @override
  Future<List<GenerationTask>> listTasks({int limit = 20}) {
    throw UnimplementedError();
  }
}

final DateTime _fixedExpiresAt = DateTime.parse('2026-05-29T01:00:00Z');

GenerationTask _task({
  required GenerationTaskStatus status,
  String? resultImageObjectId,
  String? lastErrorCode,
  String? lastErrorMessage,
}) {
  return GenerationTask(
    id: 'task-1',
    status: status,
    promptStyle: 'realistic',
    captureMode: 'portrait',
    sourceImageObjectId: 'source-1',
    resultImageObjectId: resultImageObjectId,
    costCredits: 2,
    attemptCount: 1,
    maxAttempts: 3,
    lastErrorCode: lastErrorCode,
    lastErrorMessage: lastErrorMessage,
    createdAt: DateTime.parse('2026-05-29T00:00:00Z'),
  );
}
