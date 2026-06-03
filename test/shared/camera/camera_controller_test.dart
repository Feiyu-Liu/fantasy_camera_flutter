import 'dart:async';
import 'dart:math';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:fantasy_camera_flutter/shared/camera/camera_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CameraPlatform originalPlatform;
  late _FakeCameraPlatform fakePlatform;

  setUp(() {
    originalPlatform = CameraPlatform.instance;
    fakePlatform = _FakeCameraPlatform();
    CameraPlatform.instance = fakePlatform;
  });

  tearDown(() {
    CameraPlatform.instance = originalPlatform;
  });

  test('lockCaptureOrientation defaults to portraitUp', () async {
    final CameraController controller = CameraController(
      const CameraDescription(
        name: 'back',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      ResolutionPreset.high,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    fakePlatform.emitDeviceOrientation(DeviceOrientation.landscapeLeft);

    await controller.lockCaptureOrientation();

    expect(fakePlatform.lockedOrientation, DeviceOrientation.portraitUp);
    expect(
      controller.value.lockedCaptureOrientation,
      DeviceOrientation.portraitUp,
    );
  });

  test('lockCaptureOrientation uses an explicit orientation', () async {
    final CameraController controller = CameraController(
      const CameraDescription(
        name: 'back',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      ResolutionPreset.high,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    await controller.lockCaptureOrientation(DeviceOrientation.portraitDown);

    expect(fakePlatform.lockedOrientation, DeviceOrientation.portraitDown);
    expect(
      controller.value.lockedCaptureOrientation,
      DeviceOrientation.portraitDown,
    );
  });

  test(
    'takePictureWithCaptureOrientation restores portrait capture lock',
    () async {
      final CameraController controller = CameraController(
        const CameraDescription(
          name: 'back',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
        ResolutionPreset.high,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.lockCaptureOrientation();

      final XFile file = await controller.takePictureWithCaptureOrientation(
        DeviceOrientation.landscapeLeft,
      );

      expect(file.path, '/tmp/captured.heic');
      expect(fakePlatform.events, <String>[
        'lock:portraitUp',
        'lock:landscapeLeft',
        'takePicture',
        'lock:portraitUp',
      ]);
      expect(
        controller.value.lockedCaptureOrientation,
        DeviceOrientation.portraitUp,
      );
    },
  );

  test('setFocusAndExposurePoint forwards supported points', () async {
    final CameraController controller = CameraController(
      const CameraDescription(
        name: 'back',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
      ResolutionPreset.high,
    );
    fakePlatform.focusPointSupported = true;
    fakePlatform.exposurePointSupported = true;
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.setFocusAndExposurePoint(const Point<double>(0.25, 0.75));

    expect(fakePlatform.focusPoint, const Point<double>(0.25, 0.75));
    expect(fakePlatform.exposurePoint, const Point<double>(0.25, 0.75));
  });
}

class _FakeCameraPlatform extends CameraPlatform {
  final StreamController<DeviceOrientationChangedEvent>
  _deviceOrientationController =
      StreamController<DeviceOrientationChangedEvent>.broadcast();
  final StreamController<CameraInitializedEvent> _initializedController =
      StreamController<CameraInitializedEvent>.broadcast();

  DeviceOrientation? lockedOrientation;
  int? lockedCameraId;
  Point<double>? focusPoint;
  Point<double>? exposurePoint;
  bool focusPointSupported = false;
  bool exposurePointSupported = false;
  final List<String> events = <String>[];

  void emitDeviceOrientation(DeviceOrientation orientation) {
    _deviceOrientationController.add(
      DeviceOrientationChangedEvent(orientation),
    );
  }

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    return 7;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    scheduleMicrotask(() {
      _initializedController.add(
        CameraInitializedEvent(
          7,
          1920,
          1080,
          ExposureMode.auto,
          exposurePointSupported,
          FocusMode.auto,
          focusPointSupported,
        ),
      );
    });
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) {
    return _initializedController.stream;
  }

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() {
    return _deviceOrientationController.stream;
  }

  @override
  Future<void> lockCaptureOrientation(
    int cameraId,
    DeviceOrientation orientation,
  ) async {
    lockedCameraId = cameraId;
    lockedOrientation = orientation;
    events.add('lock:${orientation.name}');
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    events.add('takePicture');
    return XFile('/tmp/captured.heic');
  }

  @override
  Future<void> setFocusPoint(int cameraId, Point<double>? point) async {
    focusPoint = point;
  }

  @override
  Future<void> setExposurePoint(int cameraId, Point<double>? point) async {
    exposurePoint = point;
  }

  @override
  Future<void> dispose(int cameraId) async {
    await _deviceOrientationController.close();
    await _initializedController.close();
  }
}
