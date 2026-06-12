import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/fantasy_camera_app.dart';
import 'config/app_config.dart';
import 'shared/core/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: <SystemUiOverlay>[SystemUiOverlay.bottom],
  );
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  if (AppConfig.hasSupabaseConfig) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabasePublishableKey,
      );
    } on Object catch (error, stackTrace) {
      logAppError('supabase_initialize_failed', error, stackTrace);
    }
  }

  runApp(const FantasyCameraApp());
}
