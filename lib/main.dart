import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';

import 'app/fantasy_camera_app.dart';
import 'features/camera/data/camera_device_repository.dart';
import 'features/camera/domain/camera_choice.dart';
import 'shared/core/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  List<CameraChoice> cameraChoices = <CameraChoice>[];
  try {
    cameraChoices = await const CameraDeviceRepository().loadCameraChoices();
  } on CameraException catch (e) {
    logAppError(e.code, e.description);
  }

  runApp(FantasyCameraApp(cameraChoices: cameraChoices));
}
