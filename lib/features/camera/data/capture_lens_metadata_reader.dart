import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';

abstract interface class CameraLensMetadataReader {
  Future<double?> readNominalFocalLength35mm({
    required String cameraName,
    required CameraLensDirection lensDirection,
  });
}

class NativeCameraLensMetadataReader implements CameraLensMetadataReader {
  const NativeCameraLensMetadataReader();

  static const MethodChannel _channel = MethodChannel(
    'fantasy_camera/capture_lens_metadata',
  );

  @override
  Future<double?> readNominalFocalLength35mm({
    required String cameraName,
    required CameraLensDirection lensDirection,
  }) async {
    final Object? value;
    try {
      value = await _channel.invokeMethod<Object?>(
        'readNominalFocalLength35mm',
        <String, Object?>{
          'cameraName': cameraName,
          'lensDirection': _lensDirectionName(lensDirection),
        },
      );
    } on MissingPluginException {
      return null;
    }
    return switch (value) {
      final int number => number.toDouble(),
      final double number => number,
      _ => null,
    };
  }
}

String _lensDirectionName(CameraLensDirection lensDirection) {
  return switch (lensDirection) {
    CameraLensDirection.front => 'front',
    CameraLensDirection.back => 'back',
    CameraLensDirection.external => 'external',
  };
}
