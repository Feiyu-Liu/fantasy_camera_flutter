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

    await container
        .read(generationSubmissionControllerProvider.notifier)
        .submitCapturedFile(XFile('/tmp/photo.jpg'));

    final GenerationSubmissionJob job = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single;
    expect(job.status, GenerationSubmissionStatus.submitted);
    expect(job.uploadSessionId, 'upload-1');
    expect(job.taskId, 'task-1');
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
            job.status == GenerationSubmissionStatus.submitted,
      ),
      isTrue,
    );
  });
}

ProviderContainer _container({
  _FakeCapturedFileReader? reader,
  _FakeUploadRepository? uploadRepository,
  _FakeGenerationTaskRepository? taskRepository,
}) {
  return ProviderContainer(
    overrides: <Override>[
      capturedFileReaderProvider.overrideWithValue(
        reader ?? _FakeCapturedFileReader(),
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
  Future<ResultUrl> createResultUrl(String taskId) {
    throw UnimplementedError();
  }

  @override
  Future<GenerationTask> fetchTask(String taskId) {
    throw UnimplementedError();
  }

  @override
  Future<List<GenerationTask>> listTasks({int limit = 20}) {
    throw UnimplementedError();
  }
}

final DateTime _fixedExpiresAt = DateTime.parse('2026-05-29T01:00:00Z');
