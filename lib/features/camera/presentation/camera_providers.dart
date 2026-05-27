import 'dart:async';

import 'package:camera_avfoundation/camera_avfoundation.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/camera/camera_controller.dart';
import '../../../shared/core/app_logger.dart';
import '../data/camera_device_repository.dart';
import '../domain/camera_choice.dart';
import 'camera_message.dart';
import 'camera_state.dart';

final cameraChoicesProvider = Provider<List<CameraChoice>>((Ref ref) {
  return const <CameraChoice>[];
});

final cameraDeviceRepositoryProvider = Provider<CameraDeviceRepository>((
  Ref ref,
) {
  return const CameraDeviceRepository();
});

final cameraStateProvider =
    NotifierProvider.autoDispose<CameraControllerNotifier, CameraState>(
      CameraControllerNotifier.new,
    );

class CameraControllerNotifier extends AutoDisposeNotifier<CameraState> {
  AVFoundationCamera? _avFoundationCamera;
  StreamSubscription<AVFoundationZoomChangedEvent>? _zoomSubscription;
  bool _isDisposed = false;

  List<CameraChoice> get _cameraChoices => ref.read(cameraChoicesProvider);

  CameraDeviceRepository get _cameraDeviceRepository =>
      ref.read(cameraDeviceRepositoryProvider);

