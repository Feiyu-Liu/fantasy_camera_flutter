import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_ui/my_ui.dart';

import '../../../config/app_config.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/camera/camera_controller.dart';
import '../../../shared/camera/camera_preview.dart';
import '../../backend_api/domain/credit_balance.dart';
import '../../backend_api/domain/prompt_config.dart';
import '../../backend_api/presentation/backend_api_providers.dart';
import '../../generation_submission/presentation/generation_submission_modal.dart';
import '../../generation_submission/presentation/generation_submission_providers.dart';
import '../data/capture_orientation_reader.dart';
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
  int _pointers = 0;
  DeviceOrientation? _lastCaptureOrientation;
  double _controlsRotationTurns = 0;

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
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: _buildCameraUi(cameraState),
    );
  }

  Widget _buildCameraUi(CameraState cameraState) {
    final CameraControllerNotifier notifier = ref.read(
      cameraStateProvider.notifier,
    );
    final PromptSelectionState promptSelection = ref.watch(
      promptSelectionControllerProvider,
    );
    final AsyncValue<CreditBalance> creditBalance = ref.watch(
      creditBalanceProvider,
    );
    final DeviceOrientation captureOrientation =
        ref.watch(captureOrientationProvider).valueOrNull ??
        DeviceOrientation.portraitUp;
    final double controlsRotationTurns = _resolveControlsRotationTurns(
      captureOrientation,
    );
    return CameraPhotoUi(
      theme: const CameraPhotoUiTheme(
        dividerWidth: AppConfig.cameraUiDividerWidth,
      ),
      viewfinder: _buildViewfinder(cameraState),
      galleryPreview: _buildGalleryPreview(cameraState),
      trailingContent: _CreditsBalanceBadge(creditBalance: creditBalance),
      message: _localizedMessage(cameraState.message),
      controlsRotationTurns: controlsRotationTurns,
      aspectRatioLabel: '4:3',
      modes: _cameraModesForPrompt(promptSelection),
      selectedModeId: promptSelection.selectedCaptureModeId,
      modeExtensions: _cameraModeExtensionsForPrompt(promptSelection),
      zoomStops: _zoomStops(cameraState),
      currentDisplayZoom: cameraState.rawToDisplayZoom(
        cameraState.currentRawZoom,
      ),
      zoomEnabled: cameraState.canScaleZoom,
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
      onGalleryPressed: () => showGenerationSubmissionDebugModal(context),
      onZoomStopSelected: notifier.setDisplayZoom,
      onModeSelected: ref
          .read(promptSelectionControllerProvider.notifier)
          .selectCaptureMode,
    );
  }

  double _resolveControlsRotationTurns(DeviceOrientation orientation) {
    if (_lastCaptureOrientation == orientation) {
      return _controlsRotationTurns;
    }
    _lastCaptureOrientation = orientation;
    _controlsRotationTurns = shortestQuarterTurnsToTarget(
      current: _controlsRotationTurns,
      target: captureOrientationTurns(orientation),
    );
    return _controlsRotationTurns;
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
        cameraState.isFrontCamera ||
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
    if (message is CameraStartingMessage) {
      return null;
    }
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

  List<CameraZoomStop> _zoomStops(CameraState cameraState) {
    if (cameraState.isFrontCamera && cameraState.displayZoomStops.length <= 1) {
      return const <CameraZoomStop>[];
    }
    return cameraState.displayZoomStops
        .map(
          (double factor) =>
              CameraZoomStop(factor: factor, label: _zoomLabel(factor)),
        )
        .toList();
  }

  String _zoomLabel(double factor) {
    final double normalized = (factor * 10).roundToDouble() / 10;
    if (normalized == normalized.roundToDouble()) {
      return '${normalized.toInt()}x';
    }
    final String text = normalized.toStringAsFixed(1);
    if (normalized < 1 && text.startsWith('0')) {
      return '${text.substring(1)}x';
    }
    return '${text}x';
  }

  List<CameraUiMode> _cameraModesForPrompt(
    PromptSelectionState promptSelection,
  ) {
    if (promptSelection.captureModes.isEmpty) {
      return CameraPhotoUi.defaultModes;
    }
    final List<PromptCaptureModeDefinition> sortedModes =
        <PromptCaptureModeDefinition>[...promptSelection.captureModes]
          ..sort(_compareCaptureModesForCameraUi);
    return sortedModes
        .map((PromptCaptureModeDefinition mode) {
          return CameraUiMode(id: mode.id, label: mode.title.toUpperCase());
        })
        .toList(growable: false);
  }

  Map<String, List<Widget>> _cameraModeExtensionsForPrompt(
    PromptSelectionState promptSelection,
  ) {
    if (promptSelection.switches.isEmpty) {
      return const <String, List<Widget>>{};
    }
    final PromptSelectionController promptController = ref.read(
      promptSelectionControllerProvider.notifier,
    );
    return <String, List<Widget>>{
      defaultCaptureMode: <Widget>[
        for (int index = 0; index < promptSelection.switches.length; index++)
          _PromptOptionBarButton(
            key: ValueKey<String>(
              'camera-prompt-option-${promptSelection.switches[index].id}',
            ),
            definition: promptSelection.switches[index],
            selected:
                promptSelection.values[promptSelection.switches[index].id] ??
                false,
            animationIndex: index,
            onPressed: promptController.toggleSwitch,
          ),
      ],
    };
  }
}

