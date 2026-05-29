import 'package:camera_avfoundation/camera_avfoundation.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:fantasy_camera_flutter/features/camera/domain/camera_choice.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_message.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_providers.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_state.dart';
import 'package:fantasy_camera_flutter/l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
