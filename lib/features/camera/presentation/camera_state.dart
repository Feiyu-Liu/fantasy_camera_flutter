import 'package:camera_avfoundation/camera_avfoundation.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';

import '../../../shared/camera/camera_controller.dart';
import '../domain/camera_choice.dart';
import 'camera_message.dart';

class CameraState {
  const CameraState({
    this.controller,
    this.selectedCameraChoice,
    this.lastCapturedFile,
    this.message,
    this.flashMode = FlashMode.off,
    this.minAvailableZoom = 1.0,
    this.maxAvailableZoom = 1.0,
    this.currentRawZoom = 1.0,
    this.baseRawZoom = 1.0,
    this.displayZoomMultiplier = 1.0,
    this.isInitializing = false,
    this.isTakingPicture = false,
    this.isSwitchingCamera = false,
    this.isTogglingFlash = false,
    this.showCaptureFlash = false,
  });

  final CameraController? controller;
  final CameraChoice? selectedCameraChoice;
  final XFile? lastCapturedFile;
  final CameraMessage? message;
  final FlashMode flashMode;
  final double minAvailableZoom;
  final double maxAvailableZoom;
  final double currentRawZoom;
  final double baseRawZoom;
  final double displayZoomMultiplier;
  final bool isInitializing;
  final bool isTakingPicture;
  final bool isSwitchingCamera;
  final bool isTogglingFlash;
  final bool showCaptureFlash;

  bool get hasInitializedController => controller?.value.isInitialized ?? false;

  bool get canTakePicture =>
      hasInitializedController &&
      !isInitializing &&
      !isTakingPicture &&
      !isSwitchingCamera;

  bool get canToggleFlash =>
      hasInitializedController &&
      !isInitializing &&
      !isSwitchingCamera &&
      !isTogglingFlash &&
      (selectedCameraChoice?.description.lensDirection !=
          CameraLensDirection.front);

  bool get canFlipCamera =>
      hasInitializedController &&
      !isInitializing &&
      !isTakingPicture &&
      !isSwitchingCamera;

  CameraLensDirection? get currentLensDirection =>
      selectedCameraChoice?.description.lensDirection;

  double rawToDisplayZoom(double rawZoom) {
    return rawZoom * displayZoomMultiplier;
  }

  double displayToRawZoom(double displayZoom) {
    return displayZoom / displayZoomMultiplier;
  }

  bool canSetDisplayZoom(double displayZoom) {
    final double rawZoom = displayToRawZoom(displayZoom);
    return rawZoom >= minAvailableZoom && rawZoom <= maxAvailableZoom;
  }

  CameraState copyWith({
    CameraController? controller,
    bool clearController = false,
    CameraChoice? selectedCameraChoice,
    bool clearSelectedCameraChoice = false,
    XFile? lastCapturedFile,
    bool clearLastCapturedFile = false,
    CameraMessage? message,
    bool clearMessage = false,
    FlashMode? flashMode,
    double? minAvailableZoom,
    double? maxAvailableZoom,
    double? currentRawZoom,
    double? baseRawZoom,
    double? displayZoomMultiplier,
    bool? isInitializing,
    bool? isTakingPicture,
    bool? isSwitchingCamera,
    bool? isTogglingFlash,
    bool? showCaptureFlash,
  }) {
    return CameraState(
      controller: clearController ? null : controller ?? this.controller,
      selectedCameraChoice: clearSelectedCameraChoice
          ? null
          : selectedCameraChoice ?? this.selectedCameraChoice,
      lastCapturedFile: clearLastCapturedFile
          ? null
          : lastCapturedFile ?? this.lastCapturedFile,
      message: clearMessage ? null : message ?? this.message,
      flashMode: flashMode ?? this.flashMode,
      minAvailableZoom: minAvailableZoom ?? this.minAvailableZoom,
      maxAvailableZoom: maxAvailableZoom ?? this.maxAvailableZoom,
      currentRawZoom: currentRawZoom ?? this.currentRawZoom,
      baseRawZoom: baseRawZoom ?? this.baseRawZoom,
      displayZoomMultiplier:
          displayZoomMultiplier ?? this.displayZoomMultiplier,
      isInitializing: isInitializing ?? this.isInitializing,
      isTakingPicture: isTakingPicture ?? this.isTakingPicture,
      isSwitchingCamera: isSwitchingCamera ?? this.isSwitchingCamera,
      isTogglingFlash: isTogglingFlash ?? this.isTogglingFlash,
      showCaptureFlash: showCaptureFlash ?? this.showCaptureFlash,
    );
  }
}

double displayZoomMultiplierFor(AVFoundationZoomCapabilities? capabilities) {
  final double multiplier = capabilities?.displayZoomFactorMultiplier ?? 1.0;
  return multiplier == 0 ? 1.0 : multiplier;
}
