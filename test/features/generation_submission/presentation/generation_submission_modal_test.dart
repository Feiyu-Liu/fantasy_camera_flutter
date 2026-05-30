import 'dart:io';
import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/json_value.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/generation_task.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/upload_session.dart';
import 'package:fantasy_camera_flutter/features/backend_api/presentation/backend_api_providers.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/application/generation_submission_service.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_image_processor.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_submission_adapters.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_submission_job.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_submission_modal.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_submission_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('modal shows captured photos with status icons', (
    WidgetTester tester,
  ) async {
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'awaiting',
        status: GenerationSubmissionStatus.awaitingConfirmation,
      ),
      _job(id: 'processing', status: GenerationSubmissionStatus.pollingTask),
      _job(id: 'completed', status: GenerationSubmissionStatus.completed),
      _job(id: 'failed', status: GenerationSubmissionStatus.failed),
    ];

    await tester.pumpWidget(_ModalHost(jobs: jobs));

    expect(
      find.byKey(const ValueKey<String>('generation-submission-photo-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-gallery-picker'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-status-awaiting'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-confirm-awaiting'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-cancel-awaiting'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-status-processing'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-status-completed'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('generation-submission-status-failed')),
      findsOneWidget,
    );
  });

  testWidgets('confirming awaiting photo starts generation', (
    WidgetTester tester,
  ) async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'awaiting',
        status: GenerationSubmissionStatus.awaitingConfirmation,
      ),
    ];

    await tester.pumpWidget(
      _ModalHost(
        jobs: jobs,
        uploadRepository: uploadRepository,
        taskRepository: taskRepository,
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('generation-submission-confirm-awaiting'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(uploadRepository.createUploadCount, 1);
    expect(taskRepository.createTaskCount, 1);
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-status-processing'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('canceling awaiting photo removes it from the list', (
    WidgetTester tester,
  ) async {
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'awaiting',
        status: GenerationSubmissionStatus.awaitingConfirmation,
      ),
    ];

    await tester.pumpWidget(
      _ModalHost(
        jobs: jobs,
        uploadRepository: uploadRepository,
        taskRepository: taskRepository,
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('generation-submission-cancel-awaiting'),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-photo-awaiting'),
      ),
      findsNothing,
    );
    expect(uploadRepository.createUploadCount, 0);
    expect(taskRepository.createTaskCount, 0);
  });

  testWidgets('modal shows gallery picker when no jobs exist', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _ModalHost(jobs: <GenerationSubmissionJob>[]),
    );

    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-gallery-picker'),
      ),
      findsOneWidget,
    );
    expect(find.text('No captured photos yet'), findsNothing);
  });

  testWidgets('tapping completed photo loads result image', (
    WidgetTester tester,
  ) async {
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(id: 'pending', status: GenerationSubmissionStatus.pollingTask),
      _job(
        id: 'done',
        status: GenerationSubmissionStatus.completed,
        taskId: 'task-done',
      ),
    ];

    await tester.pumpWidget(
      _ModalHost(jobs: jobs, taskRepository: taskRepository),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-photo-done')),
    );
    await tester.pump();
    await tester.pump();

    expect(taskRepository.resultUrlTaskIds, <String>['task-done']);
    expect(
      find.byKey(const ValueKey<String>('generation-submission-result-image')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('generation-submission-image-toggle')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-image-toggle')),
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-original-image'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('generation-submission-result-image')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('generation-submission-image-toggle')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('generation-submission-result-image')),
      findsOneWidget,
    );
  });

  testWidgets('saved result photo shows processed local image', (
    WidgetTester tester,
  ) async {
    final File processedFile = _writeImageFile('processed-result');
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'saved',
        status: GenerationSubmissionStatus.resultSaved,
        processedResultPath: processedFile.path,
      ),
    ];

    await tester.pumpWidget(_ModalHost(jobs: jobs));

    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-processed-result-image'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('result processing failure shows error message', (
    WidgetTester tester,
  ) async {
    final List<GenerationSubmissionJob> jobs = <GenerationSubmissionJob>[
      _job(
        id: 'failed-result',
        status: GenerationSubmissionStatus.resultProcessingFailed,
        resultSaveErrorMessage: 'HEIF conversion failed',
      ),
    ];

    await tester.pumpWidget(_ModalHost(jobs: jobs));

    expect(find.text('HEIF conversion failed'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>(
          'generation-submission-status-result-processing-failed',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping gallery picker queues selected image for confirmation', (
    WidgetTester tester,
  ) async {
    final File imageFile = _writeImageFile('gallery-picked');
    final _FakeGalleryImagePicker imagePicker = _FakeGalleryImagePicker(
      XFile(imageFile.path),
    );
    final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
    final _FakeGenerationTaskRepository taskRepository =
        _FakeGenerationTaskRepository();

    await tester.pumpWidget(
      _ModalHost(
        jobs: const <GenerationSubmissionJob>[],
        imagePicker: imagePicker,
        uploadRepository: uploadRepository,
        taskRepository: taskRepository,
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('generation-submission-gallery-picker'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(imagePicker.pickCount, 1);
    expect(
      find.byKey(const ValueKey<String>('generation-submission-photo-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-status-awaiting'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-status-processing'),
      ),
      findsNothing,
    );
    expect(uploadRepository.createUploadCount, 0);
    expect(taskRepository.createTaskCount, 0);
  });

  testWidgets('canceling gallery picker does not submit image', (
    WidgetTester tester,
  ) async {
    final _FakeGalleryImagePicker imagePicker = _FakeGalleryImagePicker(null);

    await tester.pumpWidget(
      _ModalHost(
        jobs: const <GenerationSubmissionJob>[],
        imagePicker: imagePicker,
        uploadRepository: _FakeUploadRepository(),
        taskRepository: _FakeGenerationTaskRepository(),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('generation-submission-gallery-picker'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(imagePicker.pickCount, 1);
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-status-processing'),
      ),
      findsNothing,
    );
  });
}

class _ModalHost extends StatelessWidget {
  const _ModalHost({
    required this.jobs,
    this.imagePicker,
    this.uploadRepository,
    this.taskRepository,
  });

  final List<GenerationSubmissionJob> jobs;
  final _FakeGalleryImagePicker? imagePicker;
  final _FakeUploadRepository? uploadRepository;
  final _FakeGenerationTaskRepository? taskRepository;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: <Override>[
        generationImageProcessorProvider.overrideWithValue(
          const _FakeGenerationImageProcessor(),
        ),
        galleryImagePickerProvider.overrideWithValue(
          imagePicker ?? _FakeGalleryImagePicker(null),
        ),
        uploadRepositoryProvider.overrideWithValue(
          uploadRepository ?? _FakeUploadRepository(),
        ),
        generationTaskRepositoryProvider.overrideWithValue(
          taskRepository ?? _FakeGenerationTaskRepository(),
        ),
        generationSubmissionServiceProvider.overrideWith((Ref ref) {
          final GenerationSubmissionService service =
              GenerationSubmissionService(
                initialState: GenerationSubmissionState(
                  jobs: ref.read(_seedJobsProvider),
                ),
                uploadRepository: uploadRepository ?? _FakeUploadRepository(),
                generationTaskRepository:
                    taskRepository ?? _FakeGenerationTaskRepository(),
                photoLibrarySaver: const _FakePhotoLibrarySaver(),
                imageProcessor: const _FakeGenerationImageProcessor(),
              );
          ref.onDispose(service.dispose);
          return service;
        }),
        _seedJobsProvider.overrideWithValue(jobs),
      ],
      child: CupertinoApp(
        home: CupertinoPageScaffold(
          child: const GenerationSubmissionDebugModal(),
        ),
      ),
    );
  }
}

final _seedJobsProvider = Provider<List<GenerationSubmissionJob>>((_) {
  return const <GenerationSubmissionJob>[];
});

class _FakeGenerationImageProcessor implements GenerationImageProcessor {
  const _FakeGenerationImageProcessor();

  @override
  Future<PreparedUploadImage> prepareUploadImage({
    required String jobId,
    required String sourcePath,
  }) async {
    return PreparedUploadImage(
      path: '$sourcePath.cleaned.jpg',
      bytes: Uint8List.fromList(<int>[1]),
      sourceExif: const <String, Object>{},
    );
  }

  @override
  Future<ProcessedResultImage> processResultImage({
    required String jobId,
    required String resultUrl,
    required Map<String, Object> sourceExif,
  }) async {
    return ProcessedResultImage(
      path: '/tmp/result.heic',
      bytes: Uint8List.fromList(<int>[1]),
    );
  }
}

class _FakeGalleryImagePicker implements GalleryImagePicker {
  _FakeGalleryImagePicker(this.result);

  final XFile? result;
  int pickCount = 0;

  @override
  Future<XFile?> pickImageFromGallery() async {
    pickCount += 1;
    return result;
  }
}

class _FakePhotoLibrarySaver implements PhotoLibrarySaver {
  const _FakePhotoLibrarySaver();

  @override
  Future<void> saveImage(String path, {required String album}) async {}
}

class _FakeUploadRepository implements UploadRepository {
  int createUploadCount = 0;

  @override
  Future<UploadSession> createUpload({
    required String contentType,
    required Uint8List bytes,
  }) async {
    createUploadCount += 1;
    return UploadSession(
      uploadSessionId: 'upload-1',
      sourceImageObjectId: 'source-1',
      provider: 'r2',
      bucket: 'fantasy-camera',
      expiresAt: DateTime.parse('2026-05-29T01:00:00Z'),
      requiredHeaders: const <String, String>{
        'content-type': 'image/jpeg',
        'content-length': '1',
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
  }) async {}

  @override
  Future<JsonObject> completeUpload(String uploadSessionId) async {
    return <String, Object?>{'id': uploadSessionId, 'status': 'uploaded'};
  }
}

class _FakeGenerationTaskRepository implements GenerationTaskRepository {
  final List<String> resultUrlTaskIds = <String>[];
  int createTaskCount = 0;

  @override
  Future<CreatedGenerationTask> createTask(
    CreateGenerationTaskInput input,
  ) async {
    createTaskCount += 1;
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
      url: 'https://example.com/result.jpg',
      expiresInSeconds: 600,
    );
  }

  @override
  Future<GenerationTask> fetchTask(String taskId) async {
    return GenerationTask(
      id: taskId,
      status: GenerationTaskStatus.pending,
      promptStyle: 'realistic',
      captureMode: 'portrait',
      sourceImageObjectId: 'source-1',
      costCredits: 2,
      attemptCount: 1,
      maxAttempts: 3,
      createdAt: DateTime.parse('2026-05-29T00:00:00Z'),
    );
  }

  @override
  Future<List<GenerationTask>> listTasks({int limit = 20}) {
    throw UnimplementedError();
  }
}

GenerationSubmissionJob _job({
  required String id,
  required GenerationSubmissionStatus status,
  String? taskId,
  String? processedResultPath,
  String? resultSaveErrorMessage,
}) {
  final DateTime now = DateTime.parse('2026-05-29T00:00:00Z');
  final File imageFile = _writeImageFile(id);
  return GenerationSubmissionJob(
    id: id,
    imagePath: imageFile.path,
    status: status,
    taskId: taskId ?? 'task-$id',
    processedResultPath: processedResultPath,
    resultSaveErrorMessage: resultSaveErrorMessage,
    createdAt: now,
    updatedAt: now,
  );
}

File _writeImageFile(String id) {
  final File imageFile = File('${Directory.systemTemp.path}/$id.jpg');
  if (!imageFile.existsSync()) {
    imageFile.writeAsBytesSync(_onePixelPng);
  }
  return imageFile;
}

final Uint8List _onePixelPng = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
