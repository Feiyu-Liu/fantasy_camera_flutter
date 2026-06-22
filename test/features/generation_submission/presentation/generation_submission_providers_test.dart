import 'dart:typed_data';

import 'package:background_downloader/background_downloader.dart';
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
import 'package:fantasy_camera_flutter/features/generation_submission/application/background_r2_upload_service.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads built-in prompt styles and ignores unavailable capture modes',
    () {
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
      expect(state.values, <String, bool>{
        'recompose': true,
        'beautifyFace': true,
        'cleanFrame': true,
        'backgroundBlur': true,
      });
      expect(state.appInputContractId, isNull);

      notifier.selectCaptureMode('general');
      state = container.read(promptSelectionControllerProvider);
      expect(state.selectedCaptureModeId, 'portrait');
      expect(
        state.switches.map((PromptSwitchDefinition switchDefinition) {
          return switchDefinition.id;
        }),
        <String>['recompose', 'beautifyFace', 'cleanFrame', 'backgroundBlur'],
      );
      expect(state.snapshot.captureMode, 'portrait');

      notifier.selectPromptStyle('abstract');
      state = container.read(promptSelectionControllerProvider);
      expect(state.selectedPromptStyleId, 'realistic');
      expect(state.selectedCaptureModeId, 'portrait');
      expect(state.snapshot.promptStyle, 'realistic');
    },
  );

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
    expect(state.values['recompose'], isFalse);
  });

  test('submits captured file through the upload and task pipeline', () async {
    final _FakeGenerationImageProcessor imageProcessor =
        _FakeGenerationImageProcessor();
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..listTaskResponses.add(_task(status: GenerationTaskStatus.pending));
    final _FakeBackgroundR2UploadService backgroundR2UploadService =
        _FakeBackgroundR2UploadService();
    final ProviderContainer container = _container(
      imageProcessor: imageProcessor,
      uploadRepository: uploadRepository,
      taskRepository: taskRepository,
      backgroundR2UploadService: backgroundR2UploadService,
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
    expect(uploadRepository.events, <String>['create:image/jpeg:4']);
    expect(backgroundR2UploadService.events, hasLength(1));
    expect(
      backgroundR2UploadService.events.single,
      startsWith('background-upload:upload-1:'),
    );
    expect(backgroundR2UploadService.events.single, endsWith(':image/jpeg'));
    expect(taskRepository.createdInputs, isEmpty);
    expect(taskRepository.fetchTaskByUploadSessionIds, <String>['upload-1']);
    expect(taskRepository.listTaskLimits, isEmpty);
    expect(
      uploadRepository.generationRequests.single?.promptStyle,
      'realistic',
    );
    expect(uploadRepository.generationRequests.single?.captureMode, 'portrait');
    expect(
      uploadRepository.generationRequests.single?.userInput['switches'],
      <String, Object?>{
        'recompose': true,
        'beautifyFace': true,
        'cleanFrame': true,
        'backgroundBlur': true,
      },
    );
  });

  test('uses queued prompt snapshot when confirming a job', () async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..listTaskResponses.add(_task(status: GenerationTaskStatus.pending));
    final ProviderContainer container = _container(
      uploadRepository: uploadRepository,
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

    final CreateGenerationTaskInput input =
        uploadRepository.generationRequests.single!;
    expect(input.appInputContractId, 'contract-1');
    expect(input.userInput['switches'], <String, Object?>{
      'recompose': true,
      'beautifyFace': false,
      'cleanFrame': true,
      'backgroundBlur': false,
    });
  });

  test('submit captured file keeps provided prompt selection', () async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..listTaskResponses.add(_task(status: GenerationTaskStatus.pending));
    final ProviderContainer container = _container(
      uploadRepository: uploadRepository,
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);

    await container
        .read(generationSubmissionControllerProvider.notifier)
        .submitCapturedFile(
          XFile('/tmp/photo.jpg'),
          promptSelection: const PromptSelectionSnapshot(
            promptStyle: 'realistic',
            captureMode: 'portrait',
            switches: <String, bool>{},
          ),
        );

    final GenerationSubmissionJob job = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single;
    expect(job.status, GenerationSubmissionStatus.pollingTask);
    expect(
      uploadRepository.generationRequests.single?.promptStyle,
      'realistic',
    );
    expect(uploadRepository.generationRequests.single?.captureMode, 'portrait');
    expect(taskRepository.createdInputs, isEmpty);
  });

  test('concurrent confirms submit a job only once', () async {
    final _FakeGenerationImageProcessor imageProcessor =
        _FakeGenerationImageProcessor()
          ..prepareDelay = const Duration(milliseconds: 20);
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..listTaskResponses.add(_task(status: GenerationTaskStatus.pending));
    final _FakeBackgroundR2UploadService backgroundR2UploadService =
        _FakeBackgroundR2UploadService();
    final ProviderContainer container = _container(
      imageProcessor: imageProcessor,
      uploadRepository: uploadRepository,
      taskRepository: taskRepository,
      backgroundR2UploadService: backgroundR2UploadService,
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
    expect(uploadRepository.events, <String>['create:image/jpeg:4']);
    expect(backgroundR2UploadService.events, hasLength(1));
    expect(taskRepository.createdInputs, isEmpty);
    expect(taskRepository.fetchTaskByUploadSessionIds, <String>['upload-1']);
    expect(taskRepository.listTaskLimits, isEmpty);
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
            backgroundR2UploadService: _FakeBackgroundR2UploadService(),
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
            backgroundR2UploadService: _FakeBackgroundR2UploadService(),
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

  test('marks job failed when background upload fails', () async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeBackgroundR2UploadService backgroundR2UploadService =
        _FakeBackgroundR2UploadService()
          ..status = TaskStatus.failed
          ..responseStatusCode = 403
          ..responseBody = 'Signature mismatch';
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final ProviderContainer container = _container(
      uploadRepository: uploadRepository,
      taskRepository: taskRepository,
      backgroundR2UploadService: backgroundR2UploadService,
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
    expect(job.errorCode, 'upload_failed');
    expect(uploadRepository.events, <String>['create:image/jpeg:4']);
    expect(backgroundR2UploadService.events, hasLength(1));
    expect(
      backgroundR2UploadService.events.single,
      startsWith('background-upload:upload-1:'),
    );
    expect(backgroundR2UploadService.events.single, endsWith(':image/jpeg'));
    expect(taskRepository.createdInputs, isEmpty);
  });

  test('create upload network timeout stays recoverable and resumes', () async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository()
      ..createUploadFailures.add(
        const BackendApiFailure(
          code: 'network_timeout',
          message: 'Timed out while creating upload.',
        ),
      );
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final ProviderContainer container = _container(
      uploadRepository: uploadRepository,
      taskRepository: taskRepository,
    );
    addTearDown(container.dispose);

    final GenerationSubmissionController controller = container.read(
      generationSubmissionControllerProvider.notifier,
    );

    final String jobId = await controller.queueGalleryFile(
      XFile('/tmp/photo.jpg'),
    );
    await controller.confirmJob(jobId);

    GenerationSubmissionJob job = container
        .read(generationSubmissionControllerProvider)
        .jobs
        .single;
    expect(job.status, GenerationSubmissionStatus.creatingUpload);
    expect(job.errorCode, 'network_timeout');
    expect(uploadRepository.events, <String>['create:image/jpeg:4']);
    expect(taskRepository.fetchTaskByUploadSessionIds, isEmpty);

    await controller.resumeActiveRecords();

    job = container.read(generationSubmissionControllerProvider).jobs.single;
    expect(job.status, GenerationSubmissionStatus.pollingTask);
    expect(uploadRepository.events, <String>[
      'create:image/jpeg:4',
      'create:image/jpeg:4',
    ]);
    expect(taskRepository.fetchTaskByUploadSessionIds, <String>['upload-1']);
  });

  test('marks job failed when uploaded task recovery fails', () async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..fetchTaskByUploadSessionFailure = const BackendApiFailure(
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
    expect(uploadRepository.events, <String>['create:image/jpeg:4']);
    expect(taskRepository.fetchTaskByUploadSessionIds, <String>['upload-1']);
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
    expect(photoLibraryAssetStore.resolvedAssetIds, contains('asset-result-1'));
    final GenerationRecord? record = await container
        .read(generationRecordRepositoryProvider)
        .findById(jobId);
    expect(record?.resultAssetId, 'asset-result-1');
    expect(record?.resultLocalCachePath, isNull);
    expect(taskRepository.fetchTaskByUploadSessionIds, <String>['upload-1']);
    expect(taskRepository.fetchTaskIds, isEmpty);
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
      backgroundR2UploadService: _FakeBackgroundR2UploadService(),
    );
    addTearDown(service.dispose);

    await service.resumeActiveRecords();

    final GenerationRecord? record = await repository.findById('record-resume');
    expect(taskRepository.fetchTasksBatchRequests, <List<String>>[
      <String>['task-1'],
    ]);
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
      backgroundR2UploadService: _FakeBackgroundR2UploadService(),
    );
    addTearDown(service.dispose);

    await Future.wait(<Future<void>>[
      service.resumeActiveRecords(),
      service.resumeActiveRecords(),
    ]);

    expect(taskRepository.fetchTasksBatchRequests, <List<String>>[
      <String>['task-1'],
    ]);
    expect(photoLibraryAssetStore.events, hasLength(1));
  });

  test('resume active records polls multiple tasks in one batch', () async {
    final GenerationRecordDatabase database =
        GenerationRecordDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(database.close);
    final GenerationRecordRepository repository = GenerationRecordRepository(
      database,
    );
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..fetchTaskResponses.add(_task(status: GenerationTaskStatus.pending))
          ..fetchTaskResponses.add(
            _task(
              id: 'task-2',
              status: GenerationTaskStatus.failed,
              lastErrorCode: 'provider_error',
              lastErrorMessage: 'Provider failed',
            ),
          );

    for (final String recordId in <String>['record-1', 'record-2']) {
      await repository.createCameraRecord(
        recordId: recordId,
        originalLocalPath: 'originals/$recordId.heic',
        createdAt: DateTime.parse('2026-05-29T00:00:00Z'),
        promptStyle: 'realistic',
        captureMode: 'portrait',
      );
      final String taskId = recordId == 'record-1' ? 'task-1' : 'task-2';
      await repository.updateTaskFields(
        recordId: recordId,
        updatedAt: DateTime.parse('2026-05-29T00:00:01Z'),
        taskId: taskId,
        taskStatus: GenerationTaskStatus.pending.wireValue,
      );
      await repository.updatePipelineStatus(
        recordId: recordId,
        status: GenerationRecordPipelineStatus.pollingTask,
        updatedAt: DateTime.parse('2026-05-29T00:00:02Z'),
      );
    }

    final GenerationSubmissionService service = GenerationSubmissionService(
      uploadRepository: _FakeUploadRepository(),
      generationTaskRepository: taskRepository,
      feedbackRepository: _FakeFeedbackRepository(),
      generationRecordRepository: repository,
      originalFileStore: _FakeGenerationOriginalFileStore(),
      photoLibraryAssetStore: _FakePhotoLibraryAssetStore(),
      imageProcessor: _FakeGenerationImageProcessor(),
      backgroundR2UploadService: _FakeBackgroundR2UploadService(),
    );
    addTearDown(service.dispose);

    await service.resumeActiveRecords();

    expect(taskRepository.fetchTasksBatchRequests, <List<String>>[
      <String>['task-1', 'task-2'],
    ]);
    final GenerationRecord? record1 = await repository.findById('record-1');
    final GenerationRecord? record2 = await repository.findById('record-2');
    expect(
      record1?.pipelineStatus,
      GenerationRecordPipelineStatus.pollingTask.name,
    );
    expect(record1?.taskStatus, GenerationTaskStatus.pending.wireValue);
    expect(
      record2?.pipelineStatus,
      GenerationRecordPipelineStatus.generationFailed.name,
    );
    expect(record2?.taskStatus, GenerationTaskStatus.failed.wireValue);
    expect(record2?.errorCode, 'provider_error');
  });

  test('batch polling backend failure keeps records polling', () async {
    final GenerationRecordDatabase database =
        GenerationRecordDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(database.close);
    final GenerationRecordRepository repository = GenerationRecordRepository(
      database,
    );
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..fetchTasksBatchFailure = const BackendApiFailure(
            code: 'network_error',
            message: 'Network failed',
            statusCode: 503,
          );

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
      photoLibraryAssetStore: _FakePhotoLibraryAssetStore(),
      imageProcessor: _FakeGenerationImageProcessor(),
      backgroundR2UploadService: _FakeBackgroundR2UploadService(),
    );
    addTearDown(service.dispose);

    await service.resumeActiveRecords();

    final GenerationRecord? record = await repository.findById('record-resume');
    expect(taskRepository.fetchTasksBatchRequests, <List<String>>[
      <String>['task-1'],
    ]);
    expect(
      record?.pipelineStatus,
      GenerationRecordPipelineStatus.pollingTask.name,
    );
    expect(record?.errorCode, isNull);
  });

  test('uploaded task recovery failure marks record failed', () async {
    final GenerationRecordDatabase database =
        GenerationRecordDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(database.close);
    final GenerationRecordRepository repository = GenerationRecordRepository(
      database,
    );
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository()
          ..fetchTaskByUploadSessionFailure = const BackendApiFailure(
            code: 'upload_event_failed',
            message: 'No active prompt for requested route',
            statusCode: 409,
          );

    await repository.createCameraRecord(
      recordId: 'record-uploaded',
      originalLocalPath: 'originals/record-uploaded.heic',
      createdAt: DateTime.parse('2026-05-29T00:00:00Z'),
      promptStyle: 'realistic',
      captureMode: 'portrait',
    );
    await repository.updateUploadFields(
      recordId: 'record-uploaded',
      updatedAt: DateTime.parse('2026-05-29T00:00:01Z'),
      uploadSessionId: 'upload-1',
      sourceImageObjectId: 'source-1',
      uploadContentType: 'image/jpeg',
      uploadSizeBytes: 4,
    );
    await repository.updatePipelineStatus(
      recordId: 'record-uploaded',
      status: GenerationRecordPipelineStatus.uploadedWaitingTask,
      updatedAt: DateTime.parse('2026-05-29T00:00:02Z'),
    );

    final GenerationSubmissionService service = GenerationSubmissionService(
      uploadRepository: _FakeUploadRepository(),
      generationTaskRepository: taskRepository,
      feedbackRepository: _FakeFeedbackRepository(),
      generationRecordRepository: repository,
      originalFileStore: _FakeGenerationOriginalFileStore(),
      photoLibraryAssetStore: _FakePhotoLibraryAssetStore(),
      imageProcessor: _FakeGenerationImageProcessor(),
      backgroundR2UploadService: _FakeBackgroundR2UploadService(),
    );
    addTearDown(service.dispose);

    await service.resumeActiveRecords();

    final GenerationRecord? record = await repository.findById(
      'record-uploaded',
    );
    expect(taskRepository.fetchTaskByUploadSessionIds, <String>['upload-1']);
    expect(
      record?.pipelineStatus,
      GenerationRecordPipelineStatus.generationFailed.name,
    );
    expect(record?.errorCode, 'upload_event_failed');
    expect(record?.errorMessage, 'No active prompt for requested route');
  });

  test('resume uploading record recovers completed backend task', () async {
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
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakePhotoLibraryAssetStore photoLibraryAssetStore =
        _FakePhotoLibraryAssetStore();

    await repository.createCameraRecord(
      recordId: 'record-uploading',
      originalLocalPath: 'originals/record-uploading.heic',
      createdAt: DateTime.parse('2026-05-29T00:00:00Z'),
      promptStyle: 'realistic',
      captureMode: 'portrait',
    );
    await repository.updateUploadFields(
      recordId: 'record-uploading',
      updatedAt: DateTime.parse('2026-05-29T00:00:01Z'),
      uploadSessionId: 'upload-1',
      sourceImageObjectId: 'source-1',
      uploadContentType: 'image/jpeg',
      uploadSizeBytes: 4,
    );
    await repository.updatePipelineStatus(
      recordId: 'record-uploading',
      status: GenerationRecordPipelineStatus.uploading,
      updatedAt: DateTime.parse('2026-05-29T00:00:02Z'),
    );

    final GenerationSubmissionService service = GenerationSubmissionService(
      uploadRepository: uploadRepository,
      generationTaskRepository: taskRepository,
      feedbackRepository: _FakeFeedbackRepository(),
      generationRecordRepository: repository,
      originalFileStore: _FakeGenerationOriginalFileStore(),
      photoLibraryAssetStore: photoLibraryAssetStore,
      imageProcessor: _FakeGenerationImageProcessor(),
      backgroundR2UploadService: _FakeBackgroundR2UploadService(),
    );
    addTearDown(service.dispose);

    await service.resumeActiveRecords();

    final GenerationRecord? record = await repository.findById(
      'record-uploading',
    );
    expect(uploadRepository.events, isEmpty);
    expect(taskRepository.fetchTaskByUploadSessionIds, <String>['upload-1']);
    expect(
      record?.pipelineStatus,
      GenerationRecordPipelineStatus.resultSaved.name,
    );
    expect(record?.taskId, 'task-1');
    expect(record?.resultAssetId, 'asset-result-1');
    expect(photoLibraryAssetStore.events.single, contains('record-uploading'));
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
      'create:image/jpeg:4',
    ]);
    expect(taskRepository.createdInputs, isEmpty);
    expect(taskRepository.fetchTaskByUploadSessionIds, <String>[
      'upload-1',
      'upload-1',
    ]);
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
      expect(taskRepository.createdInputs, isEmpty);
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

  test(
    'result notification ignores already saved results on first read',
    () async {
      final ProviderContainer container = _container(
        taskRepository: _completedTaskRepository(),
      );
      addTearDown(container.dispose);

      await _createSavedResultJob(container);

      final GenerationResultNotificationState notificationState = container
          .read(generationResultNotificationControllerProvider);

      expect(notificationState.hasUnreadResult, isFalse);
      expect(notificationState.status, GenerationResultNotificationStatus.none);
    },
  );

  test('result notification marks newly saved result as success', () async {
    final ProviderContainer container = _container(
      taskRepository: _completedTaskRepository(),
    );
    addTearDown(container.dispose);

    expect(
      container
          .read(generationResultNotificationControllerProvider)
          .hasUnreadResult,
      isFalse,
    );
    expect(
      container.read(generationResultNotificationControllerProvider).status,
      GenerationResultNotificationStatus.none,
    );

    await _createSavedResultJob(container);

    expect(
      container
          .read(generationResultNotificationControllerProvider)
          .hasUnreadResult,
      isTrue,
    );
    expect(
      container.read(generationResultNotificationControllerProvider).status,
      GenerationResultNotificationStatus.success,
    );

    container
        .read(generationResultNotificationControllerProvider.notifier)
        .markAllSeen();

    expect(
      container
          .read(generationResultNotificationControllerProvider)
          .hasUnreadResult,
      isFalse,
    );
    expect(
      container.read(generationResultNotificationControllerProvider).status,
      GenerationResultNotificationStatus.none,
    );
  });

  test('result notification marks generation failure as failure', () async {
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

    expect(
      container.read(generationResultNotificationControllerProvider).status,
      GenerationResultNotificationStatus.none,
    );

    await container
        .read(generationSubmissionControllerProvider.notifier)
        .submitCapturedFile(XFile('/tmp/photo.jpg'));

    final GenerationSubmissionJob job = await _waitForSingleJobStatus(
      container,
      GenerationSubmissionStatus.failed,
    );

    expect(job.status, GenerationSubmissionStatus.failed);
    expect(
      container.read(generationResultNotificationControllerProvider).status,
      GenerationResultNotificationStatus.failure,
    );
  });

  test(
    'result notification marks result processing failure as failure',
    () async {
      final _FakeGenerationImageProcessor imageProcessor =
          _FakeGenerationImageProcessor()
            ..processFailure = StateError('heif unsupported');
      final ProviderContainer container = _container(
        imageProcessor: imageProcessor,
        taskRepository: _completedTaskRepository(),
      );
      addTearDown(container.dispose);

      expect(
        container.read(generationResultNotificationControllerProvider).status,
        GenerationResultNotificationStatus.none,
      );

      await container
          .read(generationSubmissionControllerProvider.notifier)
          .submitCapturedFile(XFile('/tmp/photo.jpg'));

      final GenerationSubmissionJob job = await _waitForSingleJobStatus(
        container,
        GenerationSubmissionStatus.resultProcessingFailed,
      );

      expect(job.status, GenerationSubmissionStatus.resultProcessingFailed);
      expect(
        container.read(generationResultNotificationControllerProvider).status,
        GenerationResultNotificationStatus.failure,
      );
    },
  );

  test('result notification prioritizes failure over success', () async {
    final ProviderContainer container = _container(
      taskRepository: _completedTaskRepository(),
    );
    addTearDown(container.dispose);

    expect(
      container.read(generationResultNotificationControllerProvider).status,
      GenerationResultNotificationStatus.none,
    );

    await _createSavedResultJob(container);
    expect(
      container.read(generationResultNotificationControllerProvider).status,
      GenerationResultNotificationStatus.success,
    );

    final _FakeGenerationTaskRepository taskRepository =
        container.read(generationTaskRepositoryProvider)
            as _FakeGenerationTaskRepository;
    taskRepository.fetchTaskResponses.add(
      _task(
        status: GenerationTaskStatus.failed,
        lastErrorCode: 'provider_error',
        lastErrorMessage: 'Provider failed',
      ),
    );

    await container
        .read(generationSubmissionControllerProvider.notifier)
        .submitCapturedFile(XFile('/tmp/failed-photo.jpg'));
    await _waitForJobStatus(
      container,
      GenerationSubmissionStatus.failed,
      expectedCount: 2,
    );

    expect(
      container.read(generationResultNotificationControllerProvider).status,
      GenerationResultNotificationStatus.failure,
    );
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

Future<List<GenerationSubmissionJob>> _waitForJobStatus(
  ProviderContainer container,
  GenerationSubmissionStatus status, {
  required int expectedCount,
  Duration timeout = const Duration(seconds: 3),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final List<GenerationSubmissionJob> jobs = container
        .read(generationSubmissionControllerProvider)
        .jobs;
    if (jobs.length == expectedCount &&
        jobs.any((GenerationSubmissionJob job) => job.status == status)) {
      return jobs;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return container.read(generationSubmissionControllerProvider).jobs;
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
  _FakeBackgroundR2UploadService? backgroundR2UploadService,
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
      backgroundR2UploadServiceProvider.overrideWithValue(
        backgroundR2UploadService ?? _FakeBackgroundR2UploadService(),
      ),
      generationSubmissionServiceProvider.overrideWith((Ref ref) {
        final GenerationSubmissionService service = GenerationSubmissionService(
          uploadRepository: ref.watch(uploadRepositoryProvider),
          generationTaskRepository: ref.watch(generationTaskRepositoryProvider),
          feedbackRepository: ref.watch(feedbackRepositoryProvider),
          generationRecordRepository: ref.watch(
            generationRecordRepositoryProvider,
          ),
          originalFileStore: ref.watch(generationOriginalFileStoreProvider),
          photoLibraryAssetStore: ref.watch(photoLibraryAssetStoreProvider),
          imageProcessor: ref.watch(generationImageProcessorProvider),
          backgroundR2UploadService: ref.watch(
            backgroundR2UploadServiceProvider,
          ),
          notificationDeviceCoordinator:
              const NoopNotificationDeviceCoordinator(),
        );
        ref.onDispose(service.dispose);
        return service;
      }),
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
  final List<CreateGenerationTaskInput?> generationRequests =
      <CreateGenerationTaskInput?>[];
  BackendApiFailure? createUploadFailure;
  final List<BackendApiFailure> createUploadFailures = <BackendApiFailure>[];
  BackendApiFailure? uploadFailure;
  BackendApiFailure? completeUploadFailure;

  @override
  Future<UploadSession> createUpload({
    required String contentType,
    required Uint8List bytes,
    CreateGenerationTaskInput? generationRequest,
  }) async {
    events.add('create:$contentType:${bytes.length}');
    generationRequests.add(generationRequest);
    if (createUploadFailures.isNotEmpty) {
      throw createUploadFailures.removeAt(0);
    }
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

class _FakeBackgroundR2UploadService implements BackgroundR2UploadService {
  final List<String> events = <String>[];
  TaskStatus status = TaskStatus.complete;
  int? responseStatusCode = 200;
  String? responseBody;
  Object? exception;

  @override
  Future<BackgroundR2UploadResult> uploadFile({
    required UploadSession uploadSession,
    required String filePath,
    required String contentType,
    required String displayName,
  }) async {
    events.add(
      'background-upload:${uploadSession.uploadSessionId}:$filePath:$contentType',
    );
    return BackgroundR2UploadResult(
      downloaderTaskId: 'downloader-1',
      status: status,
      responseStatusCode: responseStatusCode,
      responseBody: responseBody,
      exception: exception,
    );
  }

  @override
  void dispose() {}
}

class _FakeGenerationTaskRepository implements GenerationTaskRepository {
  final List<CreateGenerationTaskInput> createdInputs =
      <CreateGenerationTaskInput>[];
  final List<String> fetchTaskIds = <String>[];
  final List<String> fetchTaskByUploadSessionIds = <String>[];
  final List<List<String>> fetchTasksBatchRequests = <List<String>>[];
  final List<GenerationTask?> fetchTaskResponses = <GenerationTask?>[];
  final List<GenerationTask> listTaskResponses = <GenerationTask>[];
  final List<int> listTaskLimits = <int>[];
  final Set<String> missingTaskIds = <String>{};
  final List<String> resultUrlTaskIds = <String>[];
  final List<Object> resultUrlResponses = <Object>[];
  BackendApiFailure? createTaskFailure;
  BackendApiFailure? fetchTaskByUploadSessionFailure;
  BackendApiFailure? fetchTasksBatchFailure;
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
    return fetchTaskResponses.removeAt(0) ??
        _task(status: GenerationTaskStatus.pending);
  }

  @override
  Future<GenerationTask?> fetchTaskByUploadSession(
    String uploadSessionId,
  ) async {
    fetchTaskByUploadSessionIds.add(uploadSessionId);
    if (fetchTaskDelay > Duration.zero) {
      await Future<void>.delayed(fetchTaskDelay);
    }
    final BackendApiFailure? failure = fetchTaskByUploadSessionFailure;
    if (failure != null) {
      throw failure;
    }
    if (fetchTaskResponses.isEmpty) {
      return _task(status: GenerationTaskStatus.pending);
    }
    return fetchTaskResponses.removeAt(0);
  }

  @override
  Future<GenerationTasksBatchResult> fetchTasksBatch(
    List<String> taskIds,
  ) async {
    fetchTasksBatchRequests.add(taskIds.toList(growable: false));
    if (fetchTaskDelay > Duration.zero) {
      await Future<void>.delayed(fetchTaskDelay);
    }
    final BackendApiFailure? failure = fetchTasksBatchFailure;
    if (failure != null) {
      throw failure;
    }

    final List<GenerationTask> tasks = <GenerationTask>[];
    final List<String> missingIds = <String>[];
    for (final String taskId in taskIds) {
      if (missingTaskIds.contains(taskId)) {
        missingIds.add(taskId);
        continue;
      }
      final GenerationTask? response = fetchTaskResponses.isEmpty
          ? _task(status: GenerationTaskStatus.pending, id: taskId)
          : fetchTaskResponses.removeAt(0);
      final GenerationTask task =
          response ?? _task(status: GenerationTaskStatus.pending, id: taskId);
      tasks.add(task.id == taskId ? task : _taskFrom(task, id: taskId));
    }
    return GenerationTasksBatchResult(tasks: tasks, missingIds: missingIds);
  }

  @override
  Future<List<GenerationTask>> listTasks({int limit = 20}) async {
    listTaskLimits.add(limit);
    if (listTaskResponses.isEmpty) {
      return <GenerationTask>[_task(status: GenerationTaskStatus.pending)];
    }
    return listTaskResponses.toList(growable: false);
  }
}

final DateTime _fixedExpiresAt = DateTime.parse('2026-05-29T01:00:00Z');

GenerationTask _task({
  required GenerationTaskStatus status,
  String id = 'task-1',
  String? resultImageObjectId,
  String? lastErrorCode,
  String? lastErrorMessage,
}) {
  return GenerationTask(
    id: id,
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

GenerationTask _taskFrom(GenerationTask task, {required String id}) {
  return GenerationTask(
    id: id,
    status: task.status,
    promptStyle: task.promptStyle,
    captureMode: task.captureMode,
    sourceImageObjectId: task.sourceImageObjectId,
    resultImageObjectId: task.resultImageObjectId,
    costCredits: task.costCredits,
    attemptCount: task.attemptCount,
    maxAttempts: task.maxAttempts,
    lastErrorCode: task.lastErrorCode,
    lastErrorMessage: task.lastErrorMessage,
    createdAt: task.createdAt,
    completedAt: task.completedAt,
    failedAt: task.failedAt,
    canceledAt: task.canceledAt,
  );
}
