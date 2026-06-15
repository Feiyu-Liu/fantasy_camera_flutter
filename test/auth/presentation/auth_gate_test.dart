import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera_avfoundation/camera_avfoundation.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/credit_balance.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/feedback.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/generation_task.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/json_value.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/upload_session.dart';
import 'package:fantasy_camera_flutter/features/backend_api/presentation/backend_api_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_camera_flutter/app/fantasy_camera_app.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_session_state.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_user.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_page.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_providers.dart';
import 'package:fantasy_camera_flutter/features/camera/data/camera_device_repository.dart';
import 'package:fantasy_camera_flutter/features/camera/domain/camera_choice.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_providers.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_ui/camera_photo_ui.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/application/generation_submission_service.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_record_database.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_record_repository.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_image_processor.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_original_file_store.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_submission_adapters.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_record.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_record_providers.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_submission_providers.dart';
import 'package:fantasy_camera_flutter/features/notifications/presentation/notification_providers.dart';
import 'package:fantasy_camera_flutter/settings/application/app_settings.dart';
import 'package:fantasy_camera_flutter/settings/presentation/settings_page.dart';

void main() {
  Future<void> usePortraitSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('shows auth page when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(
      FantasyCameraApp(
        overrides: <Override>[
          hasSupabaseConfigProvider.overrideWithValue(true),
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.signedOut(),
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(AuthPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('auth_email_field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('auth_google_button')),
      findsOneWidget,
    );
  });

  testWidgets('shows camera screen when signed in', (
    WidgetTester tester,
  ) async {
    await usePortraitSurface(tester);
    await tester.pumpWidget(
      FantasyCameraApp(
        overrides: <Override>[
          hasSupabaseConfigProvider.overrideWithValue(true),
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.signedIn(
                AuthUser(id: 'user-1', email: 'user@example.com'),
              ),
            ),
          ),
          signedInCameraChoicesProvider.overrideWith(
            (_) async => const <CameraChoice>[],
          ),
          creditsRepositoryProvider.overrideWithValue(
            const _FakeCreditsRepository(),
          ),
          generationSubmissionServiceProvider.overrideWith((Ref ref) {
            final GenerationSubmissionService
            service = GenerationSubmissionService(
              uploadRepository: const _FakeUploadRepository(),
              generationTaskRepository: const _FakeGenerationTaskRepository(),
              feedbackRepository: const _FakeFeedbackRepository(),
              generationRecordRepository: GenerationRecordRepository(
                GenerationRecordDatabase.forExecutor(NativeDatabase.memory()),
              ),
              originalFileStore: const _FakeGenerationOriginalFileStore(),
              photoLibraryAssetStore: const _FakePhotoLibraryAssetStore(),
              imageProcessor: const _FakeGenerationImageProcessor(),
            );
            ref.onDispose(service.dispose);
            return service;
          }),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CameraPhotoUi), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('camera-prompt-option-recompose')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('camera-prompt-switch-list')),
      findsNothing,
    );
  });

  testWidgets('camera gallery thumbnail opens generation gallery page', (
    WidgetTester tester,
  ) async {
    await usePortraitSurface(tester);
    await tester.pumpWidget(
      FantasyCameraApp(
        overrides: <Override>[
          hasSupabaseConfigProvider.overrideWithValue(true),
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.signedIn(
                AuthUser(id: 'user-1', email: 'user@example.com'),
              ),
            ),
          ),
          signedInCameraChoicesProvider.overrideWith(
            (_) async => const <CameraChoice>[],
          ),
          creditsRepositoryProvider.overrideWithValue(
            const _FakeCreditsRepository(),
          ),
          generationSubmissionServiceProvider.overrideWith((Ref ref) {
            final GenerationSubmissionService
            service = GenerationSubmissionService(
              uploadRepository: const _FakeUploadRepository(),
              generationTaskRepository: const _FakeGenerationTaskRepository(),
              feedbackRepository: const _FakeFeedbackRepository(),
              generationRecordRepository: GenerationRecordRepository(
                GenerationRecordDatabase.forExecutor(NativeDatabase.memory()),
              ),
              originalFileStore: const _FakeGenerationOriginalFileStore(),
              photoLibraryAssetStore: const _FakePhotoLibraryAssetStore(),
              imageProcessor: const _FakeGenerationImageProcessor(),
            );
            ref.onDispose(service.dispose);
            return service;
          }),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('7'), findsOneWidget);
    expect(find.textContaining('积分'), findsNothing);
    expect(find.bySemanticsLabel('Switch UI'), findsNothing);

    await tester.tap(find.byType(CameraPhotoGalleryButton));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('generation-gallery-empty-hero')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-gallery-picker'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('camera top right settings button opens settings page', (
    WidgetTester tester,
  ) async {
    await usePortraitSurface(tester);
    await tester.pumpWidget(
      FantasyCameraApp(
        overrides: <Override>[
          hasSupabaseConfigProvider.overrideWithValue(true),
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.signedIn(
                AuthUser(id: 'user-1', email: 'user@example.com'),
              ),
            ),
          ),
          signedInCameraChoicesProvider.overrideWith(
            (_) async => const <CameraChoice>[],
          ),
          creditsRepositoryProvider.overrideWithValue(
            const _FakeCreditsRepository(),
          ),
          generationSubmissionServiceProvider.overrideWith((Ref ref) {
            final GenerationSubmissionService
            service = GenerationSubmissionService(
              uploadRepository: const _FakeUploadRepository(),
              generationTaskRepository: const _FakeGenerationTaskRepository(),
              feedbackRepository: const _FakeFeedbackRepository(),
              generationRecordRepository: GenerationRecordRepository(
                GenerationRecordDatabase.forExecutor(NativeDatabase.memory()),
              ),
              originalFileStore: const _FakeGenerationOriginalFileStore(),
              photoLibraryAssetStore: const _FakePhotoLibraryAssetStore(),
              imageProcessor: const _FakeGenerationImageProcessor(),
            );
            ref.onDispose(service.dispose);
            return service;
          }),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('camera-settings-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('settings state changes keep current route', (
    WidgetTester tester,
  ) async {
    await usePortraitSurface(tester);
    final _FakeAppSettingsRepository appSettingsRepository =
        _FakeAppSettingsRepository();
    await tester.pumpWidget(
      FantasyCameraApp(
        overrides: <Override>[
          hasSupabaseConfigProvider.overrideWithValue(true),
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.signedIn(
                AuthUser(id: 'user-1', email: 'user@example.com'),
              ),
            ),
          ),
          appSettingsRepositoryProvider.overrideWithValue(
            appSettingsRepository,
          ),
          notificationLifecycleProvider.overrideWith((Ref ref) {}),
          signedInCameraChoicesProvider.overrideWith(
            (_) async => const <CameraChoice>[],
          ),
          creditsRepositoryProvider.overrideWithValue(
            const _FakeCreditsRepository(),
          ),
          generationSubmissionServiceProvider.overrideWith((Ref ref) {
            final GenerationSubmissionService
            service = GenerationSubmissionService(
              uploadRepository: const _FakeUploadRepository(),
              generationTaskRepository: const _FakeGenerationTaskRepository(),
              feedbackRepository: const _FakeFeedbackRepository(),
              generationRecordRepository: GenerationRecordRepository(
                GenerationRecordDatabase.forExecutor(NativeDatabase.memory()),
              ),
              originalFileStore: const _FakeGenerationOriginalFileStore(),
              photoLibraryAssetStore: const _FakePhotoLibraryAssetStore(),
              imageProcessor: const _FakeGenerationImageProcessor(),
            );
            ref.onDispose(service.dispose);
            return service;
          }),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('camera-settings-button')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('settings-confirm-before-generation-switch'),
      ),
    );
    await tester.pumpAndSettle();

    expect(appSettingsRepository.confirmBeforeGenerationEnabled, isFalse);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('camera-settings-button')),
      findsNothing,
    );

    await tester.tap(find.text('语言切换'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(appSettingsRepository.localePreference, AppLocalePreference.en);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('camera-settings-button')),
      findsNothing,
    );
  });

  testWidgets('camera gallery thumbnail prefers latest saved result image', (
    WidgetTester tester,
  ) async {
    await usePortraitSurface(tester);
    final _SeededGenerationService seededGeneration =
        await _SeededGenerationService.create();
    addTearDown(seededGeneration.dispose);
    final String originalPath = _writeImageFile('camera-preview-original').path;
    final String resultPath = _writeImageFile('camera-preview-result').path;
    await seededGeneration.seedSavedResult(
      recordId: 'record-result',
      originalPath: originalPath,
      resultPath: resultPath,
    );
    final List<GenerationRecord> records = await seededGeneration.repository
        .listRecords();

    await tester.pumpWidget(
      FantasyCameraApp(
        overrides: <Override>[
          hasSupabaseConfigProvider.overrideWithValue(true),
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.signedIn(
                AuthUser(id: 'user-1', email: 'user@example.com'),
              ),
            ),
          ),
          signedInCameraChoicesProvider.overrideWith(
            (_) async => const <CameraChoice>[],
          ),
          creditsRepositoryProvider.overrideWithValue(
            const _FakeCreditsRepository(),
          ),
          generationRecordDatabaseProvider.overrideWithValue(
            seededGeneration.database,
          ),
          generationRecordsProvider.overrideWith((Ref ref) {
            return Stream<List<GenerationRecord>>.value(records);
          }),
          generationSubmissionServiceProvider.overrideWith((Ref ref) {
            return seededGeneration.service;
          }),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(ValueKey<String>('camera-gallery-preview-$resultPath')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('camera-gallery-preview-$originalPath')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('waits for camera choices before mounting camera screen', (
    WidgetTester tester,
  ) async {
    final Completer<List<CameraChoice>> cameraChoicesCompleter =
        Completer<List<CameraChoice>>();

    await tester.pumpWidget(
      FantasyCameraApp(
        overrides: <Override>[
          hasSupabaseConfigProvider.overrideWithValue(true),
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.signedIn(
                AuthUser(id: 'user-1', email: 'user@example.com'),
              ),
            ),
          ),
          signedInCameraChoicesProvider.overrideWith(
            (_) => cameraChoicesCompleter.future,
          ),
          creditsRepositoryProvider.overrideWithValue(
            const _FakeCreditsRepository(),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.byType(CameraPhotoUi), findsNothing);
    expect(find.text('No camera found.'), findsNothing);
  });

  testWidgets('mounts camera screen after camera choices load', (
    WidgetTester tester,
  ) async {
    await usePortraitSurface(tester);
    final Completer<List<CameraChoice>> cameraChoicesCompleter =
        Completer<List<CameraChoice>>();

    await tester.pumpWidget(
      FantasyCameraApp(
        overrides: <Override>[
          hasSupabaseConfigProvider.overrideWithValue(true),
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.signedIn(
                AuthUser(id: 'user-1', email: 'user@example.com'),
              ),
            ),
          ),
          signedInCameraChoicesProvider.overrideWith(
            (_) => cameraChoicesCompleter.future,
          ),
          creditsRepositoryProvider.overrideWithValue(
            const _FakeCreditsRepository(),
          ),
        ],
      ),
    );
    await tester.pump();

    cameraChoicesCompleter.complete(const <CameraChoice>[]);
    await tester.pump();

    expect(find.byType(CameraPhotoUi), findsOneWidget);
  });

  testWidgets('loads camera choices after auth restores to signed in', (
    WidgetTester tester,
  ) async {
    await usePortraitSurface(tester);
    final StreamController<AuthSessionState> authStates =
        StreamController<AuthSessionState>();
    addTearDown(authStates.close);
    final _FakeCameraDeviceRepository cameraDeviceRepository =
        _FakeCameraDeviceRepository();

    await tester.pumpWidget(
      FantasyCameraApp(
        overrides: <Override>[
          hasSupabaseConfigProvider.overrideWithValue(true),
          authSessionProvider.overrideWith((_) => authStates.stream),
          cameraDeviceRepositoryProvider.overrideWithValue(
            cameraDeviceRepository,
          ),
          creditsRepositoryProvider.overrideWithValue(
            const _FakeCreditsRepository(),
          ),
        ],
      ),
    );

    authStates.add(const AuthSessionState.restoring());
    await tester.pump();
    authStates.add(
      const AuthSessionState.signedIn(
        AuthUser(id: 'user-1', email: 'user@example.com'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(cameraDeviceRepository.loadCount, 1);
    expect(find.byType(CameraPhotoUi), findsOneWidget);
  });

  testWidgets('shows restoring loading state', (WidgetTester tester) async {
    await tester.pumpWidget(
      FantasyCameraApp(
        overrides: <Override>[
          hasSupabaseConfigProvider.overrideWithValue(true),
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.restoring(),
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });
}

class _FakeCameraDeviceRepository extends CameraDeviceRepository {
  _FakeCameraDeviceRepository();

  int loadCount = 0;

  @override
  Future<List<CameraChoice>> loadCameraChoices() async {
    loadCount += 1;
    return const <CameraChoice>[
      CameraChoice(
        description: CameraDescription(
          name: 'back-camera',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
          lensType: CameraLensType.wide,
        ),
        label: 'wide',
        isVirtualDevice: false,
        deviceType: AVFoundationCaptureDeviceType.builtInWideAngleCamera,
      ),
    ];
  }
}

class _FakeGenerationImageProcessor implements GenerationImageProcessor {
  const _FakeGenerationImageProcessor();

  @override
  Future<PreparedUploadImage> prepareUploadImage({
    required String jobId,
    required String sourcePath,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ProcessedResultImage> processResultImage({
    required String jobId,
    required String resultUrl,
    required Map<String, Object> sourceExif,
  }) {
    throw UnimplementedError();
  }
}

class _FakeCreditsRepository implements CreditsRepository {
  const _FakeCreditsRepository();

  @override
  Future<CreditBalance> fetchBalance() async {
    return CreditBalance(
      balance: 7,
      reservedBalance: 0,
      lifetimeEarned: 7,
      lifetimeSpent: 0,
      updatedAt: DateTime.parse('2026-05-29T00:00:00Z'),
    );
  }
}

class _FakeAppSettingsRepository implements AppSettingsRepository {
  bool confirmBeforeGenerationEnabled = true;
  AppLocalePreference localePreference = AppLocalePreference.zh;

  @override
  Future<AppSettingsState> loadSettings() async {
    return AppSettingsState(
      confirmBeforeGenerationEnabled: confirmBeforeGenerationEnabled,
      localePreference: localePreference,
    );
  }

  @override
  Future<void> saveConfirmBeforeGenerationEnabled(bool value) async {
    confirmBeforeGenerationEnabled = value;
  }

  @override
  Future<void> saveLocalePreference(AppLocalePreference preference) async {
    localePreference = preference;
  }
}

class _SeededGenerationService {
  _SeededGenerationService._({
    required this.database,
    required this.repository,
    required this.service,
  });

  final GenerationRecordDatabase database;
  final GenerationRecordRepository repository;
  final GenerationSubmissionService service;

  static Future<_SeededGenerationService> create() async {
    final GenerationRecordDatabase database =
        GenerationRecordDatabase.forExecutor(NativeDatabase.memory());
    final GenerationRecordRepository repository = GenerationRecordRepository(
      database,
    );
    final GenerationSubmissionService service = GenerationSubmissionService(
      uploadRepository: const _FakeUploadRepository(),
      generationTaskRepository: const _FakeGenerationTaskRepository(),
      feedbackRepository: const _FakeFeedbackRepository(),
      generationRecordRepository: repository,
      originalFileStore: const _FakeGenerationOriginalFileStore(),
      photoLibraryAssetStore: const _FakePhotoLibraryAssetStore(),
      imageProcessor: const _FakeGenerationImageProcessor(),
    );
    return _SeededGenerationService._(
      database: database,
      repository: repository,
      service: service,
    );
  }

  Future<void> seedSavedResult({
    required String recordId,
    required String originalPath,
    required String resultPath,
  }) async {
    final DateTime now = DateTime.parse('2026-05-29T00:00:00Z');
    await repository.createCameraRecord(
      recordId: recordId,
      originalLocalPath: originalPath,
      createdAt: now,
      promptStyle: 'realistic',
      captureMode: 'portrait',
    );
    _FakePhotoLibraryAssetStore.resultPaths['asset-result-$recordId'] =
        resultPath;
    await repository.updatePipelineStatus(
      recordId: recordId,
      status: GenerationRecordPipelineStatus.resultSaved,
      updatedAt: now,
    );
    await repository.updateResultFields(
      recordId: recordId,
      updatedAt: now,
      resultAvailability:
          GenerationRecordResultAvailability.savedToPhotoLibrary,
      resultAssetId: 'asset-result-$recordId',
    );
  }

  void dispose() {
    service.dispose();
    database.close();
  }
}

class _FakePhotoLibraryAssetStore implements PhotoLibraryAssetStore {
  const _FakePhotoLibraryAssetStore();

  static final Map<String, String> resultPaths = <String, String>{};

  @override
  Future<SavedPhotoLibraryImage> saveImage(
    String path, {
    required String album,
    required String fileName,
  }) async {
    return const SavedPhotoLibraryImage(assetId: 'asset-result-1');
  }

  @override
  Future<SavedPhotoLibraryImage> saveImageToLibrary(
    String path, {
    required String fileName,
  }) async {
    return const SavedPhotoLibraryImage(assetId: 'asset-original-1');
  }

  @override
  Future<String?> resolveImagePath(String assetId) async {
    return resultPaths[assetId];
  }

  @override
  Future<void> setFavorite(String assetId, {required bool isFavorite}) async {}

  @override
  Future<void> openPhotoLibrary() async {}
}

class _FakeFeedbackRepository implements FeedbackRepository {
  const _FakeFeedbackRepository();

  @override
  Future<FeedbackSubmission> submitFeedback(FeedbackInput input) async {
    return FeedbackSubmission(
      id: 'feedback-${input.taskId}',
      taskId: input.taskId,
      rating: input.rating,
      improveOptIn: input.improveOptIn,
      createdAt: DateTime.parse('2026-05-29T00:00:00Z'),
    );
  }
}

class _FakeGenerationOriginalFileStore implements GenerationOriginalFileStore {
  const _FakeGenerationOriginalFileStore();

  @override
  Future<void> deleteOriginal(String path) async {}

  @override
  Future<String> resolveOriginalPath(String path) async {
    return path;
  }

  @override
  Future<bool> originalExists(String path) async {
    return true;
  }

  @override
  Future<StoredOriginalFile> storeCameraOriginal({
    required String recordId,
    required String sourcePath,
    required DateTime capturedAt,
  }) async {
    return StoredOriginalFile(path: sourcePath, format: 'heic');
  }
}

class _FakeUploadRepository implements UploadRepository {
  const _FakeUploadRepository();

  @override
  Future<JsonObject> completeUpload(String uploadSessionId) {
    throw UnimplementedError();
  }

  @override
  Future<UploadSession> createUpload({
    required String contentType,
    required Uint8List bytes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> uploadBytes({
    required UploadSession uploadSession,
    required Uint8List bytes,
  }) {
    throw UnimplementedError();
  }
}

class _FakeGenerationTaskRepository implements GenerationTaskRepository {
  const _FakeGenerationTaskRepository();

  @override
  Future<GenerationTask> cancelTask(String taskId) {
    throw UnimplementedError();
  }

  @override
  Future<CreatedGenerationTask> createTask(CreateGenerationTaskInput input) {
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
