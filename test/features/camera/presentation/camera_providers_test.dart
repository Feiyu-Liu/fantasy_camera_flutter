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
import 'package:fantasy_camera_flutter/features/backend_api/domain/generation_task.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/upload_session.dart';
import 'package:fantasy_camera_flutter/features/backend_api/presentation/backend_api_providers.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_image_processor.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_submission_adapters.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_message.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_providers.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_screen.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_state.dart';
import 'package:fantasy_camera_flutter/l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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

_TestContainer _container({required List<CameraChoice> choices}) {
  final GenerationRecordDatabase database =
      GenerationRecordDatabase.forExecutor(NativeDatabase.memory());
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      generationRecordDatabaseProvider.overrideWithValue(database),
      cameraChoicesProvider.overrideWithValue(choices),
      captureOrientationReaderProvider.overrideWithValue(
        const _FakeCaptureOrientationReader(),
      ),
      generationOriginalFileStoreProvider.overrideWithValue(
        const _FakeGenerationOriginalFileStore(),
      ),
      photoLibraryAssetStoreProvider.overrideWithValue(
        const _FakePhotoLibraryAssetStore(),
      ),
      generationImageProcessorProvider.overrideWithValue(
        const _FakeGenerationImageProcessor(),
      ),
      uploadRepositoryProvider.overrideWithValue(const _FakeUploadRepository()),
      generationTaskRepositoryProvider.overrideWithValue(
        const _FakeGenerationTaskRepository(),
      ),
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
  Future<String?> resolveImagePath(String assetId) async {
    return null;
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

class _FakeUploadRepository implements UploadRepository {
  const _FakeUploadRepository();

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

  @override
  Future<JsonObject> completeUpload(String uploadSessionId) {
    throw UnimplementedError();
  }
}

class _FakeGenerationTaskRepository implements GenerationTaskRepository {
  const _FakeGenerationTaskRepository();

  @override
  Future<CreatedGenerationTask> createTask(CreateGenerationTaskInput input) {
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

  @override
  Future<GenerationTask> cancelTask(String taskId) {
    throw UnimplementedError();
  }

  @override
  Future<ResultUrl> createResultUrl(String taskId) {
    throw UnimplementedError();
  }
}
