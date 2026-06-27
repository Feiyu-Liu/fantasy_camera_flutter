import 'dart:async';
import 'dart:math';

import 'package:camera_avfoundation/camera_avfoundation.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:fantasy_camera_flutter/config/app_config.dart';
import 'package:fantasy_camera_flutter/features/camera/data/capture_orientation_reader.dart';
import 'package:fantasy_camera_flutter/features/camera/domain/camera_choice.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/json_value.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_original_file_store.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_record_database.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_record_providers.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_submission_providers.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/feedback.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/generation_task.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/upload_session.dart';
import 'package:fantasy_camera_flutter/features/backend_api/presentation/backend_api_providers.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/application/background_r2_upload_service.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/application/generation_submission_service.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_image_processor.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_submission_adapters.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_submission_job.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_message.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_providers.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_screen.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_state.dart';
import 'package:fantasy_camera_flutter/l10n/l10n.dart';
import 'package:fantasy_camera_flutter/settings/application/app_settings.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CameraPlatform originalPlatform;

  setUp(() {
    originalPlatform = CameraPlatform.instance;
  });

  tearDown(() {
    CameraPlatform.instance = originalPlatform;
  });

  test('openDefaultCamera reports no camera when choices are empty', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[cameraChoicesProvider.overrideWithValue(const [])],
    );
    addTearDown(container.dispose);

    await container.read(cameraStateProvider.notifier).openDefaultCamera();

    final CameraMessage? message = container.read(cameraStateProvider).message;
    expect(message, isA<CameraNoCameraFoundMessage>());
    expect(
      message?.localize(appLocalizationsFor(defaultAppLocale)),
      appLocalizationsFor(defaultAppLocale).cameraNoCameraFound,
    );
  });

  test('displayZoomStopsFor builds display stops from AVFoundation nodes', () {
    final List<double> stops = displayZoomStopsFor(
      minRawZoom: 1.0,
      maxRawZoom: 6.0,
      displayZoomMultiplier: 0.5,
      capabilities: const AVFoundationZoomCapabilities(
        minZoomFactor: 1.0,
        maxZoomFactor: 6.0,
        recommendedMaxZoomFactor: null,
        currentZoomFactor: 2.0,
        displayZoomFactorMultiplier: 0.5,
        virtualDeviceSwitchOverZoomFactors: <double>[2.0],
        secondaryNativeResolutionZoomFactors: <double>[4.0],
        isVirtualDevice: true,
        constituentDevices: <AVFoundationPhysicalCameraDevice>[],
      ),
    );

    expect(stops, <double>[0.5, 1.0, 2.0]);
  });

  test('displayZoomStopsFor falls back to min and max stops', () {
    final List<double> stops = displayZoomStopsFor(
      minRawZoom: 1.0,
      maxRawZoom: 4.0,
      displayZoomMultiplier: 1.0,
    );

    expect(stops, <double>[1.0, 4.0]);
  });

  test(
    'displayZoomStopsFor does not expose hardware max as AVFoundation stop',
    () {
      final List<double> stops = displayZoomStopsFor(
        minRawZoom: 1.0,
        maxRawZoom: 189.0,
        displayZoomMultiplier: 1.0,
        capabilities: const AVFoundationZoomCapabilities(
          minZoomFactor: 1.0,
          maxZoomFactor: 189.0,
          recommendedMaxZoomFactor: null,
          currentZoomFactor: 1.0,
          displayZoomFactorMultiplier: 1.0,
          virtualDeviceSwitchOverZoomFactors: <double>[],
          secondaryNativeResolutionZoomFactors: <double>[],
          isVirtualDevice: false,
          constituentDevices: <AVFoundationPhysicalCameraDevice>[],
        ),
      );

      expect(stops, <double>[1.0]);
    },
  );

  test('CameraState identifies front camera zoom policy', () {
    const CameraState state = CameraState(
      selectedCameraChoice: CameraChoice(
        description: CameraDescription(
          name: 'front',
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 0,
        ),
        label: 'Front Camera',
        isVirtualDevice: false,
        deviceType: AVFoundationCaptureDeviceType.builtInWideAngleCamera,
      ),
    );

    expect(state.isFrontCamera, isTrue);
    expect(state.canScaleZoom, isFalse);
  });

  test('initialRawZoomFor defaults rear camera to display 1x', () {
    final double rawZoom = initialRawZoomFor(
      lensDirection: CameraLensDirection.back,
      minRawZoom: 1.0,
      maxRawZoom: 10.0,
      currentRawZoom: 1.0,
      displayZoomMultiplier: 0.5,
    );

    expect(rawZoom, 2.0);
  });

  test('initialRawZoomFor keeps front camera current zoom', () {
    final double rawZoom = initialRawZoomFor(
      lensDirection: CameraLensDirection.front,
      minRawZoom: 1.0,
      maxRawZoom: 189.0,
      currentRawZoom: 1.0,
      displayZoomMultiplier: 1.0,
    );

    expect(rawZoom, 1.0);
  });

  test('displayZoomMultiplierFor falls back when multiplier is zero', () {
    final double multiplier = displayZoomMultiplierFor(
      const AVFoundationZoomCapabilities(
        minZoomFactor: 1.0,
        maxZoomFactor: 4.0,
        recommendedMaxZoomFactor: null,
        currentZoomFactor: 1.0,
        displayZoomFactorMultiplier: 0,
        virtualDeviceSwitchOverZoomFactors: <double>[],
        secondaryNativeResolutionZoomFactors: <double>[],
        isVirtualDevice: false,
        constituentDevices: <AVFoundationPhysicalCameraDevice>[],
      ),
    );

    expect(multiplier, 1.0);
  });

  test('effectiveMaxRawZoomFor prefers system recommended max', () {
    final double maxZoom = effectiveMaxRawZoomFor(
      const AVFoundationZoomCapabilities(
        minZoomFactor: 1.0,
        maxZoomFactor: 90.0,
        recommendedMaxZoomFactor: 10.0,
        currentZoomFactor: 1.0,
        displayZoomFactorMultiplier: 1.0,
        virtualDeviceSwitchOverZoomFactors: <double>[],
        secondaryNativeResolutionZoomFactors: <double>[],
        isVirtualDevice: false,
        constituentDevices: <AVFoundationPhysicalCameraDevice>[],
      ),
    );

    expect(maxZoom, 10.0);
  });

  test('CameraPhotoDynamicRange maps to capture file formats', () {
    expect(
      CameraPhotoDynamicRange.sdr.imageFileFormat,
      ImageFileFormat.sdrHeif,
    );
    expect(CameraPhotoDynamicRange.hdr.imageFileFormat, ImageFileFormat.heif);
  });

  test('AppConfig exposes the configured photo dynamic range format', () {
    expect(
      AppConfig.cameraImageFileFormat,
      AppConfig.cameraPhotoDynamicRange.imageFileFormat,
    );
  });

  test(
    'AVFoundation photo capture event triggers overlay after native will-capture',
    () async {
      final _FakeAVFoundationCamera camera = _FakeAVFoundationCamera();
      CameraPlatform.instance = camera;
      final _TestContainer testContainer = _container(
        choices: const <CameraChoice>[
          CameraChoice(
            description: CameraDescription(
              name: 'back',
              lensDirection: CameraLensDirection.back,
              sensorOrientation: 0,
            ),
            label: 'Back Camera',
            isVirtualDevice: false,
            deviceType: AVFoundationCaptureDeviceType.builtInWideAngleCamera,
          ),
        ],
      );
      final ProviderContainer container = testContainer.container;
      addTearDown(() async {
        await testContainer.dispose();
        await Future<void>.delayed(Duration.zero);
      });
      final ProviderSubscription<CameraState> subscription = container.listen(
        cameraStateProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      final CameraControllerNotifier notifier = container.read(
        cameraStateProvider.notifier,
      );
      await notifier.openDefaultCamera();

      expect(container.read(cameraStateProvider).captureOverlayTrigger, 0);

      final Future<XFile?> takePictureFuture = notifier.takePicture();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(cameraStateProvider).captureOverlayTrigger, 0);

      camera.emitPhotoCaptureWillCapture();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(cameraStateProvider).captureOverlayTrigger, 1);

      camera.completeTakePicture();
      await takePictureFuture;
    },
  );

  test(
    'takePicture queues captured file when confirmation is enabled',
    () async {
      final _FakeAVFoundationCamera camera = _FakeAVFoundationCamera();
      CameraPlatform.instance = camera;
      final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
      final _FakeGenerationTaskRepository taskRepository =
          _FakeGenerationTaskRepository();
      final _TestContainer testContainer = _container(
        choices: const <CameraChoice>[
          CameraChoice(
            description: CameraDescription(
              name: 'back',
              lensDirection: CameraLensDirection.back,
              sensorOrientation: 0,
            ),
            label: 'Back Camera',
            isVirtualDevice: false,
            deviceType: AVFoundationCaptureDeviceType.builtInWideAngleCamera,
          ),
        ],
        appSettingsRepository: _FakeAppSettingsRepository(
          confirmBeforeGenerationEnabled: true,
        ),
        uploadRepository: uploadRepository,
        taskRepository: taskRepository,
      );
      final ProviderContainer container = testContainer.container;
      addTearDown(() async {
        await testContainer.dispose();
        await Future<void>.delayed(Duration.zero);
      });

      final CameraControllerNotifier notifier = container.read(
        cameraStateProvider.notifier,
      );
      await notifier.openDefaultCamera();

      final Future<XFile?> takePictureFuture = notifier.takePicture();
      camera.completeTakePicture();
      await takePictureFuture;

      final GenerationSubmissionJob job = container
          .read(generationSubmissionControllerProvider)
          .jobs
          .single;
      expect(job.status, GenerationSubmissionStatus.awaitingConfirmation);
      expect(uploadRepository.events, isEmpty);
      expect(taskRepository.createdInputs, isEmpty);
    },
  );

  test(
    'takePicture submits captured file when confirmation is disabled',
    () async {
      final _FakeAVFoundationCamera camera = _FakeAVFoundationCamera();
      CameraPlatform.instance = camera;
      final _FakeUploadRepository uploadRepository = _FakeUploadRepository();
      final _FakeGenerationImageProcessor imageProcessor =
          _FakeGenerationImageProcessor()
            ..prepareCompleter = Completer<PreparedUploadImage>();
      final _FakeGenerationTaskRepository taskRepository =
          _FakeGenerationTaskRepository();
      final _TestContainer testContainer = _container(
        choices: const <CameraChoice>[
          CameraChoice(
            description: CameraDescription(
              name: 'back',
              lensDirection: CameraLensDirection.back,
              sensorOrientation: 0,
            ),
            label: 'Back Camera',
            isVirtualDevice: false,
            deviceType: AVFoundationCaptureDeviceType.builtInWideAngleCamera,
          ),
        ],
        appSettingsRepository: _FakeAppSettingsRepository(
          confirmBeforeGenerationEnabled: false,
        ),
        imageProcessor: imageProcessor,
        uploadRepository: uploadRepository,
        taskRepository: taskRepository,
      );
      final ProviderContainer container = testContainer.container;
      addTearDown(() async {
        await testContainer.dispose();
        await Future<void>.delayed(Duration.zero);
      });

      final CameraControllerNotifier notifier = container.read(
        cameraStateProvider.notifier,
      );
      await notifier.openDefaultCamera();

      final Future<XFile?> takePictureFuture = notifier.takePicture();
      camera.completeTakePicture();
      await takePictureFuture;

      expect(container.read(cameraStateProvider).isTakingPicture, isFalse);
      GenerationSubmissionJob job = container
          .read(generationSubmissionControllerProvider)
          .jobs
          .single;
      expect(job.status, GenerationSubmissionStatus.awaitingConfirmation);
      expect(uploadRepository.events, isEmpty);

      await imageProcessor.prepareStarted;
      imageProcessor.completePrepare();
      await _pumpEventQueue();

      job = container.read(generationSubmissionControllerProvider).jobs.single;
      expect(job.status, GenerationSubmissionStatus.uploadedWaitingTask);
      expect(uploadRepository.events, <String>['create:image/jpeg:4']);
      expect(taskRepository.createdInputs, isEmpty);
    },
  );

  test('pauseCamera disposes current controller and clears state', () async {
    final _FakeAVFoundationCamera camera = _FakeAVFoundationCamera();
    CameraPlatform.instance = camera;
    final _TestContainer testContainer = _container(
      choices: const <CameraChoice>[
        CameraChoice(
          description: CameraDescription(
            name: 'back',
            lensDirection: CameraLensDirection.back,
            sensorOrientation: 0,
          ),
          label: 'Back Camera',
          isVirtualDevice: false,
          deviceType: AVFoundationCaptureDeviceType.builtInWideAngleCamera,
        ),
      ],
    );
    final ProviderContainer container = testContainer.container;
    addTearDown(() async {
      await testContainer.dispose();
      await Future<void>.delayed(Duration.zero);
    });

    final CameraControllerNotifier notifier = container.read(
      cameraStateProvider.notifier,
    );
    await notifier.openDefaultCamera();

    expect(container.read(cameraStateProvider).controller, isNotNull);

    await notifier.pauseCamera();

    final CameraState state = container.read(cameraStateProvider);
    expect(camera.disposeCount, 1);
    expect(state.controller, isNull);
    expect(state.isInitializing, isFalse);
    expect(state.isTakingPicture, isFalse);
    expect(state.isSwitchingCamera, isFalse);
    expect(state.isTogglingFlash, isFalse);
    expect(state.message, isA<CameraStartingMessage>());
  });

  test('camera can reopen after pauseCamera', () async {
    final _FakeAVFoundationCamera camera = _FakeAVFoundationCamera();
    CameraPlatform.instance = camera;
    final _TestContainer testContainer = _container(
      choices: const <CameraChoice>[
        CameraChoice(
          description: CameraDescription(
            name: 'back',
            lensDirection: CameraLensDirection.back,
            sensorOrientation: 0,
          ),
          label: 'Back Camera',
          isVirtualDevice: false,
          deviceType: AVFoundationCaptureDeviceType.builtInWideAngleCamera,
        ),
      ],
    );
    final ProviderContainer container = testContainer.container;
    addTearDown(() async {
      await testContainer.dispose();
      await Future<void>.delayed(Duration.zero);
    });

    final CameraControllerNotifier notifier = container.read(
      cameraStateProvider.notifier,
    );
    await notifier.openDefaultCamera();
    await notifier.pauseCamera();
    await notifier.openDefaultCamera();

    expect(camera.disposeCount, 1);
    expect(camera.createCameraCount, 2);
    expect(container.read(cameraStateProvider).controller, isNotNull);
    expect(
      container.read(cameraStateProvider).hasInitializedController,
      isTrue,
    );
  });

  test(
    'suspended lifecycle resume does not reopen camera while gallery is active',
    () async {
      final _FakeAVFoundationCamera camera = _FakeAVFoundationCamera();
      CameraPlatform.instance = camera;
      final _TestContainer testContainer = _container(
        choices: const <CameraChoice>[
          CameraChoice(
            description: CameraDescription(
              name: 'back',
              lensDirection: CameraLensDirection.back,
              sensorOrientation: 0,
            ),
            label: 'Back Camera',
            isVirtualDevice: false,
            deviceType: AVFoundationCaptureDeviceType.builtInWideAngleCamera,
          ),
        ],
      );
      final ProviderContainer container = testContainer.container;
      addTearDown(() async {
        await testContainer.dispose();
        await Future<void>.delayed(Duration.zero);
      });

      final CameraControllerNotifier notifier = container.read(
        cameraStateProvider.notifier,
      );
      await notifier.openDefaultCamera();
      notifier.suspendLifecycleCameraResume();
      await notifier.pauseCamera();

      await notifier.handleAppLifecycleState(AppLifecycleState.resumed);

      expect(camera.disposeCount, 1);
      expect(camera.createCameraCount, 1);
      expect(container.read(cameraStateProvider).controller, isNull);

      notifier.resumeLifecycleCameraResume();
      await notifier.handleAppLifecycleState(AppLifecycleState.resumed);

      expect(camera.createCameraCount, 2);
      expect(container.read(cameraStateProvider).controller, isNotNull);
    },
  );

  test(
    'focusAndExposeAt forwards supported focus and exposure point',
    () async {
      final _FakeAVFoundationCamera camera = _FakeAVFoundationCamera();
      CameraPlatform.instance = camera;
      final _TestContainer testContainer = _container(
        choices: const <CameraChoice>[
          CameraChoice(
            description: CameraDescription(
              name: 'back',
              lensDirection: CameraLensDirection.back,
              sensorOrientation: 0,
            ),
            label: 'Back Camera',
            isVirtualDevice: false,
            deviceType: AVFoundationCaptureDeviceType.builtInWideAngleCamera,
          ),
        ],
      );
      final ProviderContainer container = testContainer.container;
      addTearDown(() async {
        await testContainer.dispose();
        await Future<void>.delayed(Duration.zero);
      });

      final CameraControllerNotifier notifier = container.read(
        cameraStateProvider.notifier,
      );
      await notifier.openDefaultCamera();

      await notifier.focusAndExposeAt(const Point<double>(0.2, 0.8));

      expect(camera.focusPoint, const Point<double>(0.2, 0.8));
      expect(camera.exposurePoint, const Point<double>(0.2, 0.8));
    },
  );

  test('cameraPreviewPointForTap accounts for covered preview crop', () {
    final Point<double>? center = cameraPreviewPointForTap(
      tapPosition: const Offset(50, 100),
      containerSize: const Size(100, 200),
      previewSize: const Size(1920, 1080),
    );

    expect(center?.x, closeTo(0.5, 0.001));
    expect(center?.y, closeTo(0.5, 0.001));

    final Point<double>? leftEdge = cameraPreviewPointForTap(
      tapPosition: Offset.zero,
      containerSize: const Size(100, 200),
      previewSize: const Size(1920, 1080),
    );

    expect(leftEdge?.x, closeTo(0.056, 0.001));
    expect(leftEdge?.y, closeTo(0, 0.001));

    final Point<double>? croppedTop = cameraPreviewPointForTap(
      tapPosition: Offset.zero,
      containerSize: const Size(200, 100),
      previewSize: const Size(1920, 1080),
    );

    expect(croppedTop?.x, closeTo(0, 0.001));
    expect(croppedTop?.y, closeTo(0.359, 0.001));
  });
}

