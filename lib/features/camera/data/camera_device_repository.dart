import 'package:camera_avfoundation/camera_avfoundation.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';

import '../domain/camera_choice.dart';

class CameraDeviceRepository {
  const CameraDeviceRepository();

  Future<List<CameraChoice>> loadCameraChoices() async {
    final CameraPlatform platform = CameraPlatform.instance;
    if (platform is AVFoundationCamera) {
      final List<AVFoundationCameraDevice> devices = await platform
          .getAvailableCameraDevices();
      if (devices.isNotEmpty) {
        devices.sort(_compareAVFoundationCameraDevices);
        return devices.map((AVFoundationCameraDevice device) {
          return CameraChoice(
            description: device.toCameraDescription(),
            label: _avFoundationCameraDeviceLabel(device),
            isVirtualDevice: device.isVirtualDevice,
            deviceType: device.deviceType,
          );
        }).toList();
      }
    }

    final List<CameraDescription> cameras = await platform.availableCameras();
    return cameras.map((CameraDescription description) {
      return CameraChoice(
        description: description,
        label: description.lensType.name,
        isVirtualDevice: false,
        deviceType: _deviceTypeForLensType(description.lensType),
      );
    }).toList();
  }

  CameraChoice? defaultStartupCameraChoice(List<CameraChoice> choices) {
    const List<AVFoundationCaptureDeviceType> virtualPriority =
        <AVFoundationCaptureDeviceType>[
          AVFoundationCaptureDeviceType.builtInTripleCamera,
          AVFoundationCaptureDeviceType.builtInDualWideCamera,
          AVFoundationCaptureDeviceType.builtInDualCamera,
        ];

    for (final AVFoundationCaptureDeviceType deviceType in virtualPriority) {
      for (final CameraChoice choice in choices) {
        if (choice.description.lensDirection == CameraLensDirection.back &&
            choice.isVirtualDevice &&
            choice.deviceType == deviceType) {
          return choice;
        }
      }
    }

    for (final CameraChoice choice in choices) {
      if (choice.description.lensDirection == CameraLensDirection.back &&
          choice.deviceType ==
              AVFoundationCaptureDeviceType.builtInWideAngleCamera) {
        return choice;
      }
    }

    for (final CameraChoice choice in choices) {
      if (choice.description.lensDirection == CameraLensDirection.back) {
        return choice;
      }
    }

    return choices.isNotEmpty ? choices.first : null;
  }
}

int _compareAVFoundationCameraDevices(
  AVFoundationCameraDevice first,
  AVFoundationCameraDevice second,
) {
  final int directionComparison = first.lensDirection.index.compareTo(
    second.lensDirection.index,
  );
  if (directionComparison != 0) {
    return directionComparison;
  }
  return _avFoundationCameraDevicePriority(
    first,
  ).compareTo(_avFoundationCameraDevicePriority(second));
}

int _avFoundationCameraDevicePriority(AVFoundationCameraDevice device) {
  switch (device.deviceType) {
    case AVFoundationCaptureDeviceType.builtInTripleCamera:
      return 0;
    case AVFoundationCaptureDeviceType.builtInDualWideCamera:
      return 1;
    case AVFoundationCaptureDeviceType.builtInDualCamera:
      return 2;
    case AVFoundationCaptureDeviceType.builtInWideAngleCamera:
      return 3;
    case AVFoundationCaptureDeviceType.builtInUltraWideCamera:
      return 4;
    case AVFoundationCaptureDeviceType.builtInTelephotoCamera:
      return 5;
    case AVFoundationCaptureDeviceType.builtInTrueDepthCamera:
      return 6;
    case AVFoundationCaptureDeviceType.unknown:
      return 7;
  }
}

String _avFoundationCameraDeviceLabel(AVFoundationCameraDevice device) {
  final String prefix = device.isVirtualDevice ? 'virtual ' : '';
  switch (device.deviceType) {
    case AVFoundationCaptureDeviceType.builtInTripleCamera:
      return '${prefix}triple';
    case AVFoundationCaptureDeviceType.builtInDualWideCamera:
      return '${prefix}dual-wide';
    case AVFoundationCaptureDeviceType.builtInDualCamera:
      return '${prefix}dual';
    case AVFoundationCaptureDeviceType.builtInWideAngleCamera:
      return 'wide';
    case AVFoundationCaptureDeviceType.builtInUltraWideCamera:
      return 'ultra-wide';
    case AVFoundationCaptureDeviceType.builtInTelephotoCamera:
      return 'tele';
    case AVFoundationCaptureDeviceType.builtInTrueDepthCamera:
      return 'true-depth';
    case AVFoundationCaptureDeviceType.unknown:
      return 'unknown';
  }
}

AVFoundationCaptureDeviceType _deviceTypeForLensType(CameraLensType lensType) {
  switch (lensType) {
    case CameraLensType.wide:
      return AVFoundationCaptureDeviceType.builtInWideAngleCamera;
    case CameraLensType.telephoto:
      return AVFoundationCaptureDeviceType.builtInTelephotoCamera;
    case CameraLensType.ultraWide:
      return AVFoundationCaptureDeviceType.builtInUltraWideCamera;
    case CameraLensType.unknown:
      return AVFoundationCaptureDeviceType.unknown;
  }
}
