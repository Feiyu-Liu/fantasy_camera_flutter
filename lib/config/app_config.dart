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

  static const ResolutionPreset cameraPreviewResolutionPreset =
      ResolutionPreset.max;

  static const double cameraZoomRampRate = 8.0;

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