int _compareCaptureModesForCameraUi(
  PromptCaptureModeDefinition first,
  PromptCaptureModeDefinition second,
) {
  return _captureModeSortRank(
    first.id,
  ).compareTo(_captureModeSortRank(second.id));
}

int _captureModeSortRank(String id) {
  return switch (id) {
    'general' => 0,
    defaultCaptureMode => 1,
    _ => 2,
  };
}

class _CreditsBalanceBadge extends StatelessWidget {
  const _CreditsBalanceBadge({required this.creditBalance});

  final AsyncValue<CreditBalance> creditBalance;

  @override
  Widget build(BuildContext context) {
    final String value = creditBalance.when(
      data: (CreditBalance balance) => balance.balance.toString(),
      error: (_, _) => '--',
      loading: () => '...',
    );

    return Center(
      child: Semantics(
        label: '积分 $value',
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Row(
            key: ValueKey<String>(value),
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const _CreditCoinIcon(),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    color: CupertinoColors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditCoinIcon extends StatelessWidget {
  const _CreditCoinIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      LucideIcons.tickets,
      color: CupertinoColors.black,
      size: 17,
    );
  }
}

class _PromptOptionBarButton extends StatelessWidget {
  const _PromptOptionBarButton({
    required this.definition,
    required this.selected,
    required this.animationIndex,
    required this.onPressed,
    super.key,
  });

  final PromptSwitchDefinition definition;
  final bool selected;
  final int animationIndex;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : Duration(milliseconds: 180 + animationIndex * 36),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset((1 - value) * -10, 0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Semantics(
          button: true,
          selected: selected,
          label: definition.title,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            onPressed: () {
              HapticFeedback.selectionClick();
              onPressed(definition.id);
            },
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 90),
              curve: Curves.easeOutCubic,
              height: 34,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFEAC45B)
                    : CupertinoColors.white,
                border: Border.all(
                  color: CupertinoColors.black.withValues(
                    alpha: selected ? 1 : 0.72,
                  ),
                  width: AppConfig.cameraUiDividerWidth,
                ),
                borderRadius: BorderRadius.zero,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      definition.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        color: CupertinoColors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Icon(
                      _promptOptionIcon(definition.id),
                      color: CupertinoColors.black,
                      size: 15,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _promptOptionIcon(String id) {
  return switch (id) {
    'recompose' => LucideIcons.wandSparkles,
    'beautifyFace' => LucideIcons.userRoundCheck,
    'cleanFrame' => LucideIcons.sparkles,
    'backgroundBlur' => LucideIcons.aperture,
    _ => LucideIcons.slidersHorizontal,
  };
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
          child: CupertinoActivityIndicator(color: CupertinoColors.white),
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
        color: CupertinoColors.black,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (initialized)
              _CoveredCameraPreview(controller: cameraController!),
            IgnorePointer(
              child: FadeTransition(
                opacity: _overlayOpacity,
                child: const ColoredBox(color: CupertinoColors.black),
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
