import 'package:flutter/material.dart';

import '../features/camera/domain/camera_choice.dart';
import '../features/camera/presentation/camera_screen.dart';

class FantasyCameraApp extends StatelessWidget {
  const FantasyCameraApp({required this.cameraChoices, super.key});

  final List<CameraChoice> cameraChoices;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraScreen(cameraChoices: cameraChoices),
    );
  }
}
