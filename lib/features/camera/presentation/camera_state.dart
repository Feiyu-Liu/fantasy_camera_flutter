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
    this.displayZoomStops = const <double>[1.0],
    this.isInitializing = false,
    this.isTakingPicture = false,
    this.isSwitchingCamera = false,
    this.isTogglingFlash = false,
    this.captureOverlayTrigger = 0,
    this.insufficientCreditsPromptTrigger = 0,
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
  final List<double> displayZoomStops;
  final bool isInitializing;
  final bool isTakingPicture;
  final bool isSwitchingCamera;
  final bool isTogglingFlash;
  final int captureOverlayTrigger;
  final int insufficientCreditsPromptTrigger;

  bool get hasInitializedController => controller?.value.isInitialized ?? false;

  bool get canTakePicture =>
      hasInitializedController &&
      !isInitializing &&
      !isTakingPicture &&
      !isSwitchingCamera;

  bool get canShowShutter =>
      hasInitializedController && !isInitializing && !isSwitchingCamera;

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

  bool get isFrontCamera => currentLensDirection == CameraLensDirection.front;

  bool get canScaleZoom =>
      hasInitializedController && !isInitializing && !isSwitchingCamera;

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
    List<double>? displayZoomStops,
    bool? isInitializing,
    bool? isTakingPicture,
    bool? isSwitchingCamera,
    bool? isTogglingFlash,
    int? captureOverlayTrigger,
    int? insufficientCreditsPromptTrigger,
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
      displayZoomStops: displayZoomStops ?? this.displayZoomStops,
      isInitializing: isInitializing ?? this.isInitializing,
      isTakingPicture: isTakingPicture ?? this.isTakingPicture,
      isSwitchingCamera: isSwitchingCamera ?? this.isSwitchingCamera,
      isTogglingFlash: isTogglingFlash ?? this.isTogglingFlash,
      captureOverlayTrigger:
          captureOverlayTrigger ?? this.captureOverlayTrigger,
      insufficientCreditsPromptTrigger:
          insufficientCreditsPromptTrigger ??
          this.insufficientCreditsPromptTrigger,
    );
  }
}

double displayZoomMultiplierFor(AVFoundationZoomCapabilities? capabilities) {
  final double multiplier = capabilities?.displayZoomFactorMultiplier ?? 1.0;
  return multiplier == 0 ? 1.0 : multiplier;
}

double effectiveMaxRawZoomFor(AVFoundationZoomCapabilities capabilities) {
  final double? recommendedMaxZoom = capabilities.recommendedMaxZoomFactor;
  if (recommendedMaxZoom == null || !recommendedMaxZoom.isFinite) {
    return capabilities.maxZoomFactor;
  }
  return recommendedMaxZoom.clamp(
    capabilities.minZoomFactor,
    capabilities.maxZoomFactor,
  );
}

double initialRawZoomFor({
  required CameraLensDirection? lensDirection,
  required double minRawZoom,
  required double maxRawZoom,
  required double currentRawZoom,
  required double displayZoomMultiplier,
}) {
  if (lensDirection == CameraLensDirection.back) {
    return (1.0 / displayZoomMultiplier).clamp(minRawZoom, maxRawZoom);
  }
  return currentRawZoom.clamp(minRawZoom, maxRawZoom);
}

List<double> displayZoomStopsFor({
  required double minRawZoom,
  required double maxRawZoom,
  required double displayZoomMultiplier,
  AVFoundationZoomCapabilities? capabilities,
}) {
  final double multiplier = displayZoomMultiplier == 0
      ? 1.0
      : displayZoomMultiplier;
  final double minDisplayZoom = _normalizeDisplayZoom(minRawZoom * multiplier);
  final double maxDisplayZoom = _normalizeDisplayZoom(maxRawZoom * multiplier);
  final Set<double> stops = <double>{minDisplayZoom};

  if (minDisplayZoom <= 1.0 && 1.0 <= maxDisplayZoom) {
    stops.add(1.0);
  }

  if (capabilities != null) {
    for (final double rawZoom
        in capabilities.virtualDeviceSwitchOverZoomFactors) {
      stops.add(_normalizeDisplayZoom(rawZoom * multiplier));
    }
    for (final double rawZoom
        in capabilities.secondaryNativeResolutionZoomFactors) {
      stops.add(_normalizeDisplayZoom(rawZoom * multiplier));
    }
  }

  if (capabilities == null &&
      stops.length == 1 &&
      maxDisplayZoom != minDisplayZoom) {
    stops.add(maxDisplayZoom);
  }

  final List<double> sortedStops =
      stops
          .where(
            (double stop) =>
                stop.isFinite &&
                stop >= minDisplayZoom &&
                stop <= maxDisplayZoom,
          )
          .toList()
        ..sort();
  return sortedStops.isEmpty ? <double>[1.0] : sortedStops;
}

double _normalizeDisplayZoom(double zoom) {
  return (zoom * 10).roundToDouble() / 10;
}
