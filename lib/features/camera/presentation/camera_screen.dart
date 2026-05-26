import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_ui/my_ui.dart';

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
  late final CameraViewModel _viewModel;
  String _selectedPhotoModeId = 'photo';
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
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: _buildCameraUi()),
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
      ),
    );
  }

  Widget _buildCameraUi() {
    return CameraPhotoUi(
      viewfinder: _buildViewfinder(),
      message: _message,
      aspectRatioLabel: '4:3',
      selectedModeId: _selectedPhotoModeId,
      shutterEnabled: _viewModel.canTakePicture,
      shutterBusy: _viewModel.isTakingPicture,
      onShutterPressed: _viewModel.takePicture,
      onModeSelected: (String modeId) {
        setState(() {
          _selectedPhotoModeId = modeId;
        });
      },
    );
  }

  Widget _buildViewfinder() {
    return _PreviewPanel(
      controller: _controller,
      child: _buildPreviewGestureLayer(),
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

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    final CameraController? controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _pointers != 2) {
      return;
    }

    await _viewModel.setScaledZoom(details.scale);
  }

  CameraController? get _controller => _viewModel.controller;

  String? get _message => _viewModel.message;
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.controller, required this.child});

  final CameraController? controller;
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
