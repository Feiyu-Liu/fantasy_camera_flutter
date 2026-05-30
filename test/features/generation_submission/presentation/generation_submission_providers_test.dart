import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/api_failure.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/generation_task.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/json_value.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/upload_session.dart';
import 'package:fantasy_camera_flutter/features/backend_api/presentation/backend_api_providers.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_submission_job.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_submission_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('submits captured file through the upload and task pipeline', () async {
    final _FakeCapturedFileReader reader = _FakeCapturedFileReader();
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final ProviderContainer container = _container(
      reader: reader,
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
    expect(reader.readPaths, <String>['/tmp/photo.jpg']);
    expect(uploadRepository.events, <String>[
      'create:image/jpeg:3',
      'upload:upload-1:3',
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
      },
    );
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
    expect(uploadRepository.events, <String>['create:image/jpeg:3']);
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
      'create:image/jpeg:3',
      'upload:upload-1:3',
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
      'create:image/jpeg:3',
      'upload:upload-1:3',
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

  test('polling completed task marks job completed', () async {
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
    expect(job.status, GenerationSubmissionStatus.completed);
    expect(job.taskStatus, GenerationTaskStatus.completed);
    expect(job.resultImageObjectId, 'result-1');
    expect(taskRepository.fetchTaskIds, <String>['task-1', 'task-1']);
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

  test('completed job loads and caches result url', () async {
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
  _FakeCapturedFileReader? reader,
  _FakePhotoLibrarySaver? photoLibrarySaver,
  _FakeUploadRepository? uploadRepository,
  _FakeGenerationTaskRepository? taskRepository,
}) {
  return ProviderContainer(
    overrides: <Override>[
      capturedFileReaderProvider.overrideWithValue(
        reader ?? _FakeCapturedFileReader(),
      ),
      photoLibrarySaverProvider.overrideWithValue(
        photoLibrarySaver ?? _FakePhotoLibrarySaver(),
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

class _FakeCapturedFileReader implements CapturedFileReader {
  final List<String> readPaths = <String>[];

  @override
  Future<Uint8List> readAsBytes(XFile file) async {
    readPaths.add(file.path);
    return Uint8List.fromList(<int>[1, 2, 3]);
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
        'content-length': '3',
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
