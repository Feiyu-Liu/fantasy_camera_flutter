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

  // Google Sign-In iOS OAuth client ID. Inject with
  // `--dart-define=GOOGLE_IOS_CLIENT_ID=...`.
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  // Google Sign-In web OAuth client ID. This is used as the server client ID
  // so Google returns an ID token acceptable to Supabase.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  // Cloudflare Worker API base URL。通过 `--dart-define=WORKER_API_BASE_URL=...` 注入。
  static const String workerApiBaseUrl = String.fromEnvironment(
    'WORKER_API_BASE_URL',
  );

  // RevenueCat iOS public SDK key。客户端 public key 可见，但不能使用 secret API key。
  static const String revenueCatIosPublicSdkKey = String.fromEnvironment(
    'REVENUECAT_IOS_PUBLIC_SDK_KEY',
  );

  // RevenueCat 中用于积分包的 offering id。为空时使用 current offering。
  static const String revenueCatOfferingId = String.fromEnvironment(
    'REVENUECAT_OFFERING_ID',
    defaultValue: 'credits',
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

  // 相机 UI 中分割线和细边框的统一线宽。
  static const double cameraUiDividerWidth = 0.5;

  // 拍摄原图和最终生成图保存到系统相册时使用的相册名。
  static const String generationPhotoAlbumName = 'TesserCam';

  // App 外部网页链接。法律页面首版统一打开英文版，不随 App 语言切换。
  static const String appHomeUrl = 'https://tessercam.flyingfish.cc';
  static const String privacyPolicyUrl =
      'https://tessercam.flyingfish.cc/privacy-policy.html';
  static const String termsOfUseUrl =
      'https://tessercam.flyingfish.cc/terms-of-use.html';
  static const String developerEmail = 'liufeiyu135@gmail.com';
  static const String developerXUrl = 'https://x.com/tilapia638?s=11';
  static const String developerRedditUrl =
      'https://www.reddit.com/r/tessercam/';

  // Supabase 邮箱确认回调。该 URL 必须同时加入 Supabase Auth Redirect URLs。
  static const String authCallbackScheme = 'host.eunoia.tessercam';
  static const String authEmailRedirectUrl =
      '$authCallbackScheme://login-callback/';

  // APNs topic，必须与 iOS Bundle ID 以及 Worker 的 APNS_ALLOWED_TOPICS 对齐。
  static const String pushNotificationTopic = String.fromEnvironment(
    'PUSH_NOTIFICATION_TOPIC',
    defaultValue: 'host.eunoia.tessercam',
  );

  // 生成图保存到系统相册前使用的文件名规范。
  static const String generationResultFileNamePrefix = 'TesserCam';
  static const String generationResultFileExtension = 'heic';

  static String generationResultFileName(String recordId) {
    return '$generationResultFileNamePrefix-$recordId.'
        '$generationResultFileExtension';
  }

  // 用户手动保存原图到系统相册时使用的文件名规范。
  static const String generationOriginalFileNamePrefix = 'TesserCam-Original';

  static String generationOriginalFileName(String recordId, String path) {
    final String extension = _fileExtension(path, fallback: 'heic');
    return '$generationOriginalFileNamePrefix-$recordId.$extension';
  }

  static String _fileExtension(String path, {required String fallback}) {
    final int dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == path.length - 1) {
      return fallback;
    }
    return path.substring(dotIndex + 1).toLowerCase();
  }

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

  // MVP 阶段每次生成固定消耗 2 积分；与后端 active prompt cost_credits 对齐。
  static const int generationCostCredits = 2;

  // Supabase 是否具备可用配置；用于决定认证模块是否初始化远端能力。
  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static bool get hasGoogleSignInConfig =>
      googleIosClientId.isNotEmpty && googleWebClientId.isNotEmpty;

  // Worker API 是否具备可用配置；用于决定后端 API client 是否可发起请求。
  static bool get hasWorkerApiConfig => workerApiBaseUrl.isNotEmpty;

  static bool get hasRevenueCatIosConfig =>
      revenueCatIosPublicSdkKey.isNotEmpty;
}
