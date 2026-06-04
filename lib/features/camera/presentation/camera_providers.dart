import 'dart:async';
import 'dart:math';

import 'package:camera_avfoundation/camera_avfoundation.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../features/backend_api/domain/prompt_config.dart';
import '../../../features/generation_submission/presentation/generation_submission_providers.dart';
import '../../../shared/camera/camera_controller.dart';
import '../../../shared/core/app_logger.dart';
import '../data/camera_device_repository.dart';
import '../data/capture_orientation_reader.dart';
import '../domain/camera_choice.dart';
import 'camera_message.dart';
import 'camera_state.dart';

final cameraChoicesProvider = Provider<List<CameraChoice>>((Ref ref) {
  return const <CameraChoice>[];
}, dependencies: const <ProviderOrFamily>[]);

final cameraDeviceRepositoryProvider = Provider<CameraDeviceRepository>((
  Ref ref,
) {
  return const CameraDeviceRepository();
});

final captureOrientationReaderProvider = Provider<CaptureOrientationReader>((
  Ref ref,
) {
  return NativeCaptureOrientationReader();
});

final captureOrientationProvider =
    StreamProvider.autoDispose<DeviceOrientation>((Ref ref) {
      final CaptureOrientationReader reader = ref.watch(
        captureOrientationReaderProvider,
      );
      return reader.watchCaptureOrientation(
        initialOrientation: DeviceOrientation.portraitUp,
      );
    }, dependencies: <ProviderOrFamily>[captureOrientationReaderProvider]);

final cameraStateProvider =
    NotifierProvider.autoDispose<CameraControllerNotifier, CameraState>(
      CameraControllerNotifier.new,
      dependencies: <ProviderOrFamily>[
        cameraChoicesProvider,
        generationSubmissionControllerProvider,
        promptSelectionControllerProvider,
      ],
    );

