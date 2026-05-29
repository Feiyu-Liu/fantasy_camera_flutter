import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/fantasy_camera_app.dart';
import 'config/app_config.dart';
import 'shared/core/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.hasSupabaseConfig) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabasePublishableKey,
      );
    } on Object catch (error, stackTrace) {
      logAppError('supabase_initialize_failed', error, stackTrace);
    }
  }

  runApp(const FantasyCameraApp());
}
