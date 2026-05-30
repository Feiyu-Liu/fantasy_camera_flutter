import 'package:camera_platform_interface/camera_platform_interface.dart';

class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static const String workerApiBaseUrl = String.fromEnvironment(
    'WORKER_API_BASE_URL',
  );

  // 相机采集会话分辨率。`max` 会让平台相机插件选择支持的最高非方形格式。
  static const ResolutionPreset cameraPreviewResolutionPreset =
      ResolutionPreset.max;

  // 相机初始化和图像流的图像数据格式偏好；这不是 `takePicture()` 最终保存的文件格式。
  static const ImageFormatGroup cameraImageFormatGroup = ImageFormatGroup.jpeg;

  // `takePicture()` 最终保存的照片文件格式。
  static const ImageFileFormat cameraImageFileFormat = ImageFileFormat.heif;

  // iOS AVFoundation 切换变焦档位时的动画变焦速度。
  static const double cameraZoomRampRate = 10.0;

  static const String generationPhotoAlbumName = 'TesserCam';

  static const int generationUploadImageMaxSide = 2048;

  static const int generationUploadJpegQuality = 90;

  static const int generationResultHeifQuality = 90;

  static const bool generationUploadKeepExif = false;

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
