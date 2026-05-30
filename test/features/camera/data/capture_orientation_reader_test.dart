import 'package:fantasy_camera_flutter/features/camera/data/capture_orientation_reader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

void main() {
  test('maps native physical orientation to Flutter device orientation', () {
    expect(
      mapNativeCaptureOrientation(
        NativeDeviceOrientation.portraitUp,
        fallback: DeviceOrientation.landscapeLeft,
      ),
      DeviceOrientation.portraitUp,
    );
    expect(
      mapNativeCaptureOrientation(
        NativeDeviceOrientation.portraitDown,
        fallback: DeviceOrientation.landscapeLeft,
      ),
      DeviceOrientation.portraitDown,
    );
    expect(
      mapNativeCaptureOrientation(
        NativeDeviceOrientation.landscapeLeft,
        fallback: DeviceOrientation.portraitUp,
      ),
      DeviceOrientation.landscapeLeft,
    );
    expect(
      mapNativeCaptureOrientation(
        NativeDeviceOrientation.landscapeRight,
        fallback: DeviceOrientation.portraitUp,
      ),
      DeviceOrientation.landscapeRight,
    );
    expect(
      mapNativeCaptureOrientation(
        NativeDeviceOrientation.unknown,
        fallback: DeviceOrientation.landscapeRight,
      ),
      DeviceOrientation.landscapeRight,
    );
  });

  test('maps capture orientation to UI control turns', () {
    expect(captureOrientationTurns(DeviceOrientation.portraitUp), 0);
    expect(captureOrientationTurns(DeviceOrientation.landscapeLeft), 0.25);
    expect(captureOrientationTurns(DeviceOrientation.portraitDown), 0.5);
    expect(captureOrientationTurns(DeviceOrientation.landscapeRight), 0.75);
  });

  test('shortestQuarterTurnsToTarget uses the shortest path', () {
    expect(shortestQuarterTurnsToTarget(current: 0.75, target: 0), 1.0);
    expect(shortestQuarterTurnsToTarget(current: 0, target: 0.75), -0.25);
    expect(shortestQuarterTurnsToTarget(current: 0.25, target: 0.75), -0.25);
    expect(shortestQuarterTurnsToTarget(current: 0.5, target: 0.5), 0.5);
  });
}
