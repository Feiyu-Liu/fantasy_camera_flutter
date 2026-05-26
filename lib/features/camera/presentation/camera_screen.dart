import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/camera/camera_controller.dart';
import '../../../shared/camera/camera_preview.dart';
import '../domain/camera_choice.dart';
import 'camera_view_model.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({required this.cameraChoices, super.key});

  final List<CameraChoice> cameraChoices;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  static const List<double> _fixedDisplayZooms = <double>[0.5, 1.0, 2.0];
  static const double _previewAspectRatio = 4 / 3;
  static const double _previewTopInsetAfterSafeArea = 58;
  static const double _minimumDockHeight = 132;
  static const double _zoomButtonSize = 44;

  late final CameraViewModel _viewModel;
  int _pointers = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = CameraViewModel(cameraChoices: widget.cameraChoices);
    _viewModel.addListener(_handleViewModelChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_viewModel.openDefaultCamera());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.removeListener(_handleViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_viewModel.handleAppLifecycleState(state));
  }

  void _handleViewModelChanged() {
    if (mounted) {
      setState(() {});
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
                    opacity: _viewModel.showFlash ? 0.85 : 0.0,
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
        onScaleStart: (_) => _viewModel.handleScaleStart(),
        onScaleUpdate: _handleScaleUpdate,
      ),
    );
  }

  Widget _buildZoomControls() {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final double currentDisplayZoom = _viewModel.rawToDisplayZoom(
      _viewModel.currentRawZoom,
    );
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
                enabled: _viewModel.canSetDisplayZoom(displayZoom),
                size: _zoomButtonSize,
                onPressed: () => _viewModel.setDisplayZoom(displayZoom),
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
          busy: _viewModel.isTakingPicture,
          onPressed: _viewModel.takePicture,
        ),
      ),
    );
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    final CameraController? controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _pointers != 2) {
      return;
    }

    await _viewModel.setScaledZoom(details.scale);
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

  CameraController? get _controller => _viewModel.controller;

  String? get _message => _viewModel.message;
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
