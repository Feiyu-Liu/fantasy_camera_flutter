import 'dart:async';

import 'package:camera_avfoundation/camera_avfoundation.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';

import 'camera_controller.dart';
import 'camera_preview.dart';

void _logError(String code, String? message) {
  // ignore: avoid_print
  print('Error: $code${message == null ? '' : '\nError Message: $message'}');
}

List<_CameraChoice> _cameraChoices = <_CameraChoice>[];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    _cameraChoices = await _loadCameraChoices();
  } on CameraException catch (e) {
    _logError(e.code, e.description);
  }
  runApp(const CameraApp());
}

class CameraApp extends StatelessWidget {
  const CameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraExampleHome(),
    );
  }
}

class CameraExampleHome extends StatefulWidget {
  const CameraExampleHome({super.key});

  @override
  State<CameraExampleHome> createState() => _CameraExampleHomeState();
}

class _CameraExampleHomeState extends State<CameraExampleHome>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const List<double> _fixedDisplayZooms = <double>[0.5, 1.0, 2.0];
  static const double _previewAspectRatio = 4 / 3;
  static const double _previewTopInsetAfterSafeArea = 58;
  static const double _minimumDockHeight = 132;
  static const double _zoomButtonSize = 44;

  CameraController? _controller;
  AVFoundationCamera? _avFoundationCamera;
  AVFoundationZoomCapabilities? _zoomCapabilities;
  StreamSubscription<AVFoundationZoomChangedEvent>? _zoomSubscription;

  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentRawZoom = 1.0;
  double _baseRawZoom = 1.0;
  int _pointers = 0;
  bool _isTakingPicture = false;
  bool _showFlash = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openDefaultCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_zoomSubscription?.cancel());
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      unawaited(_zoomSubscription?.cancel());
      _zoomSubscription = null;
      unawaited(controller.dispose());
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _openDefaultCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final EdgeInsets safeArea = MediaQuery.paddingOf(context);
          final double previewTop =
              safeArea.top + _previewTopInsetAfterSafeArea;
          final double previewHeight =
              (constraints.maxWidth * _previewAspectRatio).clamp(
                0.0,
                constraints.maxHeight - previewTop - _minimumDockHeight,
              );
          final double dockHeight =
              (constraints.maxHeight - previewTop - previewHeight).clamp(
                _minimumDockHeight,
                constraints.maxHeight,
              );

          return Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                top: previewTop,
                width: constraints.maxWidth,
                height: previewHeight,
                child: _PreviewPanel(
                  controller: _controller,
                  message: _message,
                  child: _buildPreviewGestureLayer(),
                ),
              ),
              Positioned(
                left: 0,
                top: previewTop + previewHeight - 69,
                width: constraints.maxWidth,
                height: 44,
                child: Center(child: _buildZoomControls()),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: dockHeight,
                child: _buildBottomDock(),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showFlash ? 0.85 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPreviewGestureLayer() {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Listener(
      onPointerDown: (_) => _pointers++,
      onPointerUp: (_) => _pointers = (_pointers - 1).clamp(0, 10),
      onPointerCancel: (_) => _pointers = (_pointers - 1).clamp(0, 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
      ),
    );
  }

  Widget _buildZoomControls() {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final double currentDisplayZoom = _rawToDisplayZoom(_currentRawZoom);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(_zoomButtonSize / 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final double displayZoom in _fixedDisplayZooms)
              _ZoomButton(
                label: _formatDisplayZoom(displayZoom),
                selected:
                    _nearestFixedDisplayZoom(currentDisplayZoom) == displayZoom,
                enabled: _canSetDisplayZoom(displayZoom),
                size: _zoomButtonSize,
                onPressed: () => _setDisplayZoom(displayZoom),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDock() {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.98),
      child: Align(
        alignment: const Alignment(0, -0.1),
        child: _ShutterButton(
          enabled: _controller?.value.isInitialized ?? false,
          busy: _isTakingPicture,
          onPressed: _takePicture,
        ),
      ),
    );
  }

  Future<void> _openDefaultCamera() async {
    if (!mounted || _controller != null) {
      return;
    }

    final _CameraChoice? choice = _defaultStartupCameraChoice();
    if (choice == null) {
      setState(() {
        _message = 'No camera found.';
      });
      return;
    }

    await _initializeCameraController(choice.description);
  }

  _CameraChoice? _defaultStartupCameraChoice() {
    const List<AVFoundationCaptureDeviceType> virtualPriority =
        <AVFoundationCaptureDeviceType>[
          AVFoundationCaptureDeviceType.builtInTripleCamera,
          AVFoundationCaptureDeviceType.builtInDualWideCamera,
          AVFoundationCaptureDeviceType.builtInDualCamera,
        ];

    for (final AVFoundationCaptureDeviceType deviceType in virtualPriority) {
      for (final _CameraChoice choice in _cameraChoices) {
        if (choice.description.lensDirection == CameraLensDirection.back &&
            choice.isVirtualDevice &&
            choice.deviceType == deviceType) {
          return choice;
        }
      }
    }

    for (final _CameraChoice choice in _cameraChoices) {
      if (choice.description.lensDirection == CameraLensDirection.back &&
          choice.deviceType ==
              AVFoundationCaptureDeviceType.builtInWideAngleCamera) {
        return choice;
      }
    }

    for (final _CameraChoice choice in _cameraChoices) {
      if (choice.description.lensDirection == CameraLensDirection.back) {
        return choice;
      }
    }

    return _cameraChoices.isNotEmpty ? _cameraChoices.first : null;
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

    cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    setState(() {
      _controller = cameraController;
      _message = 'Starting camera...';
    });

    try {
      await cameraController.initialize();
      final List<double> zoomRange = await Future.wait(<Future<double>>[
        CameraPlatform.instance.getMinZoomLevel(cameraController.cameraId),
        CameraPlatform.instance.getMaxZoomLevel(cameraController.cameraId),
      ]);
      _minAvailableZoom = zoomRange[0];
      _maxAvailableZoom = zoomRange[1];
      await _configureAVFoundationZoom(cameraController);
      if (mounted) {
        setState(() {
          _message = null;
        });
      }
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
            if (!mounted) {
              return;
            }
            setState(() {
              _currentRawZoom = event.zoomFactor;
            });
          });
      return;
    }

    _currentRawZoom = _minAvailableZoom;
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseRawZoom = _currentRawZoom;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    final CameraController? controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _pointers != 2) {
      return;
    }

    final double rawZoom = (_baseRawZoom * details.scale).clamp(
      _minAvailableZoom,
      _maxAvailableZoom,
    );
    try {
      await CameraPlatform.instance.setZoomLevel(controller.cameraId, rawZoom);
      setState(() {
        _currentRawZoom = rawZoom;
      });
      await _refreshCurrentZoomFactor();
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  Future<void> _setDisplayZoom(double displayZoom) async {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final double rawZoom = _displayToRawZoom(
      displayZoom,
    ).clamp(_minAvailableZoom, _maxAvailableZoom);

    try {
      final AVFoundationCamera? avFoundationCamera = _avFoundationCamera;
      if (avFoundationCamera != null) {
        await avFoundationCamera.setZoomFactor(
          controller.cameraId,
          rawZoom,
          animated: true,
        );
      } else {
        await CameraPlatform.instance.setZoomLevel(
          controller.cameraId,
          rawZoom,
        );
      }
      setState(() {
        _currentRawZoom = rawZoom;
      });
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  Future<void> _refreshCurrentZoomFactor() async {
    final CameraController? controller = _controller;
    final AVFoundationCamera? avFoundationCamera = _avFoundationCamera;
    if (controller == null ||
        !controller.value.isInitialized ||
        avFoundationCamera == null) {
      return;
    }

    try {
      final double rawZoom = await avFoundationCamera.getCurrentZoomFactor(
        controller.cameraId,
      );
      if (mounted) {
        setState(() {
          _currentRawZoom = rawZoom;
        });
      }
    } on CameraException {
      // Gesture updates already applied a local value; ignore refresh failures.
    }
  }

  Future<void> _takePicture() async {
    final CameraController? controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _isTakingPicture) {
      return;
    }

    setState(() {
      _isTakingPicture = true;
    });

    try {
      await controller.takePicture();
      _showCaptureFlash();
    } on CameraException catch (e) {
      _showCameraException(e);
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  void _showCaptureFlash() {
    setState(() {
      _showFlash = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 30), () {
      if (mounted) {
        setState(() {
          _showFlash = false;
        });
      }
    });
  }

  double _rawToDisplayZoom(double rawZoom) {
    return rawZoom * _displayZoomMultiplier;
  }

  double _displayToRawZoom(double displayZoom) {
    return displayZoom / _displayZoomMultiplier;
  }

  double get _displayZoomMultiplier {
    final double multiplier =
        _zoomCapabilities?.displayZoomFactorMultiplier ?? 1.0;
    return multiplier == 0 ? 1.0 : multiplier;
  }

  bool _canSetDisplayZoom(double displayZoom) {
    final double rawZoom = _displayToRawZoom(displayZoom);
    return rawZoom >= _minAvailableZoom && rawZoom <= _maxAvailableZoom;
  }

  double _nearestFixedDisplayZoom(double displayZoom) {
    return _fixedDisplayZooms.reduce((double best, double candidate) {
      return (candidate - displayZoom).abs() < (best - displayZoom).abs()
          ? candidate
          : best;
    });
  }

  String _formatDisplayZoom(double displayZoom) {
    if (displayZoom == 0.5) {
      return '.5';
    }
    if (displayZoom == 1.0) {
      return '1x';
    }
    if (displayZoom == displayZoom.roundToDouble()) {
      return displayZoom.toInt().toString();
    }
    return displayZoom.toStringAsFixed(1);
  }

  void _showCameraException(CameraException e) {
    _logError(e.code, e.description);
    if (mounted) {
      setState(() {
        _message = e.description ?? e.code;
      });
    }
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.controller,
    required this.message,
    required this.child,
  });

  final CameraController? controller;
  final String? message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final CameraController? cameraController = controller;
    final bool initialized = cameraController?.value.isInitialized ?? false;
    return ClipRect(
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (initialized)
              _CoveredCameraPreview(controller: cameraController!)
            else
              const Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            child,
            if (message != null)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        message!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoveredCameraPreview extends StatelessWidget {
  const _CoveredCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final Size previewSize = controller.value.previewSize ?? Size.zero;
    if (previewSize.isEmpty) {
      return CameraPreview(controller);
    }

    final double cameraAspectRatio = previewSize.width / previewSize.height;
    final double portraitAspectRatio = 1 / cameraAspectRatio;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: portraitAspectRatio,
        height: 1,
        child: CameraPreview(controller),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.size,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.22)
            : Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: Opacity(
                opacity: enabled ? 1.0 : 0.35,
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? const Color(0xffffc72c) : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatefulWidget {
  const _ShutterButton({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled && !widget.busy ? widget.onPressed : null,
      onTapDown: widget.enabled && !widget.busy
          ? (_) => setState(() {
              _pressed = true;
            })
          : null,
      onTapCancel: () => setState(() {
        _pressed = false;
      }),
      onTapUp: (_) => setState(() {
        _pressed = false;
      }),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.4,
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xff474747), width: 5),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x52000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraChoice {
  const _CameraChoice({
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

Future<List<_CameraChoice>> _loadCameraChoices() async {
  final CameraPlatform platform = CameraPlatform.instance;
  if (platform is AVFoundationCamera) {
    final List<AVFoundationCameraDevice> devices = await platform
        .getAvailableCameraDevices();
    if (devices.isNotEmpty) {
      devices.sort(_compareAVFoundationCameraDevices);
      return devices.map((AVFoundationCameraDevice device) {
        return _CameraChoice(
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
    return _CameraChoice(
      description: description,
      label: description.lensType.name,
      isVirtualDevice: false,
      deviceType: _deviceTypeForLensType(description.lensType),
    );
  }).toList();
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