class CameraControllerNotifier extends AutoDisposeNotifier<CameraState> {
  AVFoundationCamera? _avFoundationCamera;
  StreamSubscription<AVFoundationZoomChangedEvent>? _zoomSubscription;
  StreamSubscription<AVFoundationPhotoCaptureWillCaptureEvent>?
  _photoCaptureSubscription;
  bool _isDisposed = false;
  int _controllerGeneration = 0;

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
      displayZoomStops: const <double>[1.0],
    );
  }

  void handleScaleStart() {
    state = state.copyWith(baseRawZoom: state.currentRawZoom);
  }

  Future<void> setScaledZoom(double scale) async {
    final CameraController? currentController = state.controller;
    if (currentController == null ||
        !currentController.value.isInitialized ||
        state.isSwitchingCamera ||
        state.isFrontCamera) {
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
          rate: AppConfig.cameraZoomRampRate,
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

  Future<void> setDisplayZoomImmediately(double displayZoom) async {
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
      await CameraPlatform.instance.setZoomLevel(
        currentController.cameraId,
        rawZoom,
      );
      state = state.copyWith(currentRawZoom: rawZoom);
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  Future<void> focusAndExposeAt(Point<double> point) async {
    final CameraController? currentController = state.controller;
    if (currentController == null ||
        !currentController.value.isInitialized ||
        state.isSwitchingCamera) {
      return;
    }

    final Point<double> clampedPoint = Point<double>(
      point.x.clamp(0.0, 1.0),
      point.y.clamp(0.0, 1.0),
    );
    final bool focusSupported = currentController.value.focusPointSupported;
    final bool exposureSupported =
        currentController.value.exposurePointSupported;
    debugPrint(
      '[CameraFocus] tap point x=${clampedPoint.x.toStringAsFixed(3)} '
      'y=${clampedPoint.y.toStringAsFixed(3)} '
      'focusSupported=$focusSupported exposureSupported=$exposureSupported',
    );

    if (!focusSupported && !exposureSupported) {
      return;
    }

    try {
      await currentController.setFocusAndExposurePoint(clampedPoint);
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
    if (_avFoundationCamera == null) {
      _triggerCaptureOverlay();
    }

    try {
      final DeviceOrientation captureOrientation = await ref
          .read(captureOrientationReaderProvider)
          .readCaptureOrientation(
            fallback: currentController.value.deviceOrientation,
          );
      final XFile file = await currentController
          .takePictureWithCaptureOrientation(
            captureOrientation,
            restoreOrientation: DeviceOrientation.portraitUp,
          );
      state = state.copyWith(lastCapturedFile: file);
      final PromptSelectionSnapshot promptSelection = ref
          .read(promptSelectionControllerProvider)
          .snapshot;
      await ref
          .read(generationSubmissionControllerProvider.notifier)
          .queueCapturedFile(file, promptSelection: promptSelection);
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
    if (_isDisposed) {
      return;
    }
    state = state.copyWith(clearController: true);
    await _initializeCameraController(choice);
  }

  Future<void> _initializeCameraController(CameraChoice choice) async {
    final CameraController cameraController = CameraController(
      choice.description,
      AppConfig.cameraPreviewResolutionPreset,
      enableAudio: false,
      imageFormatGroup: AppConfig.cameraImageFormatGroup,
    );

    cameraController.addListener(_syncControllerValue);

    final int generation = _controllerGeneration;
    state = state.copyWith(controller: cameraController);

    try {
      await cameraController.initialize();
      if (!_isCurrentController(cameraController, generation)) {
        return;
      }
      await cameraController.lockCaptureOrientation(
        DeviceOrientation.portraitUp,
      );
      if (!_isCurrentController(cameraController, generation)) {
        return;
      }
      await cameraController.setImageFileFormat(
        AppConfig.cameraImageFileFormat,
      );
      if (!_isCurrentController(cameraController, generation)) {
        return;
      }
      final List<double> zoomRange = await Future.wait(<Future<double>>[
        CameraPlatform.instance.getMinZoomLevel(cameraController.cameraId),
        CameraPlatform.instance.getMaxZoomLevel(cameraController.cameraId),
      ]);
      if (!_isCurrentController(cameraController, generation)) {
        return;
      }
      state = state.copyWith(
        minAvailableZoom: zoomRange[0],
        maxAvailableZoom: zoomRange[1],
      );
      await _configureAVFoundationZoom(cameraController, generation);
      if (!_isCurrentController(cameraController, generation)) {
        return;
      }
      await _restoreFlashMode(cameraController, generation);
      if (!_isCurrentController(cameraController, generation)) {
        return;
      }
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

  Future<void> _restoreFlashMode(
    CameraController cameraController,
    int generation,
  ) async {
    final FlashMode desiredFlashMode =
        state.selectedCameraChoice?.description.lensDirection ==
            CameraLensDirection.front
        ? FlashMode.off
        : state.flashMode;
    try {
      await cameraController.setFlashMode(desiredFlashMode);
      if (!_isCurrentController(cameraController, generation)) {
        return;
      }
      state = state.copyWith(flashMode: desiredFlashMode);
    } on CameraException catch (e) {
      if (!_isCurrentController(cameraController, generation)) {
        return;
      }
      logAppError(e.code, e.description);
      state = state.copyWith(flashMode: FlashMode.off);
    }
  }

  Future<void> _configureAVFoundationZoom(
    CameraController cameraController,
    int generation,
  ) async {
    await _zoomSubscription?.cancel();
    _zoomSubscription = null;
    await _photoCaptureSubscription?.cancel();
    _photoCaptureSubscription = null;
    _avFoundationCamera = null;

    final CameraPlatform platform = CameraPlatform.instance;
    if (platform is AVFoundationCamera) {
      _avFoundationCamera = platform;
      final AVFoundationZoomCapabilities capabilities = await platform
          .getZoomCapabilities(cameraController.cameraId);
      if (!_isCurrentController(cameraController, generation)) {
        return;
      }
      final double displayZoomMultiplier = displayZoomMultiplierFor(
        capabilities,
      );
      final double maxRawZoom = effectiveMaxRawZoomFor(capabilities);
      final double currentRawZoom = initialRawZoomFor(
        lensDirection: state.currentLensDirection,
        minRawZoom: capabilities.minZoomFactor,
        maxRawZoom: maxRawZoom,
        currentRawZoom: capabilities.currentZoomFactor,
        displayZoomMultiplier: displayZoomMultiplier,
      );
      if (currentRawZoom != capabilities.currentZoomFactor) {
        await CameraPlatform.instance.setZoomLevel(
          cameraController.cameraId,
          currentRawZoom,
        );
        if (!_isCurrentController(cameraController, generation)) {
          return;
        }
      }
      state = state.copyWith(
        minAvailableZoom: capabilities.minZoomFactor,
        maxAvailableZoom: maxRawZoom,
        currentRawZoom: currentRawZoom,
        baseRawZoom: currentRawZoom,
        displayZoomMultiplier: displayZoomMultiplier,
        displayZoomStops: displayZoomStopsFor(
          minRawZoom: capabilities.minZoomFactor,
          maxRawZoom: maxRawZoom,
          displayZoomMultiplier: displayZoomMultiplier,
          capabilities: capabilities,
        ),
      );
      _zoomSubscription = platform
          .onZoomFactorChanged(cameraController.cameraId)
          .listen((AVFoundationZoomChangedEvent event) {
            if (!_isCurrentController(cameraController, generation)) {
              return;
            }
            state = state.copyWith(
              currentRawZoom: event.zoomFactor.clamp(
                state.minAvailableZoom,
                state.maxAvailableZoom,
              ),
            );
          });
      _photoCaptureSubscription = platform
          .onPhotoCaptureWillCapture(cameraController.cameraId)
          .listen((AVFoundationPhotoCaptureWillCaptureEvent event) {
            if (!_isCurrentController(cameraController, generation)) {
              return;
            }
            _triggerCaptureOverlay();
          });
      return;
    }

    if (!_isCurrentController(cameraController, generation)) {
      return;
    }
    state = state.copyWith(
      currentRawZoom: state.minAvailableZoom,
      baseRawZoom: state.minAvailableZoom,
      displayZoomMultiplier: 1.0,
      displayZoomStops: displayZoomStopsFor(
        minRawZoom: state.minAvailableZoom,
        maxRawZoom: state.maxAvailableZoom,
        displayZoomMultiplier: 1.0,
      ),
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
    _controllerGeneration += 1;
    await _zoomSubscription?.cancel();
    _zoomSubscription = null;
    await _photoCaptureSubscription?.cancel();
    _photoCaptureSubscription = null;
    _avFoundationCamera = null;

    if (currentController == null) {
      return;
    }

    currentController.removeListener(_syncControllerValue);
    await currentController.dispose();
  }

  bool _isCurrentController(CameraController cameraController, int generation) {
    return !_isDisposed &&
        _controllerGeneration == generation &&
        state.controller == cameraController;
  }
}
