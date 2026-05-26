import 'dart:async';

import 'package:camera_avfoundation/camera_avfoundation.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/widgets.dart';

import '../../../shared/camera/camera_controller.dart';
import '../../../shared/core/app_logger.dart';
import '../data/camera_device_repository.dart';
import '../domain/camera_choice.dart';

class CameraViewModel extends ChangeNotifier {
  CameraViewModel({
    required List<CameraChoice> cameraChoices,
    CameraDeviceRepository cameraDeviceRepository =
        const CameraDeviceRepository(),
  }) : _cameraChoices = cameraChoices,
       _cameraDeviceRepository = cameraDeviceRepository;

  final List<CameraChoice> _cameraChoices;
  final CameraDeviceRepository _cameraDeviceRepository;

  CameraController? _controller;
  AVFoundationCamera? _avFoundationCamera;
  AVFoundationZoomCapabilities? _zoomCapabilities;
  StreamSubscription<AVFoundationZoomChangedEvent>? _zoomSubscription;

  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentRawZoom = 1.0;
  double _baseRawZoom = 1.0;
  bool _isTakingPicture = false;
  bool _showFlash = false;
  String? _message;
  bool _isDisposed = false;

  CameraController? get controller => _controller;
  double get currentRawZoom => _currentRawZoom;
  bool get isTakingPicture => _isTakingPicture;
  bool get showFlash => _showFlash;
  String? get message => _message;

  bool get canTakePicture =>
      (_controller?.value.isInitialized ?? false) && !_isTakingPicture;

  Future<void> openDefaultCamera() async {
    if (_controller != null) {
      return;
    }

    final CameraChoice? choice = _cameraDeviceRepository
        .defaultStartupCameraChoice(_cameraChoices);
    if (choice == null) {
      _message = 'No camera found.';
      _emit();
      return;
    }

    await _initializeCameraController(choice.description);
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await openDefaultCamera();
      return;
    }

    final CameraController? currentController = _controller;
    if (currentController == null ||
        !currentController.value.isInitialized ||
        state != AppLifecycleState.inactive) {
      return;
    }

    await _zoomSubscription?.cancel();
    _zoomSubscription = null;
    unawaited(currentController.dispose());
    _controller = null;
    _avFoundationCamera = null;
    _zoomCapabilities = null;
    _message = 'Starting camera...';
    _emit();
  }

  void handleScaleStart() {
    _baseRawZoom = _currentRawZoom;
  }

  Future<void> setScaledZoom(double scale) async {
    final CameraController? currentController = _controller;
    if (currentController == null || !currentController.value.isInitialized) {
      return;
    }

    final double rawZoom = (_baseRawZoom * scale).clamp(
      _minAvailableZoom,
      _maxAvailableZoom,
    );
    try {
      await CameraPlatform.instance.setZoomLevel(
        currentController.cameraId,
        rawZoom,
      );
      _currentRawZoom = rawZoom;
      _emit();
      await _refreshCurrentZoomFactor();
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  Future<void> setDisplayZoom(double displayZoom) async {
    final CameraController? currentController = _controller;
    if (currentController == null || !currentController.value.isInitialized) {
      return;
    }

    final double rawZoom = displayToRawZoom(
      displayZoom,
    ).clamp(_minAvailableZoom, _maxAvailableZoom);

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
      _currentRawZoom = rawZoom;
      _emit();
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  Future<void> takePicture() async {
    final CameraController? currentController = _controller;
    if (currentController == null ||
        !currentController.value.isInitialized ||
        currentController.value.isTakingPicture ||
        _isTakingPicture) {
      return;
    }

    _isTakingPicture = true;
    _emit();

    try {
      await currentController.takePicture();
      _showCaptureFlash();
    } on CameraException catch (e) {
      _showCameraException(e);
    } finally {
      _isTakingPicture = false;
      _emit();
    }
  }

  double rawToDisplayZoom(double rawZoom) {
    return rawZoom * _displayZoomMultiplier;
  }

  double displayToRawZoom(double displayZoom) {
    return displayZoom / _displayZoomMultiplier;
  }

  bool canSetDisplayZoom(double displayZoom) {
    final double rawZoom = displayToRawZoom(displayZoom);
    return rawZoom >= _minAvailableZoom && rawZoom <= _maxAvailableZoom;
  }

  Future<void> _initializeCameraController(
    CameraDescription cameraDescription,
  ) async {
    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    cameraController.addListener(_emit);

    _controller = cameraController;
    _message = 'Starting camera...';
    _emit();

    try {
      await cameraController.initialize();
      final List<double> zoomRange = await Future.wait(<Future<double>>[
        CameraPlatform.instance.getMinZoomLevel(cameraController.cameraId),
        CameraPlatform.instance.getMaxZoomLevel(cameraController.cameraId),
      ]);
      _minAvailableZoom = zoomRange[0];
      _maxAvailableZoom = zoomRange[1];
      await _configureAVFoundationZoom(cameraController);
      _message = null;
      _emit();
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  Future<void> _configureAVFoundationZoom(
    CameraController cameraController,
  ) async {
    await _zoomSubscription?.cancel();
    _zoomSubscription = null;
    _avFoundationCamera = null;
    _zoomCapabilities = null;

    final CameraPlatform platform = CameraPlatform.instance;
    if (platform is AVFoundationCamera) {
      _avFoundationCamera = platform;
      final AVFoundationZoomCapabilities capabilities = await platform
          .getZoomCapabilities(cameraController.cameraId);
      _zoomCapabilities = capabilities;
      _minAvailableZoom = capabilities.minZoomFactor;
      _maxAvailableZoom = capabilities.maxZoomFactor;
      _currentRawZoom = capabilities.currentZoomFactor;
      _zoomSubscription = platform
          .onZoomFactorChanged(cameraController.cameraId)
          .listen((AVFoundationZoomChangedEvent event) {
            _currentRawZoom = event.zoomFactor;
            _emit();
          });
      return;
    }

    _currentRawZoom = _minAvailableZoom;
  }

  Future<void> _refreshCurrentZoomFactor() async {
    final CameraController? currentController = _controller;
    final AVFoundationCamera? avFoundationCamera = _avFoundationCamera;
    if (currentController == null ||
        !currentController.value.isInitialized ||
        avFoundationCamera == null) {
      return;
    }

    try {
      _currentRawZoom = await avFoundationCamera.getCurrentZoomFactor(
        currentController.cameraId,
      );
      _emit();
    } on CameraException {
      // Gesture updates already applied a local value; ignore refresh failures.
    }
  }

  void _showCaptureFlash() {
    _showFlash = true;
    _emit();
    Future<void>.delayed(const Duration(milliseconds: 30), () {
      _showFlash = false;
      _emit();
    });
  }

  double get _displayZoomMultiplier {
    final double multiplier =
        _zoomCapabilities?.displayZoomFactorMultiplier ?? 1.0;
    return multiplier == 0 ? 1.0 : multiplier;
  }

  void _showCameraException(CameraException e) {
    logAppError(e.code, e.description);
    _message = e.description ?? e.code;
    _emit();
  }

  void _emit() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.removeListener(_emit);
    unawaited(_zoomSubscription?.cancel());
    unawaited(_controller?.dispose());
    super.dispose();
  }
}
