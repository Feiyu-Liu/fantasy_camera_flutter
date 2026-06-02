import 'package:camera_platform_interface/camera_platform_interface.dart';

enum CameraPhotoDynamicRange {
  sdr,
  hdr;

  ImageFileFormat get imageFileFormat {
    return switch (this) {
      CameraPhotoDynamicRange.sdr => ImageFileFormat.sdrHeif,
      CameraPhotoDynamicRange.hdr => ImageFileFormat.heif,
    };
  }
}

class AppConfig {
  const AppConfig._();

  // Supabase 项目 URL。通过 `--dart-define=SUPABASE_URL=...` 注入。
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  // Supabase publishable key。仅用于客户端初始化，不应放入 service role key。
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  // Cloudflare Worker API base URL。通过 `--dart-define=WORKER_API_BASE_URL=...` 注入。
  static const String workerApiBaseUrl = String.fromEnvironment(
    'WORKER_API_BASE_URL',
  );

  // 相机采集会话分辨率。`max` 会让平台相机插件选择支持的最高非方形格式。
  static const ResolutionPreset cameraPreviewResolutionPreset =
      ResolutionPreset.max;

  // 相机初始化和图像流的图像数据格式偏好；这不是 `takePicture()` 最终保存的文件格式。
  static const ImageFormatGroup cameraImageFormatGroup = ImageFormatGroup.jpeg;

  // `takePicture()` 最终保存的照片动态范围。默认导出 SDR HEIF，避免保留 Apple HDR gain map。
  static const CameraPhotoDynamicRange cameraPhotoDynamicRange =
      CameraPhotoDynamicRange.sdr;

  static ImageFileFormat get cameraImageFileFormat =>
      cameraPhotoDynamicRange.imageFileFormat;

  // iOS AVFoundation 切换变焦档位时的动画变焦速度。
  static const double cameraZoomRampRate = 10.0;

  // 拍摄原图和最终生成图保存到系统相册时使用的相册名。
  static const String generationPhotoAlbumName = 'TesserCam';

  // 上传前清洗图片的最长边目标像素。保持比例缩放到 2K 水平。
  static const int generationUploadImageMaxSide = 2048;

  // 上传给生成服务的 JPEG 编码质量。
  static const int generationUploadJpegQuality = 100;

  // 生成结果转为 HEIF 后保存到系统相册的编码质量。
  static const int generationResultHeifQuality = 100;

  // 上传给生成服务的临时 JPEG 是否保留 EXIF。当前关闭以减少服务端解码不稳定因素。
  static const bool generationUploadKeepExif = false;

  // App 内置 prompt 配置版本。随生成请求写入 userInput，便于追踪生成任务使用的配置。
  static const String promptConfigVersion = 'app_bundled_2026_06_01';

  // Supabase 是否具备可用配置；用于决定认证模块是否初始化远端能力。
  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  // Worker API 是否具备可用配置；用于决定后端 API client 是否可发起请求。
  static bool get hasWorkerApiConfig => workerApiBaseUrl.isNotEmpty;
}
