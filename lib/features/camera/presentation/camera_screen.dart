import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_ui/my_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/camera/camera_controller.dart';
import '../../../shared/camera/camera_preview.dart';
import 'camera_message.dart';
import 'camera_providers.dart';
import 'camera_state.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  String _selectedPhotoModeId = 'photo';
  int _pointers = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(cameraStateProvider.notifier).openDefaultCamera());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(
      ref.read(cameraStateProvider.notifier).handleAppLifecycleState(state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CameraState cameraState = ref.watch(cameraStateProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildCameraUi(cameraState),
    );
  }

  Widget _buildCameraUi(CameraState cameraState) {
    final CameraControllerNotifier notifier = ref.read(
      cameraStateProvider.notifier,
    );
    return CameraPhotoUi(
      viewfinder: _buildViewfinder(cameraState),
      galleryPreview: _buildGalleryPreview(cameraState),
      message: _localizedMessage(cameraState.message),
      aspectRatioLabel: '4:3',
      selectedModeId: _selectedPhotoModeId,
      shutterEnabled: cameraState.canShowShutter,
      shutterBusy: false,
      flashMode: _flashUiMode(cameraState),
      flashEnabled: cameraState.canToggleFlash,
      flashBusy: cameraState.isTogglingFlash,
      cameraFacing: _cameraFacingUi(cameraState.currentLensDirection),
      flipEnabled: _canFlipCamera(cameraState),
      flipBusy: cameraState.isSwitchingCamera,
      onFlashPressed: notifier.toggleFlash,
      onFlipCameraPressed: notifier.flipCamera,
      onShutterPressed: notifier.takePicture,
      onModeSelected: (String modeId) {
        setState(() {
          _selectedPhotoModeId = modeId;
        });
      },
    );
  }

  Widget _buildViewfinder(CameraState cameraState) {
    return _PreviewPanel(
      controller: cameraState.controller,
      captureOverlayTrigger: cameraState.captureOverlayTrigger,
      child: _buildPreviewGestureLayer(cameraState),
    );
  }

  Widget _buildPreviewGestureLayer(CameraState cameraState) {
    final CameraController? controller = cameraState.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Listener(
      onPointerDown: (_) => _pointers++,
      onPointerUp: (_) => _pointers = (_pointers - 1).clamp(0, 10),
      onPointerCancel: (_) => _pointers = (_pointers - 1).clamp(0, 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (_) =>
            ref.read(cameraStateProvider.notifier).handleScaleStart(),
        onScaleUpdate: _handleScaleUpdate,
      ),
    );
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    final CameraState cameraState = ref.read(cameraStateProvider);
    final CameraController? controller = cameraState.controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _pointers != 2) {
      return;
    }

    await ref.read(cameraStateProvider.notifier).setScaledZoom(details.scale);
  }

  Widget? _buildGalleryPreview(CameraState cameraState) {
    if (cameraState.isTakingPicture) {
      return const _CaptureProgressThumbnail();
    }

    final String? path = cameraState.lastCapturedFile?.path;
    if (path == null || path.isEmpty) {
      return null;
    }

    return Image.file(File(path), fit: BoxFit.cover);
  }

  String? _localizedMessage(CameraMessage? message) {
    return message?.localize(context.l10n);
  }

  bool _canFlipCamera(CameraState cameraState) {
    if (!cameraState.canFlipCamera) {
      return false;
    }
    final CameraLensDirection? currentDirection =
        cameraState.currentLensDirection;
    if (currentDirection == null) {
      return false;
    }
    final bool hasOppositeDirection = ref
        .watch(cameraChoicesProvider)
        .any(
          (choice) =>
              choice.description.lensDirection != currentDirection &&
              (choice.description.lensDirection == CameraLensDirection.front ||
                  choice.description.lensDirection == CameraLensDirection.back),
        );
    return hasOppositeDirection;
  }

  CameraFlashUiMode _flashUiMode(CameraState cameraState) {
    if (cameraState.currentLensDirection == CameraLensDirection.front) {
      return CameraFlashUiMode.unavailable;
    }
    return cameraState.flashMode == FlashMode.off
        ? CameraFlashUiMode.off
        : CameraFlashUiMode.on;
  }

  CameraFacingUi _cameraFacingUi(CameraLensDirection? lensDirection) {
    return switch (lensDirection) {
      CameraLensDirection.back => CameraFacingUi.rear,
      CameraLensDirection.front => CameraFacingUi.front,
      CameraLensDirection.external || null => CameraFacingUi.unknown,
    };
  }
}

class _CaptureProgressThumbnail extends StatelessWidget {
  const _CaptureProgressThumbnail();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF111111),
      child: Center(
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      ),
    );
  }
}

class _PreviewPanel extends StatefulWidget {
  const _PreviewPanel({
    required this.controller,
    required this.captureOverlayTrigger,
    required this.child,
  });

  final CameraController? controller;
  final int captureOverlayTrigger;
  final Widget child;

  @override
  State<_PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<_PreviewPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _overlayController;
  late final Animation<double> _overlayOpacity;
  int _lastCaptureOverlayTrigger = 0;

  @override
  void initState() {
    super.initState();
    _lastCaptureOverlayTrigger = widget.captureOverlayTrigger;
    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _overlayOpacity = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInQuart)),
        weight: 30,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 70,
      ),
    ]).animate(_overlayController);
  }

  @override
  void didUpdateWidget(covariant _PreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.captureOverlayTrigger != _lastCaptureOverlayTrigger) {
      _lastCaptureOverlayTrigger = widget.captureOverlayTrigger;
      _overlayController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _overlayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? cameraController = widget.controller;
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
            IgnorePointer(
              child: FadeTransition(
                opacity: _overlayOpacity,
                child: const ColoredBox(color: Colors.black),
              ),
            ),
            widget.child,
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
