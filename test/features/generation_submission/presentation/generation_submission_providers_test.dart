import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/api_failure.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/feedback.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/generation_task.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/json_value.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/prompt_config.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/upload_session.dart';
import 'package:fantasy_camera_flutter/features/backend_api/presentation/backend_api_providers.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/application/generation_submission_service.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_record_database.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_record_repository.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_image_processor.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_original_file_store.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_submission_adapters.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_record.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_submission_job.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_record_providers.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_submission_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads built-in prompt styles and switches capture modes', () {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);

    final PromptSelectionController notifier = container.read(
      promptSelectionControllerProvider.notifier,
    );
    PromptSelectionState state = container.read(
      promptSelectionControllerProvider,
    );
    expect(
      state.styles.map((PromptStyleDefinition style) => style.id),
      <String>['realistic'],
    );
    expect(state.selectedPromptStyleId, 'realistic');
    expect(state.selectedCaptureModeId, 'portrait');
    expect(
      state.switches.map((PromptSwitchDefinition switchDefinition) {
        return switchDefinition.id;
      }),
      <String>['recompose', 'beautifyFace', 'cleanFrame', 'backgroundBlur'],
    );
    expect(state.appInputContractId, isNull);

    notifier.selectCaptureMode('general');
    state = container.read(promptSelectionControllerProvider);
    expect(state.selectedCaptureModeId, 'general');
    expect(state.switches, isEmpty);
    expect(state.snapshot.captureMode, 'general');

    notifier.selectPromptStyle('abstract');
    state = container.read(promptSelectionControllerProvider);
    expect(state.selectedPromptStyleId, 'realistic');
    expect(state.selectedCaptureModeId, 'general');
    expect(state.snapshot.promptStyle, 'realistic');
  });

  test('keeps switch values per prompt route', () {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);

    final PromptSelectionController notifier = container.read(
      promptSelectionControllerProvider.notifier,
    );
    notifier.toggleSwitch('recompose');
    notifier.selectCaptureMode('general');
    notifier.selectCaptureMode('portrait');

    final PromptSelectionState state = container.read(
      promptSelectionControllerProvider,
    );
    expect(state.values['recompose'], isTrue);
  });

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
    final String jobId = await notifier.queueGalleryFile(
      XFile('/tmp/photo.jpg'),
    );

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
    final String jobId = await notifier.queueGalleryFile(
      XFile('/tmp/photo.jpg'),
      promptSelection: snapshot,
    );

    container
        .read(promptSelectionControllerProvider.notifier)
        .toggleSwitch('beautifyFace');
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

  test('concurrent confirms submit a job only once', () async {
    final _FakeGenerationImageProcessor imageProcessor =
        _FakeGenerationImageProcessor()
          ..prepareDelay = const Duration(milliseconds: 20);
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
    final String jobId = await notifier.queueGalleryFile(
      XFile('/tmp/photo.jpg'),
    );

    await Future.wait(<Future<void>>[
      notifier.confirmJob(jobId),
      notifier.confirmJob(jobId),
    ]);

    expect(imageProcessor.preparedSourcePaths, <String>['/tmp/photo.jpg']);
    expect(uploadRepository.events, <String>[
      'create:image/jpeg:4',
      'upload:upload-1:4',
      'complete:upload-1',
    ]);
    expect(taskRepository.createdInputs, hasLength(1));
  });

  test('queues captured file into private original cache', () async {
    final _FakeGenerationOriginalFileStore originalFileStore =
        _FakeGenerationOriginalFileStore();
    final _FakePhotoLibraryAssetStore photoLibraryAssetStore =
        _FakePhotoLibraryAssetStore();
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final ProviderContainer container = _container(
      originalFileStore: originalFileStore,
      photoLibraryAssetStore: photoLibraryAssetStore,
      uploadRepository: uploadRepository,
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);

    await container
        .read(generationSubmissionControllerProvider.notifier)
        .queueCapturedFile(XFile('/tmp/photo.jpg'));

    final GenerationSubmissionJob job = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single;
    expect(job.status, GenerationSubmissionStatus.awaitingConfirmation);
    expect(job.imagePath, startsWith('/resolved/originals/'));
    expect(
      originalFileStore.storedRelativePaths.single,
      startsWith('originals/'),
    );
    expect(photoLibraryAssetStore.events, isEmpty);
    expect(uploadRepository.events, isEmpty);
    expect(taskRepository.createdInputs, isEmpty);
  });

  test(
    'queues captured file without saving original to photo library',
    () async {
      final _FakePhotoLibraryAssetStore photoLibraryAssetStore =
          _FakePhotoLibraryAssetStore()..failure = StateError('photos denied');
      final ProviderContainer container = _container(
        photoLibraryAssetStore: photoLibraryAssetStore,
      );
      addTearDown(container.dispose);

      await container
          .read(generationSubmissionControllerProvider.notifier)
          .queueCapturedFile(XFile('/tmp/photo.jpg'));

      final GenerationSubmissionJob job = container
          .read(generationSubmissionControllerProvider)
          .jobs
          .single;
      expect(job.status, GenerationSubmissionStatus.awaitingConfirmation);
      expect(job.errorCode, isNull);
      expect(job.errorMessage, isNull);
      expect(photoLibraryAssetStore.events, isEmpty);
    },
  );

  test(
    'canceling awaiting confirmation job removes it without submitting',
    () async {
      final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
      final _FakeGenerationTaskRepository taskRepository =
          _completedTaskRepository();
      final ProviderContainer container = _container(
        uploadRepository: uploadRepository,
        taskRepository: taskRepository,
      );
      addTearDown(container.dispose);
      final GenerationSubmissionController notifier = container.read(
        generationSubmissionControllerProvider.notifier,
      );

      final String jobId = await notifier.queueGalleryFile(
        XFile('/tmp/photo.jpg'),
      );
      await notifier.cancelJob(jobId);

      expect(
        container.read(generationSubmissionControllerProvider).jobs,
        isEmpty,
      );
      expect(uploadRepository.events, isEmpty);
      expect(taskRepository.createdInputs, isEmpty);
    },
  );

  test(
    'resolves gallery original from asset id after service restart',
    () async {
      final GenerationRecordDatabase database =
          GenerationRecordDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(database.close);

      final GenerationRecordRepository repository = GenerationRecordRepository(
        database,
      );
      final _FakeGenerationOriginalFileStore originalFileStore =
          _FakeGenerationOriginalFileStore();
      final _FakePhotoLibraryAssetStore photoLibraryAssetStore =
          _FakePhotoLibraryAssetStore();
      final GenerationSubmissionService firstService =
          GenerationSubmissionService(
            uploadRepository: _FakeUploadRepository(),
            generationTaskRepository: _FakeGenerationTaskRepository(),
            feedbackRepository: _FakeFeedbackRepository(),
            generationRecordRepository: repository,
            originalFileStore: originalFileStore,
            photoLibraryAssetStore: photoLibraryAssetStore,
            imageProcessor: _FakeGenerationImageProcessor(),
          );
      addTearDown(firstService.dispose);

      final String recordId = await firstService.queueGalleryFile(
        XFile('/tmp/gallery-picker-cache.jpg'),
        originalAssetId: 'asset-gallery-1',
      );
      final GenerationRecord? record = await repository.findById(recordId);
      expect(record?.originalAssetId, 'asset-gallery-1');
      expect(record?.originalLocalPath, isNull);

      final GenerationSubmissionService restartedService =
          GenerationSubmissionService(
            uploadRepository: _FakeUploadRepository(),
            generationTaskRepository: _FakeGenerationTaskRepository(),
            feedbackRepository: _FakeFeedbackRepository(),
            generationRecordRepository: repository,
            originalFileStore: originalFileStore,
            photoLibraryAssetStore: photoLibraryAssetStore,
            imageProcessor: _FakeGenerationImageProcessor(),
          );
      addTearDown(restartedService.dispose);

      final GenerationSubmissionState state = await restartedService
          .stateForRecords(await repository.listRecords());

      expect(state.jobs.single.imagePath, '/photos/asset-gallery-1.heic');
      expect(photoLibraryAssetStore.resolvedAssetIds, <String>[
        'asset-gallery-1',
      ]);
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
      everyElement(startsWith('/resolved/originals/')),
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
    final _FakePhotoLibraryAssetStore photoLibraryAssetStore =
        _FakePhotoLibraryAssetStore();
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
      photoLibraryAssetStore: photoLibraryAssetStore,
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
    expect(job.processedResultPath, '/photos/asset-result-1.heic');
    expect(imageProcessor.processedResultUrls, <String>[
      'https://example.com/result-1.jpg',
    ]);
    expect(imageProcessor.processedSourceExif.single, <String, Object>{
      'DateTimeOriginal': '2026:05:29 00:00:00',
    });
    expect(photoLibraryAssetStore.events, hasLength(1));
    expect(
      photoLibraryAssetStore.events.single,
      predicate<String>(
        (String value) =>
            value ==
            'save:/tmp/photo.jpg.cleaned.jpg.result.heic:TesserCam:TesserCam-$jobId.heic',
      ),
    );
    expect(photoLibraryAssetStore.resolvedAssetIds, <String>[
      'asset-result-1',
      'asset-result-1',
    ]);
    final GenerationRecord? record = await container
        .read(generationRecordRepositoryProvider)
        .findById(jobId);
    expect(record?.resultAssetId, 'asset-result-1');
    expect(record?.resultLocalCachePath, isNull);
    expect(taskRepository.fetchTaskIds, <String>['task-1', 'task-1']);
  });

  test('result not ready retries result url without marking failure', () async {
    final _FakePhotoLibraryAssetStore photoLibraryAssetStore =
        _FakePhotoLibraryAssetStore();
    final _FakeGenerationImageProcessor imageProcessor =
        _FakeGenerationImageProcessor();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..fetchTaskResponses.add(
            _task(
              status: GenerationTaskStatus.completed,
              resultImageObjectId: 'result-1',
            ),
          )
          ..resultUrlResponses.add(
            const BackendApiFailure(
              code: 'result_not_ready',
              message: 'Generation result is not ready',
              statusCode: 409,
            ),
          )
          ..resultUrlResponses.add(
            const ResultUrl(
              url: 'https://example.com/result-1.jpg',
              expiresInSeconds: 600,
            ),
          );
    final ProviderContainer container = _container(
      photoLibraryAssetStore: photoLibraryAssetStore,
      imageProcessor: imageProcessor,
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);

    await container
        .read(generationSubmissionControllerProvider.notifier)
        .submitCapturedFile(XFile('/tmp/photo.jpg'));

    final GenerationSubmissionJob deferredJob = await _waitForSingleJobStatus(
      container,
      GenerationSubmissionStatus.completed,
    );
    expect(deferredJob.resultSaveErrorCode, isNull);
    expect(taskRepository.resultUrlTaskIds, <String>['task-1']);
    expect(imageProcessor.processedResultUrls, isEmpty);

    final GenerationSubmissionJob savedJob = await _waitForSingleJobStatus(
      container,
      GenerationSubmissionStatus.resultSaved,
      timeout: const Duration(seconds: 5),
    );
    expect(savedJob.resultUrl, 'https://example.com/result-1.jpg');
    expect(taskRepository.resultUrlTaskIds, <String>['task-1', 'task-1']);
    expect(imageProcessor.processedResultUrls, <String>[
      'https://example.com/result-1.jpg',
    ]);
    expect(photoLibraryAssetStore.events, hasLength(1));
  });

  test('result url backend failure still marks postprocess failure', () async {
    final _FakeGenerationImageProcessor imageProcessor =
        _FakeGenerationImageProcessor();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..fetchTaskResponses.add(
            _task(
              status: GenerationTaskStatus.completed,
              resultImageObjectId: 'result-1',
            ),
          )
          ..resultUrlResponses.add(
            const BackendApiFailure(
              code: 'storage_error',
              message: 'Could not sign result URL',
              statusCode: 500,
            ),
          );
    final ProviderContainer container = _container(
      imageProcessor: imageProcessor,
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);

    await container
        .read(generationSubmissionControllerProvider.notifier)
        .submitCapturedFile(XFile('/tmp/photo.jpg'));

    final GenerationSubmissionJob failedJob = await _waitForSingleJobStatus(
      container,
      GenerationSubmissionStatus.resultProcessingFailed,
    );
    expect(failedJob.resultSaveErrorCode, 'result_processing_failed');
    expect(failedJob.resultSaveErrorMessage, contains('Result URL'));
    expect(taskRepository.resultUrlTaskIds, <String>['task-1']);
    expect(imageProcessor.processedResultUrls, isEmpty);
  });

  test('resumes polling task after service restart', () async {
    final GenerationRecordDatabase database =
        GenerationRecordDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(database.close);
    final GenerationRecordRepository repository = GenerationRecordRepository(
      database,
    );
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..fetchTaskResponses.add(
            _task(
              status: GenerationTaskStatus.completed,
              resultImageObjectId: 'result-1',
            ),
          );
    final _FakePhotoLibraryAssetStore photoLibraryAssetStore =
        _FakePhotoLibraryAssetStore();

    await repository.createCameraRecord(
      recordId: 'record-resume',
      originalLocalPath: 'originals/record-resume.heic',
      createdAt: DateTime.parse('2026-05-29T00:00:00Z'),
      promptStyle: 'realistic',
      captureMode: 'portrait',
    );
    await repository.updateTaskFields(
      recordId: 'record-resume',
      updatedAt: DateTime.parse('2026-05-29T00:00:01Z'),
      taskId: 'task-1',
      taskStatus: GenerationTaskStatus.pending.wireValue,
    );
    await repository.updatePipelineStatus(
      recordId: 'record-resume',
      status: GenerationRecordPipelineStatus.pollingTask,
      updatedAt: DateTime.parse('2026-05-29T00:00:02Z'),
    );

    final GenerationSubmissionService service = GenerationSubmissionService(
      uploadRepository: _FakeUploadRepository(),
      generationTaskRepository: taskRepository,
      feedbackRepository: _FakeFeedbackRepository(),
      generationRecordRepository: repository,
      originalFileStore: _FakeGenerationOriginalFileStore(),
      photoLibraryAssetStore: photoLibraryAssetStore,
      imageProcessor: _FakeGenerationImageProcessor(),
    );
    addTearDown(service.dispose);

    await service.resumeActiveRecords();

    final GenerationRecord? record = await repository.findById('record-resume');
    expect(taskRepository.fetchTaskIds, <String>['task-1']);
    expect(
      record?.pipelineStatus,
      GenerationRecordPipelineStatus.resultSaved.name,
    );
    expect(record?.resultAssetId, 'asset-result-1');
    expect(photoLibraryAssetStore.events.single, contains('record-resume'));
  });

  test('concurrent resume active records polls a task only once', () async {
    final GenerationRecordDatabase database =
        GenerationRecordDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(database.close);
    final GenerationRecordRepository repository = GenerationRecordRepository(
      database,
    );
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..fetchTaskDelay = const Duration(milliseconds: 20)
          ..fetchTaskResponses.add(
            _task(
              status: GenerationTaskStatus.completed,
              resultImageObjectId: 'result-1',
            ),
          );
    final _FakePhotoLibraryAssetStore photoLibraryAssetStore =
        _FakePhotoLibraryAssetStore();

    await repository.createCameraRecord(
      recordId: 'record-resume',
      originalLocalPath: 'originals/record-resume.heic',
      createdAt: DateTime.parse('2026-05-29T00:00:00Z'),
      promptStyle: 'realistic',
      captureMode: 'portrait',
    );
    await repository.updateTaskFields(
      recordId: 'record-resume',
      updatedAt: DateTime.parse('2026-05-29T00:00:01Z'),
      taskId: 'task-1',
      taskStatus: GenerationTaskStatus.pending.wireValue,
    );
    await repository.updatePipelineStatus(
      recordId: 'record-resume',
      status: GenerationRecordPipelineStatus.pollingTask,
      updatedAt: DateTime.parse('2026-05-29T00:00:02Z'),
    );

    final GenerationSubmissionService service = GenerationSubmissionService(
      uploadRepository: _FakeUploadRepository(),
      generationTaskRepository: taskRepository,
      feedbackRepository: _FakeFeedbackRepository(),
      generationRecordRepository: repository,
      originalFileStore: _FakeGenerationOriginalFileStore(),
      photoLibraryAssetStore: photoLibraryAssetStore,
      imageProcessor: _FakeGenerationImageProcessor(),
    );
    addTearDown(service.dispose);

    await Future.wait(<Future<void>>[
      service.resumeActiveRecords(),
      service.resumeActiveRecords(),
    ]);

    expect(taskRepository.fetchTaskIds, <String>['task-1']);
    expect(photoLibraryAssetStore.events, hasLength(1));
  });

  test('retry failed job resubmits from original image', () async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
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
    final String jobId = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single
        .id;
    await container
        .read(generationRecordRepositoryProvider)
        .updatePipelineStatus(
          recordId: jobId,
          status: GenerationRecordPipelineStatus.generationFailed,
          updatedAt: DateTime.now(),
          errorCode: 'network_error',
          errorMessage: 'Network failed',
        );

    await container
        .read(generationSubmissionControllerProvider.notifier)
        .retryJob(jobId);

    final GenerationSubmissionJob job = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single;
    expect(job.status, GenerationSubmissionStatus.pollingTask);
    expect(job.errorCode, isNull);
    expect(uploadRepository.events, <String>[
      'create:image/jpeg:4',
      'upload:upload-1:4',
      'complete:upload-1',
      'create:image/jpeg:4',
      'upload:upload-1:4',
      'complete:upload-1',
    ]);
    expect(taskRepository.createdInputs, hasLength(2));
  });

  test(
    'retry result processing failure reprocesses saved task result',
    () async {
      final _FakeGenerationTaskRepository taskRepository =
          _completedTaskRepository();
      final _FakeGenerationImageProcessor imageProcessor =
          _FakeGenerationImageProcessor();
      final _FakePhotoLibraryAssetStore photoLibraryAssetStore =
          _FakePhotoLibraryAssetStore();
      final ProviderContainer container = _container(
        imageProcessor: imageProcessor,
        photoLibraryAssetStore: photoLibraryAssetStore,
        taskRepository: taskRepository,
      );
      addTearDown(container.dispose);

      final String jobId = await _createSavedResultJob(container);
      await container
          .read(generationRecordRepositoryProvider)
          .updatePipelineStatus(
            recordId: jobId,
            status: GenerationRecordPipelineStatus.resultSaveFailed,
            updatedAt: DateTime.now(),
            errorCode: 'result_processing_failed',
            errorMessage: 'HEIF failed',
          );

      await container
          .read(generationSubmissionControllerProvider.notifier)
          .retryJob(jobId);

      final GenerationSubmissionJob job = container
          .read(generationSubmissionControllerProvider)
          .jobs
          .single;
      expect(job.status, GenerationSubmissionStatus.resultSaved);
      expect(taskRepository.createdInputs, hasLength(1));
      expect(taskRepository.resultUrlTaskIds, <String>['task-1', 'task-1']);
      expect(imageProcessor.processedResultUrls, hasLength(2));
      expect(photoLibraryAssetStore.events, hasLength(2));
    },
  );

  test(
    'favorite toggles iOS asset and submits first positive feedback',
    () async {
      final _FakePhotoLibraryAssetStore photoLibraryAssetStore =
          _FakePhotoLibraryAssetStore();
      final _FakeFeedbackRepository feedbackRepository =
          _FakeFeedbackRepository();
      final ProviderContainer container = _container(
        photoLibraryAssetStore: photoLibraryAssetStore,
        feedbackRepository: feedbackRepository,
        taskRepository: _completedTaskRepository(),
      );
      addTearDown(container.dispose);
      final String jobId = await _createSavedResultJob(container);
      final GenerationSubmissionController notifier = container.read(
        generationSubmissionControllerProvider.notifier,
      );

      await notifier.toggleResultFavorite(jobId);

      GenerationSubmissionJob job = container
          .read(generationSubmissionControllerProvider)
          .jobs
          .single;
      expect(job.isResultFavorite, isTrue);
      expect(
        photoLibraryAssetStore.events.last,
        'favorite:asset-result-1:true',
      );
      expect(feedbackRepository.inputs, hasLength(1));
      expect(feedbackRepository.inputs.single.taskId, 'task-1');
      expect(feedbackRepository.inputs.single.rating, FeedbackRating.positive);
      expect(feedbackRepository.inputs.single.tags, <String>['ios_favorite']);

      await notifier.toggleResultFavorite(jobId);

      job = container.read(generationSubmissionControllerProvider).jobs.single;
      expect(job.isResultFavorite, isFalse);
      expect(
        photoLibraryAssetStore.events.last,
        'favorite:asset-result-1:false',
      );
      expect(feedbackRepository.inputs, hasLength(1));

      await notifier.toggleResultFavorite(jobId);

      job = container.read(generationSubmissionControllerProvider).jobs.single;
      expect(job.isResultFavorite, isTrue);
      expect(feedbackRepository.inputs, hasLength(1));
    },
  );

  test('favorite failure keeps local state unchanged', () async {
    final _FakePhotoLibraryAssetStore photoLibraryAssetStore =
        _FakePhotoLibraryAssetStore();
    final ProviderContainer container = _container(
      photoLibraryAssetStore: photoLibraryAssetStore,
      taskRepository: _completedTaskRepository(),
    );
    addTearDown(container.dispose);
    final String jobId = await _createSavedResultJob(container);
    photoLibraryAssetStore.failure = StateError('favorite denied');

    await expectLater(
      container
          .read(generationSubmissionControllerProvider.notifier)
          .toggleResultFavorite(jobId),
      throwsStateError,
    );

    final GenerationSubmissionJob job = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single;
    expect(job.isResultFavorite, isFalse);
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

    final GenerationSubmissionJob job = await _waitForSingleJobStatus(
      container,
      GenerationSubmissionStatus.resultProcessingFailed,
    );
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

    final GenerationSubmissionJob job = await _waitForSingleJobStatus(
      container,
      GenerationSubmissionStatus.failed,
    );
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

  test('concurrent result url loads share one backend request', () async {
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..createResultUrlDelay = const Duration(milliseconds: 20);
    final ProviderContainer container = _container(
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);
    final GenerationSubmissionController notifier = container.read(
      generationSubmissionControllerProvider.notifier,
    );

    final String jobId = await notifier.queueGalleryFile(
      XFile('/tmp/photo.jpg'),
    );
    await container
        .read(generationRecordRepositoryProvider)
        .updateTaskFields(
          recordId: jobId,
          updatedAt: DateTime.now(),
          taskId: 'task-1',
          taskStatus: GenerationTaskStatus.completed.wireValue,
          resultImageObjectId: 'result-1',
        );
    await container
        .read(generationRecordRepositoryProvider)
        .updatePipelineStatus(
          recordId: jobId,
          status: GenerationRecordPipelineStatus.completed,
          updatedAt: DateTime.now(),
        );

    final List<String?> urls = await Future.wait(<Future<String?>>[
      notifier.loadResultUrl(jobId),
      notifier.loadResultUrl(jobId),
    ]);

    expect(urls, <String?>[
      'https://example.com/result-1.jpg',
      'https://example.com/result-1.jpg',
    ]);
    expect(taskRepository.resultUrlTaskIds, <String>['task-1']);
  });
}

Future<GenerationSubmissionJob> _waitForSingleJobStatus(
  ProviderContainer container,
  GenerationSubmissionStatus status, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final List<GenerationSubmissionJob> jobs = container
        .read(generationSubmissionControllerProvider)
        .jobs;
    if (jobs.length == 1 && jobs.single.status == status) {
      return jobs.single;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return container.read(generationSubmissionControllerProvider).jobs.single;
}

Future<String> _createSavedResultJob(ProviderContainer container) async {
  await container
      .read(generationSubmissionControllerProvider.notifier)
      .submitCapturedFile(XFile('/tmp/photo.jpg'));
  await Future<void>.delayed(Duration.zero);

  final String jobId = container
      .read(generationSubmissionControllerProvider)
      .jobs
      .single
      .id;

  GenerationSubmissionJob job = await _waitForSingleJobStatus(
    container,
    GenerationSubmissionStatus.resultSaved,
  );
  if (job.status != GenerationSubmissionStatus.resultSaved) {
    await container
        .read(generationSubmissionControllerProvider.notifier)
        .pollTaskNowForDebug(jobId);
    job = await _waitForSingleJobStatus(
      container,
      GenerationSubmissionStatus.resultSaved,
    );
  }
  expect(job.status, GenerationSubmissionStatus.resultSaved);
  return jobId;
}

_FakeGenerationTaskRepository _completedTaskRepository() {
  return _FakeGenerationTaskRepository()
    ..fetchTaskResponses.add(
      _task(
        status: GenerationTaskStatus.completed,
        resultImageObjectId: 'result-1',
      ),
    );
}

ProviderContainer _container({
  _FakePhotoLibraryAssetStore? photoLibraryAssetStore,
  _FakeGenerationImageProcessor? imageProcessor,
  _FakeUploadRepository? uploadRepository,
  _FakeGenerationTaskRepository? taskRepository,
  _FakeFeedbackRepository? feedbackRepository,
  _FakeGenerationOriginalFileStore? originalFileStore,
}) {
  final GenerationRecordDatabase database =
      GenerationRecordDatabase.forExecutor(NativeDatabase.memory());
  return ProviderContainer(
    overrides: <Override>[
      generationRecordDatabaseProvider.overrideWithValue(database),
      generationOriginalFileStoreProvider.overrideWithValue(
        originalFileStore ?? _FakeGenerationOriginalFileStore(),
      ),
      photoLibraryAssetStoreProvider.overrideWithValue(
        photoLibraryAssetStore ?? _FakePhotoLibraryAssetStore(),
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
      feedbackRepositoryProvider.overrideWithValue(
        feedbackRepository ?? _FakeFeedbackRepository(),
      ),
    ],
  );
}

class _FakeGenerationOriginalFileStore implements GenerationOriginalFileStore {
  final List<String> storedPaths = <String>[];
  final List<String> storedRelativePaths = <String>[];
  final List<String> deletedPaths = <String>[];
  Object? storeFailure;

  @override
  Future<StoredOriginalFile> storeCameraOriginal({
    required String recordId,
    required String sourcePath,
    required DateTime capturedAt,
  }) async {
    final Object? failure = storeFailure;
    if (failure != null) {
      throw failure;
    }
    final String storedPath = 'originals/2026/06/04/$recordId.heic';
    storedPaths.add('$sourcePath->$storedPath');
    storedRelativePaths.add(storedPath);
    return StoredOriginalFile(path: storedPath, format: 'heic');
  }

  @override
  Future<String> resolveOriginalPath(String path) async {
    if (path.startsWith('/')) {
      return path;
    }
    return '/resolved/$path';
  }

  @override
  Future<bool> originalExists(String path) async {
    return true;
  }

  @override
  Future<void> deleteOriginal(String path) async {
    deletedPaths.add(path);
  }
}

class _FakeGenerationImageProcessor implements GenerationImageProcessor {
  final List<String> preparedSourcePaths = <String>[];
  final List<String> processedResultUrls = <String>[];
  final List<Map<String, Object>> processedSourceExif = <Map<String, Object>>[];
  Object? prepareFailure;
  Object? processFailure;
  Duration prepareDelay = Duration.zero;

  @override
  Future<PreparedUploadImage> prepareUploadImage({
    required String jobId,
    required String sourcePath,
  }) async {
    preparedSourcePaths.add(sourcePath);
    if (prepareDelay > Duration.zero) {
      await Future<void>.delayed(prepareDelay);
    }
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

class _FakePhotoLibraryAssetStore implements PhotoLibraryAssetStore {
  final List<String> events = <String>[];
  final List<String> resolvedAssetIds = <String>[];
  Object? failure;
  String assetId = 'asset-result-1';

  @override
  Future<SavedPhotoLibraryImage> saveImage(
    String path, {
    required String album,
    required String fileName,
  }) async {
    events.add('save:$path:$album:$fileName');
    final Object? failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return SavedPhotoLibraryImage(assetId: assetId);
  }

  @override
  Future<SavedPhotoLibraryImage> saveImageToLibrary(
    String path, {
    required String fileName,
  }) async {
    events.add('save-library:$path:$fileName');
    final Object? failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return const SavedPhotoLibraryImage(assetId: 'asset-original-1');
  }

  @override
  Future<String?> resolveImagePath(String assetId) async {
    resolvedAssetIds.add(assetId);
    return '/photos/$assetId.heic';
  }

  @override
  Future<void> setFavorite(String assetId, {required bool isFavorite}) async {
    events.add('favorite:$assetId:$isFavorite');
    final Object? failure = this.failure;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<void> openPhotoLibrary() async {
    events.add('open-photo-library');
  }
}

class _FakeFeedbackRepository implements FeedbackRepository {
  final List<FeedbackInput> inputs = <FeedbackInput>[];
  Object? failure;

  @override
  Future<FeedbackSubmission> submitFeedback(FeedbackInput input) async {
    inputs.add(input);
    final Object? failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return FeedbackSubmission(
      id: 'feedback-${input.taskId}',
      taskId: input.taskId,
      rating: input.rating,
      improveOptIn: input.improveOptIn,
      createdAt: DateTime.parse('2026-05-29T00:00:00Z'),
    );
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
  final List<Object> resultUrlResponses = <Object>[];
  BackendApiFailure? createTaskFailure;
  Duration createResultUrlDelay = Duration.zero;
  Duration fetchTaskDelay = Duration.zero;

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
    if (createResultUrlDelay > Duration.zero) {
      await Future<void>.delayed(createResultUrlDelay);
    }
    if (resultUrlResponses.isNotEmpty) {
      final Object response = resultUrlResponses.removeAt(0);
      if (response is BackendApiFailure) {
        throw response;
      }
      return response as ResultUrl;
    }
    return const ResultUrl(
      url: 'https://example.com/result-1.jpg',
      expiresInSeconds: 600,
    );
  }

  @override
  Future<GenerationTask> fetchTask(String taskId) async {
    fetchTaskIds.add(taskId);
    if (fetchTaskDelay > Duration.zero) {
      await Future<void>.delayed(fetchTaskDelay);
    }
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