  @override
  CameraState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      unawaited(_disposeCurrentController());
    });
    return const CameraState();
  }

  Future<void> openDefaultCamera() async {
    if (state.controller != null || state.isInitializing) {
      return;
    }

    final CameraChoice? choice = _cameraDeviceRepository
        .defaultStartupCameraChoice(_cameraChoices);
    if (choice == null) {
      state = state.copyWith(message: const CameraNoCameraFoundMessage());
      return;
    }

    await _openCameraChoice(choice);
  }

  Future<void> handleAppLifecycleState(AppLifecycleState lifecycleState) async {
    if (lifecycleState == AppLifecycleState.resumed) {
      await openDefaultCamera();
      return;
    }

    if (lifecycleState != AppLifecycleState.inactive &&
        lifecycleState != AppLifecycleState.paused &&
        lifecycleState != AppLifecycleState.hidden &&
        lifecycleState != AppLifecycleState.detached) {
      return;
    }

    if (state.controller == null) {
      return;
    }

    await _disposeCurrentController();
    state = state.copyWith(
      clearController: true,
      message: const CameraStartingMessage(),
      isInitializing: false,
      isTakingPicture: false,
      isSwitchingCamera: false,
      isTogglingFlash: false,
      minAvailableZoom: 1.0,
      maxAvailableZoom: 1.0,
      currentRawZoom: 1.0,
      baseRawZoom: 1.0,
      displayZoomMultiplier: 1.0,
    );
  }

  void handleScaleStart() {
    state = state.copyWith(baseRawZoom: state.currentRawZoom);
  }

  Future<void> setScaledZoom(double scale) async {
    final CameraController? currentController = state.controller;
    if (currentController == null ||
        !currentController.value.isInitialized ||
        state.isSwitchingCamera) {
      return;
    }

    final double rawZoom = (state.baseRawZoom * scale).clamp(
      state.minAvailableZoom,
      state.maxAvailableZoom,
    );
    try {
      await CameraPlatform.instance.setZoomLevel(
        currentController.cameraId,
        rawZoom,
      );
      state = state.copyWith(currentRawZoom: rawZoom);
      await _refreshCurrentZoomFactor();
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  Future<void> setDisplayZoom(double displayZoom) async {
    final CameraController? currentController = state.controller;
    if (currentController == null ||
        !currentController.value.isInitialized ||
        state.isSwitchingCamera) {
      return;
    }

    final double rawZoom = state
        .displayToRawZoom(displayZoom)
        .clamp(state.minAvailableZoom, state.maxAvailableZoom);

    try {
      final AVFoundationCamera? avFoundationCamera = _avFoundationCamera;
      if (avFoundationCamera != null) {
        await avFoundationCamera.setZoomFactor(
          currentController.cameraId,
          rawZoom,
          animated: true,
        );
      } else {
        await CameraPlatform.instance.setZoomLevel(
          currentController.cameraId,
          rawZoom,
        );
      }
      state = state.copyWith(currentRawZoom: rawZoom);
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  Future<XFile?> takePicture() async {
    final CameraController? currentController = state.controller;
    if (currentController == null ||
        !currentController.value.isInitialized ||
        currentController.value.isTakingPicture ||
        !state.canTakePicture) {
      return null;
    }

    state = state.copyWith(isTakingPicture: true);
    _triggerCaptureOverlay();

    try {
      final XFile file = await currentController.takePicture();
      state = state.copyWith(lastCapturedFile: file);
      return file;
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    } finally {
      state = state.copyWith(isTakingPicture: false);
    }
  }

  Future<void> toggleFlash() async {
    final CameraController? currentController = state.controller;
    if (currentController == null ||
        !currentController.value.isInitialized ||
        !state.canToggleFlash) {
      return;
    }

    final FlashMode nextMode = state.flashMode == FlashMode.off
        ? FlashMode.always
        : FlashMode.off;

    state = state.copyWith(isTogglingFlash: true);
    try {
      await currentController.setFlashMode(nextMode);
      state = state.copyWith(flashMode: nextMode);
    } on CameraException catch (e) {
      _showCameraException(e);
    } finally {
      state = state.copyWith(isTogglingFlash: false);
    }
  }

  Future<void> flipCamera() async {
    if (!state.canFlipCamera) {
      return;
    }

    final CameraLensDirection? currentLensDirection =
        state.currentLensDirection;
    if (currentLensDirection == null) {
      return;
    }

    final CameraChoice? targetChoice = _cameraDeviceRepository
        .oppositeLensCameraChoice(_cameraChoices, currentLensDirection);
    if (targetChoice == null) {
      return;
    }

    state = state.copyWith(isSwitchingCamera: true, isTakingPicture: false);
    try {
      await _openCameraChoice(targetChoice);
    } finally {
      state = state.copyWith(isSwitchingCamera: false);
    }
  }

  Future<void> _openCameraChoice(CameraChoice choice) async {
    state = state.copyWith(
      selectedCameraChoice: choice,
      message: const CameraStartingMessage(),
      isInitializing: true,
    );

    await _disposeCurrentController();
    state = state.copyWith(clearController: true);
    await _initializeCameraController(choice);
  }

  Future<void> _initializeCameraController(CameraChoice choice) async {
    final CameraController cameraController = CameraController(
      choice.description,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    cameraController.addListener(_syncControllerValue);

    state = state.copyWith(controller: cameraController);

    try {
      await cameraController.initialize();
      final List<double> zoomRange = await Future.wait(<Future<double>>[
        CameraPlatform.instance.getMinZoomLevel(cameraController.cameraId),
        CameraPlatform.instance.getMaxZoomLevel(cameraController.cameraId),
      ]);
      state = state.copyWith(
        minAvailableZoom: zoomRange[0],
        maxAvailableZoom: zoomRange[1],
      );
      await _configureAVFoundationZoom(cameraController);
      await _restoreFlashMode(cameraController);
      state = state.copyWith(
        clearMessage: true,
        isInitializing: false,
        selectedCameraChoice: choice,
      );
    } on CameraException catch (e) {
      _showCameraException(e);
      state = state.copyWith(isInitializing: false);
    }
  }

  Future<void> _restoreFlashMode(CameraController cameraController) async {
    final FlashMode desiredFlashMode =
        state.selectedCameraChoice?.description.lensDirection ==
            CameraLensDirection.front
        ? FlashMode.off
        : state.flashMode;
    try {
      await cameraController.setFlashMode(desiredFlashMode);
      state = state.copyWith(flashMode: desiredFlashMode);
    } on CameraException catch (e) {
      logAppError(e.code, e.description);
      state = state.copyWith(flashMode: FlashMode.off);
    }
  }

  Future<void> _configureAVFoundationZoom(
    CameraController cameraController,
  ) async {
    await _zoomSubscription?.cancel();
    _zoomSubscription = null;
    _avFoundationCamera = null;

    final CameraPlatform platform = CameraPlatform.instance;
    if (platform is AVFoundationCamera) {
      _avFoundationCamera = platform;
      final AVFoundationZoomCapabilities capabilities = await platform
          .getZoomCapabilities(cameraController.cameraId);
      state = state.copyWith(
        minAvailableZoom: capabilities.minZoomFactor,
        maxAvailableZoom: capabilities.maxZoomFactor,
        currentRawZoom: capabilities.currentZoomFactor,
        baseRawZoom: capabilities.currentZoomFactor,
        displayZoomMultiplier: displayZoomMultiplierFor(capabilities),
      );
      _zoomSubscription = platform
          .onZoomFactorChanged(cameraController.cameraId)
          .listen((AVFoundationZoomChangedEvent event) {
            state = state.copyWith(currentRawZoom: event.zoomFactor);
          });
      return;
    }

    state = state.copyWith(
      currentRawZoom: state.minAvailableZoom,
      baseRawZoom: state.minAvailableZoom,
      displayZoomMultiplier: 1.0,
    );
  }

  Future<void> _refreshCurrentZoomFactor() async {
    final CameraController? currentController = state.controller;
    final AVFoundationCamera? avFoundationCamera = _avFoundationCamera;
    if (currentController == null ||
        !currentController.value.isInitialized ||
        avFoundationCamera == null) {
      return;
    }

    try {
      final double currentZoom = await avFoundationCamera.getCurrentZoomFactor(
        currentController.cameraId,
      );
      state = state.copyWith(currentRawZoom: currentZoom);
    } on CameraException {
      // Gesture updates already applied a local value; ignore refresh failures.
    }
  }

  void _triggerCaptureOverlay() {
    state = state.copyWith(
      captureOverlayTrigger: state.captureOverlayTrigger + 1,
    );
  }

  void _showCameraException(CameraException e) {
    logAppError(e.code, e.description);
    state = state.copyWith(
      message: CameraErrorMessage(e.description ?? e.code),
    );
  }

  void _syncControllerValue() {
    if (_isDisposed) {
      return;
    }
    state = state.copyWith();
  }

  Future<void> _disposeCurrentController() async {
    final CameraController? currentController = state.controller;
    await _zoomSubscription?.cancel();
    _zoomSubscription = null;
    _avFoundationCamera = null;

    if (currentController == null) {
      return;
    }

    currentController.removeListener(_syncControllerValue);
    await currentController.dispose();
  }
}
