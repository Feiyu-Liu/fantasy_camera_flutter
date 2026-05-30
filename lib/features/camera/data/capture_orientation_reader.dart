import 'package:flutter/services.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

abstract interface class CaptureOrientationReader {
  Future<DeviceOrientation> readCaptureOrientation({
    required DeviceOrientation fallback,
  });

  Stream<DeviceOrientation> watchCaptureOrientation({
    required DeviceOrientation initialOrientation,
  });
}

class NativeCaptureOrientationReader implements CaptureOrientationReader {
  NativeCaptureOrientationReader({
    NativeDeviceOrientationCommunicator? communicator,
  }) : _communicator = communicator ?? NativeDeviceOrientationCommunicator();

  final NativeDeviceOrientationCommunicator _communicator;

  @override
  Future<DeviceOrientation> readCaptureOrientation({
    required DeviceOrientation fallback,
  }) async {
    final NativeDeviceOrientation orientation = await _communicator.orientation(
      useSensor: true,
    );
    return mapNativeCaptureOrientation(orientation, fallback: fallback);
  }

  @override
  Stream<DeviceOrientation> watchCaptureOrientation({
    required DeviceOrientation initialOrientation,
  }) {
    return _communicator
        .onOrientationChanged(useSensor: true)
        .map(
          (NativeDeviceOrientation orientation) => mapNativeCaptureOrientation(
            orientation,
            fallback: initialOrientation,
          ),
        )
        .distinct();
  }
}

DeviceOrientation mapNativeCaptureOrientation(
  NativeDeviceOrientation orientation, {
  required DeviceOrientation fallback,
}) {
  return switch (orientation) {
    NativeDeviceOrientation.portraitUp => DeviceOrientation.portraitUp,
    NativeDeviceOrientation.portraitDown => DeviceOrientation.portraitDown,
    NativeDeviceOrientation.landscapeLeft => DeviceOrientation.landscapeLeft,
    NativeDeviceOrientation.landscapeRight => DeviceOrientation.landscapeRight,
    NativeDeviceOrientation.unknown => fallback,
  };
}

double captureOrientationTurns(DeviceOrientation orientation) {
  return switch (orientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 0.25,
    DeviceOrientation.portraitDown => 0.5,
    DeviceOrientation.landscapeRight => 0.75,
  };
}

double shortestQuarterTurnsToTarget({
  required double current,
  required double target,
}) {
  final double currentDegrees = current * 360;
  final double targetDegrees = target * 360;
  if (currentDegrees % 360 == targetDegrees % 360) {
    return current;
  }
  final bool clockwise = (targetDegrees - currentDegrees + 540) % 360 - 180 > 0;
  double resultDegrees = currentDegrees;
  do {
    resultDegrees += (clockwise ? 1 : -1) * 90;
  } while (resultDegrees % 360 != targetDegrees % 360);
  return resultDegrees / 360;
}
