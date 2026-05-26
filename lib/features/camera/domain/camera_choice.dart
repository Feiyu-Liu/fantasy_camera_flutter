import 'package:camera_avfoundation/camera_avfoundation.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';

class CameraChoice {
  const CameraChoice({
    required this.description,
    required this.label,
    required this.isVirtualDevice,
    required this.deviceType,
  });

  final CameraDescription description;
  final String label;
  final bool isVirtualDevice;
  final AVFoundationCaptureDeviceType deviceType;
}
