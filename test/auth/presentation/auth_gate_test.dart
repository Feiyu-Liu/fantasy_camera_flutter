import 'dart:async';
import 'dart:typed_data';

import 'package:camera_avfoundation/camera_avfoundation.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/credit_balance.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/generation_task.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/json_value.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/upload_session.dart';
import 'package:fantasy_camera_flutter/features/backend_api/presentation/backend_api_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ui/my_ui.dart';

import 'package:fantasy_camera_flutter/app/fantasy_camera_app.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_session_state.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_user.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_page.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_providers.dart';
import 'package:fantasy_camera_flutter/features/camera/data/camera_device_repository.dart';
import 'package:fantasy_camera_flutter/features/camera/domain/camera_choice.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_providers.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/application/generation_submission_service.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_image_processor.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_submission_adapters.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_submission_providers.dart';

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
    expect(find.text('Sign in to continue'), findsOneWidget);
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

  testWidgets('camera gallery thumbnail opens generation debug modal', (
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
            final GenerationSubmissionService service =
                GenerationSubmissionService(
                  uploadRepository: const _FakeUploadRepository(),
                  generationTaskRepository:
                      const _FakeGenerationTaskRepository(),
                  photoLibrarySaver: const _FakePhotoLibrarySaver(),
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
      find.byKey(
        const ValueKey<String>('generation-submission-gallery-picker'),
      ),
      findsOneWidget,
    );
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

class _FakePhotoLibrarySaver implements PhotoLibrarySaver {
  const _FakePhotoLibrarySaver();

  @override
  Future<void> saveImage(String path, {required String album}) async {}
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