Future<void> _pumpEventQueue() async {
  for (int index = 0; index < 5; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

_TestContainer _container({
  required List<CameraChoice> choices,
  AppSettingsRepository? appSettingsRepository,
  GenerationImageProcessor? imageProcessor,
  UploadRepository? uploadRepository,
  GenerationTaskRepository? taskRepository,
}) {
  final GenerationRecordDatabase database =
      GenerationRecordDatabase.forExecutor(NativeDatabase.memory());
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      generationRecordDatabaseProvider.overrideWithValue(database),
      cameraChoicesProvider.overrideWithValue(choices),
      captureOrientationReaderProvider.overrideWithValue(
        const _FakeCaptureOrientationReader(),
      ),
      appSettingsRepositoryProvider.overrideWithValue(
        appSettingsRepository ?? _FakeAppSettingsRepository(),
      ),
      generationOriginalFileStoreProvider.overrideWithValue(
        const _FakeGenerationOriginalFileStore(),
      ),
      photoLibraryAssetStoreProvider.overrideWithValue(
        const _FakePhotoLibraryAssetStore(),
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
        const _FakeFeedbackRepository(),
      ),
      backgroundR2UploadServiceProvider.overrideWithValue(
        const _FakeBackgroundR2UploadService(),
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
  return _TestContainer(container: container, database: database);
}

class _TestContainer {
  const _TestContainer({required this.container, required this.database});

  final ProviderContainer container;
  final GenerationRecordDatabase database;

  Future<void> dispose() async {
    container.dispose();
    await database.close();
  }
}

class _FakeAVFoundationCamera extends AVFoundationCamera {
  final StreamController<DeviceOrientationChangedEvent>
  _deviceOrientationController =
      StreamController<DeviceOrientationChangedEvent>.broadcast();
  final StreamController<CameraInitializedEvent> _initializedController =
      StreamController<CameraInitializedEvent>.broadcast();
  final StreamController<AVFoundationPhotoCaptureWillCaptureEvent>
  _photoCaptureController =
      StreamController<AVFoundationPhotoCaptureWillCaptureEvent>.broadcast();
  final Completer<XFile> _takePictureCompleter = Completer<XFile>();
  Point<double>? focusPoint;
  Point<double>? exposurePoint;
  int createCameraCount = 0;
  int disposeCount = 0;

  static const int _cameraId = 0;

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings? mediaSettings,
  ) async {
    createCameraCount += 1;
    return _cameraId;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    _initializedController.add(
      CameraInitializedEvent(
        cameraId,
        1920,
        1080,
        ExposureMode.auto,
        true,
        FocusMode.auto,
        true,
      ),
    );
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) {
    return _initializedController.stream.where(
      (CameraInitializedEvent event) => event.cameraId == cameraId,
    );
  }

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() {
    return _deviceOrientationController.stream;
  }

  @override
  Future<void> lockCaptureOrientation(
    int cameraId,
    DeviceOrientation orientation,
  ) async {}

  @override
  Future<void> setImageFileFormat(int cameraId, ImageFileFormat format) async {}

  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1.0;

  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 4.0;

  @override
  Future<AVFoundationZoomCapabilities> getZoomCapabilities(int cameraId) async {
    return const AVFoundationZoomCapabilities(
      minZoomFactor: 1.0,
      maxZoomFactor: 4.0,
      recommendedMaxZoomFactor: 4.0,
      currentZoomFactor: 1.0,
      displayZoomFactorMultiplier: 1.0,
      virtualDeviceSwitchOverZoomFactors: <double>[],
      secondaryNativeResolutionZoomFactors: <double>[],
      isVirtualDevice: false,
      constituentDevices: <AVFoundationPhysicalCameraDevice>[],
    );
  }

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {}

  @override
  Future<void> setFocusPoint(int cameraId, Point<double>? point) async {
    focusPoint = point;
  }

  @override
  Future<void> setExposurePoint(int cameraId, Point<double>? point) async {
    exposurePoint = point;
  }

  @override
  Future<void> setPhotoCaptureOrientation(
    DeviceOrientation orientation,
  ) async {}

  @override
  Future<XFile> takePicture(int cameraId) {
    return _takePictureCompleter.future;
  }

  @override
  Stream<AVFoundationPhotoCaptureWillCaptureEvent> onPhotoCaptureWillCapture(
    int cameraId,
  ) {
    return _photoCaptureController.stream.where(
      (AVFoundationPhotoCaptureWillCaptureEvent event) =>
          event.cameraId == cameraId,
    );
  }

  void emitPhotoCaptureWillCapture() {
    _photoCaptureController.add(
      AVFoundationPhotoCaptureWillCaptureEvent(_cameraId),
    );
  }

  void completeTakePicture() {
    _takePictureCompleter.complete(XFile('/tmp/captured.heic'));
  }

  @override
  Future<void> dispose(int cameraId) async {
    disposeCount += 1;
  }
}

class _FakeCaptureOrientationReader implements CaptureOrientationReader {
  const _FakeCaptureOrientationReader();

  @override
  Future<DeviceOrientation> readCaptureOrientation({
    required DeviceOrientation fallback,
  }) async {
    return fallback;
  }

  @override
  Stream<DeviceOrientation> watchCaptureOrientation({
    required DeviceOrientation initialOrientation,
  }) {
    return Stream<DeviceOrientation>.value(initialOrientation);
  }
}

class _FakeAppSettingsRepository implements AppSettingsRepository {
  _FakeAppSettingsRepository({this.confirmBeforeGenerationEnabled = true});

  bool confirmBeforeGenerationEnabled;
  AppLocalePreference localePreference = AppLocalePreference.system;
  AppThemePreference themePreference = AppThemePreference.light;

  @override
  Future<AppSettingsState> loadSettings() async {
    return AppSettingsState(
      confirmBeforeGenerationEnabled: confirmBeforeGenerationEnabled,
      localePreference: localePreference,
      themePreference: themePreference,
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

  @override
  Future<void> saveThemePreference(AppThemePreference preference) async {
    themePreference = preference;
  }
}

class _FakePhotoLibraryAssetStore implements PhotoLibraryAssetStore {
  const _FakePhotoLibraryAssetStore();

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
    return null;
  }

  @override
  Future<void> setFavorite(String assetId, {required bool isFavorite}) async {}

  @override
  Future<void> openPhotoLibrary() async {}
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

  @override
  Future<StoredOriginalFile> storeGalleryOriginal({
    required String recordId,
    required String sourcePath,
    required DateTime importedAt,
  }) async {
    return storeCameraOriginal(
      recordId: recordId,
      sourcePath: sourcePath,
      capturedAt: importedAt,
    );
  }
}

class _FakeGenerationImageProcessor implements GenerationImageProcessor {
  final List<String> preparedSourcePaths = <String>[];
  Completer<PreparedUploadImage>? prepareCompleter;
  final Completer<void> _prepareStartedCompleter = Completer<void>();

  Future<void> get prepareStarted => _prepareStartedCompleter.future;

  @override
  Future<PreparedUploadImage> prepareUploadImage({
    required String jobId,
    required String sourcePath,
  }) async {
    preparedSourcePaths.add(sourcePath);
    if (!_prepareStartedCompleter.isCompleted) {
      _prepareStartedCompleter.complete();
    }
    final Completer<PreparedUploadImage>? completer = prepareCompleter;
    if (completer != null) {
      return completer.future;
    }
    return _preparedUploadImage(sourcePath);
  }

  void completePrepare() {
    final Completer<PreparedUploadImage>? completer = prepareCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }
    completer.complete(_preparedUploadImage(preparedSourcePaths.single));
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

PreparedUploadImage _preparedUploadImage(String sourcePath) {
  return PreparedUploadImage(
    path: '$sourcePath.cleaned.jpg',
    bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
    sourceExif: const <String, Object>{
      'DateTimeOriginal': '2026:05:29 00:00:00',
    },
  );
}

class _FakeUploadRepository implements UploadRepository {
  final List<String> events = <String>[];

  @override
  Future<UploadSession> createUpload({
    required String contentType,
    required Uint8List bytes,
    CreateGenerationTaskInput? generationRequest,
  }) async {
    events.add('create:$contentType:${bytes.length}');
    return UploadSession(
      uploadSessionId: 'upload-1',
      sourceImageObjectId: 'source-1',
      provider: 'r2',
      bucket: 'fantasy-camera',
      expiresAt: DateTime.parse('2026-05-29T00:10:00Z'),
      requiredHeaders: <String, String>{
        'content-type': 'image/jpeg',
        'content-length': '${bytes.length}',
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
  }

  @override
  Future<JsonObject> completeUpload(String uploadSessionId) async {
    events.add('complete:$uploadSessionId');
    return <String, Object?>{'id': uploadSessionId, 'status': 'uploaded'};
  }
}

class _FakeBackgroundR2UploadService implements BackgroundR2UploadService {
  const _FakeBackgroundR2UploadService();

  @override
  Future<BackgroundR2UploadResult> uploadFile({
    required UploadSession uploadSession,
    required String filePath,
    required String contentType,
    required String displayName,
  }) async {
    return const BackgroundR2UploadResult(
      downloaderTaskId: 'downloader-1',
      status: TaskStatus.complete,
      responseStatusCode: 200,
    );
  }

  @override
  void dispose() {}
}

class _FakeGenerationTaskRepository implements GenerationTaskRepository {
  final List<CreateGenerationTaskInput> createdInputs =
      <CreateGenerationTaskInput>[];

  @override
  Future<CreatedGenerationTask> createTask(
    CreateGenerationTaskInput input,
  ) async {
    createdInputs.add(input);
    return const CreatedGenerationTask(
      taskId: 'task-1',
      status: GenerationTaskStatus.pending,
      creditReservationId: 'reservation-1',
      costCredits: 2,
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
      maxAttempts: 1,
      createdAt: DateTime.parse('2026-05-29T00:00:00Z'),
    );
  }

  @override
  Future<GenerationTask?> fetchTaskByUploadSession(
    String uploadSessionId,
  ) async {
    return null;
  }

  @override
  Future<GenerationTasksBatchResult> fetchTasksBatch(
    List<String> taskIds,
  ) async {
    return GenerationTasksBatchResult(
      tasks: taskIds
          .map(
            (String taskId) => GenerationTask(
              id: taskId,
              status: GenerationTaskStatus.pending,
              promptStyle: 'realistic',
              captureMode: 'portrait',
              sourceImageObjectId: 'source-1',
              costCredits: 2,
              attemptCount: 1,
              maxAttempts: 1,
              createdAt: DateTime.parse('2026-05-29T00:00:00Z'),
            ),
          )
          .toList(growable: false),
      missingIds: const <String>[],
    );
  }

  @override
  Future<List<GenerationTask>> listTasks({int limit = 20}) async {
    return const <GenerationTask>[];
  }

  @override
  Future<GenerationTask> cancelTask(String taskId) {
    throw UnimplementedError();
  }

  @override
  Future<ResultUrl> createResultUrl(String taskId) {
    throw UnimplementedError();
  }
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
