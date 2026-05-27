import 'package:camera_avfoundation/camera_avfoundation.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:fantasy_camera_flutter/features/camera/data/camera_device_repository.dart';
import 'package:fantasy_camera_flutter/features/camera/domain/camera_choice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const CameraDeviceRepository repository = CameraDeviceRepository();

  group('CameraDeviceRepository', () {
    test('prefers rear virtual triple camera on startup', () {
      final CameraChoice front = _choice(
        name: 'front',
        direction: CameraLensDirection.front,
        deviceType: AVFoundationCaptureDeviceType.builtInTrueDepthCamera,
      );
      final CameraChoice rearWide = _choice(
        name: 'rear-wide',
        direction: CameraLensDirection.back,
        deviceType: AVFoundationCaptureDeviceType.builtInWideAngleCamera,
      );
      final CameraChoice rearTriple = _choice(
        name: 'rear-triple',
        direction: CameraLensDirection.back,
        isVirtualDevice: true,
        deviceType: AVFoundationCaptureDeviceType.builtInTripleCamera,
      );

      expect(
        repository.defaultStartupCameraChoice(<CameraChoice>[
          front,
          rearWide,
          rearTriple,
        ]),
        rearTriple,
      );
    });

    test('falls back to rear wide camera on startup', () {
      final CameraChoice front = _choice(
        name: 'front',
        direction: CameraLensDirection.front,
        deviceType: AVFoundationCaptureDeviceType.builtInTrueDepthCamera,
      );
      final CameraChoice rearWide = _choice(
        name: 'rear-wide',
        direction: CameraLensDirection.back,
        deviceType: AVFoundationCaptureDeviceType.builtInWideAngleCamera,
      );

      expect(
        repository.defaultStartupCameraChoice(<CameraChoice>[front, rearWide]),
        rearWide,
      );
    });

    test('selects opposite lens direction', () {
      final CameraChoice front = _choice(
        name: 'front',
        direction: CameraLensDirection.front,
        deviceType: AVFoundationCaptureDeviceType.builtInTrueDepthCamera,
      );
      final CameraChoice rear = _choice(
        name: 'rear',
        direction: CameraLensDirection.back,
      );

      expect(
        repository.oppositeLensCameraChoice(<CameraChoice>[
          rear,
          front,
        ], CameraLensDirection.back),
        front,
      );
      expect(
        repository.oppositeLensCameraChoice(<CameraChoice>[
          rear,
          front,
        ], CameraLensDirection.front),
        rear,
      );
    });
  });
}

CameraChoice _choice({
  required String name,
  required CameraLensDirection direction,
  bool isVirtualDevice = false,
  AVFoundationCaptureDeviceType deviceType =
      AVFoundationCaptureDeviceType.builtInWideAngleCamera,
}) {
  return CameraChoice(
    description: CameraDescription(
      name: name,
      lensDirection: direction,
      sensorOrientation: 90,
      lensType: CameraLensType.wide,
    ),
    label: name,
    isVirtualDevice: isVirtualDevice,
    deviceType: deviceType,
  );
}
