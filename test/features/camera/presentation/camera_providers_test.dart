import 'package:camera_avfoundation/camera_avfoundation.dart';
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

  test('displayZoomMultiplierFor falls back when multiplier is zero', () {
    final double multiplier = displayZoomMultiplierFor(
      const AVFoundationZoomCapabilities(
        minZoomFactor: 1.0,
        maxZoomFactor: 4.0,
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
}
