import 'package:camera_platform_interface/camera_platform_interface.dart';

class AppConfig {
  const AppConfig._();

  static const ResolutionPreset cameraPreviewResolutionPreset =
      ResolutionPreset.max;

  static const double cameraZoomRampRate = 8.0;
}
