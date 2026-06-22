import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_router.dart';
import '../../../config/app_config.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/camera/camera_controller.dart';
import '../../../shared/camera/camera_preview.dart';
import '../../../shared/core/app_logger.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../backend_api/domain/credit_balance.dart';
import '../../backend_api/domain/prompt_config.dart';
import '../../backend_api/presentation/backend_api_providers.dart';
import '../../generation_submission/domain/generation_submission_job.dart';
import '../../generation_submission/presentation/generation_submission_providers.dart';
import '../data/capture_orientation_reader.dart';
import 'camera_ui/camera_photo_option_button.dart';
import 'camera_ui/camera_photo_ui.dart';
import 'camera_message.dart';
import 'camera_ui/camera_ui_models.dart';
import 'camera_ui/camera_ui_tokens.dart';
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
  Offset? _focusIndicatorPosition;
  int _focusIndicatorTrigger = 0;
  DeviceOrientation? _lastCaptureOrientation;
  double _controlsRotationTurns = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_resumeActiveGenerationRecords());
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

  Future<void> _resumeActiveGenerationRecords() async {
    try {
      await ref
          .read(generationSubmissionControllerProvider.notifier)
          .resumeActiveRecords();
    } on Object catch (error, stackTrace) {
      logAppError('generation_resume_active_records_failed', error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CameraState cameraState = ref.watch(cameraStateProvider);
    final AppThemeColors colors = AppThemeColors.of(context);
    return CupertinoPageScaffold(
      backgroundColor: colors.cameraBackground,
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
    final PromptSelectionState localizedPromptSelection = _localizedPromptState(
      promptSelection,
    );
    final AsyncValue<CreditBalance> creditBalance = ref.watch(
      creditBalanceProvider,
    );
    final GenerationSubmissionJob? latestGenerationJob = ref
        .watch(generationSubmissionControllerProvider)
        .latestJob;
    final DeviceOrientation captureOrientation =
        ref.watch(captureOrientationProvider).valueOrNull ??
        DeviceOrientation.portraitUp;
    final double controlsRotationTurns = _resolveControlsRotationTurns(
      captureOrientation,
    );
    final CameraUiTokens tokens = CameraUiTokens.forTheme(
      context,
      dividerWidth: AppConfig.cameraUiDividerWidth,
    );
    return CameraPhotoUi(
      tokens: tokens,
      viewfinder: _buildViewfinder(cameraState),
      galleryPreview: _buildGalleryPreview(cameraState, latestGenerationJob),
      leadingContent: _CameraSettingsButton(
        tokens: tokens,
        onPressed: _openSettings,
      ),
      trailingContent: _CameraTopRightActions(
        tokens: tokens,
        creditBalance: creditBalance,
        onCreditsPressed: _openCreditPurchase,
      ),
      message: _localizedMessage(cameraState.message),
      controlsRotationTurns: controlsRotationTurns,
      aspectRatioLabel: '4:3',
      promptOptions: _cameraPromptOptions(localizedPromptSelection, tokens),
      zoomStops: _zoomStops(cameraState),
      currentDisplayZoom: cameraState.rawToDisplayZoom(
        cameraState.currentRawZoom,
      ),
      zoomEnabled: cameraState.canScaleZoom,
      galleryEnabled: !cameraState.isTakingPicture,
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
      onGalleryPressed: _openGallery,
      onZoomStopSelected: notifier.setDisplayZoom,
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

  Future<void> _openGallery() async {
    final CameraControllerNotifier notifier = ref.read(
      cameraStateProvider.notifier,
    );
    notifier.suspendLifecycleCameraResume();
    try {
      await notifier.pauseCamera();
      if (!mounted) {
        return;
      }
      await context.push(generationGalleryRoute);
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        notifier.resumeLifecycleCameraResume();
      }
    }
    await notifier.openDefaultCamera();
  }

  Future<void> _openSettings() async {
    await _pushRouteWithPausedCamera(settingsRoute);
  }

  Future<void> _openCreditPurchase() async {
    await _pushRouteWithPausedCamera(creditPurchaseRoute);
  }

  Future<void> _pushRouteWithPausedCamera(String route) async {
    final CameraControllerNotifier notifier = ref.read(
      cameraStateProvider.notifier,
    );
    notifier.suspendLifecycleCameraResume();
    try {
      final CameraState cameraState = ref.read(cameraStateProvider);
      if (cameraState.controller != null) {
        await notifier.pauseCamera();
      }
      if (!mounted) {
        return;
      }
      await context.push(route);
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        notifier.resumeLifecycleCameraResume();
      }
    }
    await notifier.openDefaultCamera();
  }

  Widget _buildViewfinder(CameraState cameraState) {
    return _PreviewPanel(
      controller: cameraState.controller,
      captureOverlayTrigger: cameraState.captureOverlayTrigger,
      focusIndicatorPosition: _focusIndicatorPosition,
      focusIndicatorTrigger: _focusIndicatorTrigger,
      child: _buildPreviewGestureLayer(cameraState),
    );
  }

  Widget _buildPreviewGestureLayer(CameraState cameraState) {
    final CameraController? controller = cameraState.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Listener(
          onPointerDown: (_) => _pointers++,
          onPointerUp: (_) => _pointers = (_pointers - 1).clamp(0, 10),
          onPointerCancel: (_) => _pointers = (_pointers - 1).clamp(0, 10),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) =>
                ref.read(cameraStateProvider.notifier).handleScaleStart(),
            onScaleUpdate: _handleScaleUpdate,
            onTapDown: (TapDownDetails details) =>
                _handlePreviewTapDown(details, constraints.biggest, controller),
          ),
        );
      },
    );
  }

  Future<void> _handlePreviewTapDown(
    TapDownDetails details,
    Size panelSize,
    CameraController controller,
  ) async {
    if (_pointers > 1) {
      return;
    }

    if (panelSize.isEmpty) {
      return;
    }

    final Offset localPosition = details.localPosition;
    setState(() {
      _focusIndicatorPosition = localPosition;
      _focusIndicatorTrigger += 1;
    });

    final Point<double>? focusPoint = cameraPreviewPointForTap(
      tapPosition: localPosition,
      containerSize: panelSize,
      previewSize: controller.value.previewSize,
    );
    if (focusPoint == null) {
      return;
    }

    await ref.read(cameraStateProvider.notifier).focusAndExposeAt(focusPoint);
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

  Widget? _buildGalleryPreview(
    CameraState cameraState,
    GenerationSubmissionJob? latestGenerationJob,
  ) {
    if (cameraState.isTakingPicture) {
      return const _CaptureProgressThumbnail();
    }

    final String? path = _galleryPreviewPath(latestGenerationJob);
    if (path == null || path.isEmpty) {
      return null;
    }

    return Image.file(
      File(path),
      key: ValueKey<String>('camera-gallery-preview-$path'),
      fit: BoxFit.cover,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        debugPrint(
          '[CameraScreen] gallery preview image load failure path=$path error=$error',
        );
        return const _MissingGalleryPreviewThumbnail();
      },
    );
  }

  String? _galleryPreviewPath(GenerationSubmissionJob? latestGenerationJob) {
    if (latestGenerationJob == null) {
      return null;
    }
    if (latestGenerationJob.status == GenerationSubmissionStatus.resultSaved &&
        latestGenerationJob.processedResultPath != null) {
      return latestGenerationJob.processedResultPath;
    }
    return latestGenerationJob.imagePath;
  }

  String? _localizedMessage(CameraMessage? message) {
    if (message is CameraStartingMessage) {
      return null;
    }
    return message?.localize(context.l10n);
  }

  PromptSelectionState _localizedPromptState(PromptSelectionState state) {
    final AppLocalizations l10n = context.l10n;
    final List<PromptStyleDefinition> styles = localizedPromptStyles(
      state.styles,
      styleTitle: (String id, String fallback) {
        return switch (id) {
          defaultPromptStyle => l10n.promptStyleRealisticTitle,
          _ => fallback,
        };
      },
      captureModeTitle: (String id, String fallback) {
        return switch (id) {
          defaultCaptureMode => l10n.promptCaptureModePortraitTitle,
          'general' => l10n.promptCaptureModeGeneralTitle,
          _ => fallback,
        };
      },
      switchTitle: (String id, String fallback) {
        return switch (id) {
          'recompose' => l10n.promptSwitchRecomposeTitle,
          'beautifyFace' => l10n.promptSwitchBeautifyFaceTitle,
          'cleanFrame' => l10n.promptSwitchCleanFrameTitle,
          'backgroundBlur' => l10n.promptSwitchBackgroundBlurTitle,
          _ => fallback,
        };
      },
    );
    return state.copyWith(
      styles: styles,
      switches: promptSwitchesForDefinitions(
        styles,
        promptStyle: state.selectedPromptStyleId,
        captureMode: defaultCaptureMode,
      ),
      selectedCaptureModeId: defaultCaptureMode,
    );
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

  List<Widget> _cameraPromptOptions(
    PromptSelectionState promptSelection,
    CameraUiTokens tokens,
  ) {
    if (promptSelection.switches.isEmpty) {
      return const <Widget>[];
    }
    final PromptSelectionController promptController = ref.read(
      promptSelectionControllerProvider.notifier,
    );
    return <Widget>[
      for (int index = 0; index < promptSelection.switches.length; index++)
        CameraPhotoOptionButton(
          key: ValueKey<String>(
            'camera-prompt-option-${promptSelection.switches[index].id}',
          ),
          tokens: tokens,
          label: promptSelection.switches[index].title,
          icon: _promptOptionIcon(promptSelection.switches[index].id),
          selected:
              promptSelection.values[promptSelection.switches[index].id] ??
              false,
          animationIndex: index,
          onPressed: () {
            promptController.toggleSwitch(promptSelection.switches[index].id);
          },
        ),
    ];
  }
}

class _CreditsBalanceBadge extends StatelessWidget {
  const _CreditsBalanceBadge({
    required this.tokens,
    required this.creditBalance,
    required this.onPressed,
  });

  final CameraUiTokens tokens;
  final AsyncValue<CreditBalance> creditBalance;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final String value = creditBalance.when(
      data: (CreditBalance balance) => balance.balance.toString(),
      error: (_, _) => '--',
      loading: () => '...',
    );

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      child: Center(
        child: Semantics(
          button: true,
          label: context.l10n.cameraCreditsBalanceSemanticsLabel(value),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Row(
              key: ValueKey<String>(value),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _CreditCoinIcon(color: tokens.primaryTextColor),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: tokens.primaryTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraTopRightActions extends StatelessWidget {
  const _CameraTopRightActions({
    required this.tokens,
    required this.creditBalance,
    required this.onCreditsPressed,
  });

  final CameraUiTokens tokens;
  final AsyncValue<CreditBalance> creditBalance;
  final VoidCallback onCreditsPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _CreditsBalanceBadge(
            tokens: tokens,
            creditBalance: creditBalance,
            onPressed: onCreditsPressed,
          ),
        ),
      ],
    );
  }
}

class _CameraSettingsButton extends StatelessWidget {
  const _CameraSettingsButton({required this.tokens, required this.onPressed});

  final CameraUiTokens tokens;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Settings',
      child: CupertinoButton(
        key: const ValueKey<String>('camera-settings-button'),
        padding: EdgeInsets.zero,
        minimumSize: const Size(34, 44),
        onPressed: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        child: SizedBox(
          width: 34,
          height: 44,
          child: Center(
            child: Icon(
              LucideIcons.settings,
              color: tokens.primaryTextColor,
              size: 19,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreditCoinIcon extends StatelessWidget {
  const _CreditCoinIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(LucideIcons.tickets, color: color, size: 17);
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
      color: AppColors.darkSurface,
      child: Center(
        child: SizedBox.square(
          dimension: 18,
          child: CupertinoActivityIndicator(color: AppColors.white),
        ),
      ),
    );
  }
}

class _MissingGalleryPreviewThumbnail extends StatelessWidget {
  const _MissingGalleryPreviewThumbnail();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.darkSurface,
      child: Center(
        child: Icon(
          LucideIcons.image,
          color: AppColors.secondaryLabel.resolveFrom(context),
          size: 20,
        ),
      ),
    );
  }
}

class _PreviewPanel extends StatefulWidget {
  const _PreviewPanel({
    required this.controller,
    required this.captureOverlayTrigger,
    required this.focusIndicatorPosition,
    required this.focusIndicatorTrigger,
    required this.child,
  });

  final CameraController? controller;
  final int captureOverlayTrigger;
  final Offset? focusIndicatorPosition;
  final int focusIndicatorTrigger;
  final Widget child;

  @override
  State<_PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends State<_PreviewPanel>
    with TickerProviderStateMixin {
  late final AnimationController _overlayController;
  late final AnimationController _focusController;
  late final Animation<double> _overlayOpacity;
  late final Animation<double> _focusOpacity;
  late final Animation<double> _focusScale;
  int _lastCaptureOverlayTrigger = 0;
  int _lastFocusIndicatorTrigger = 0;

  @override
  void initState() {
    super.initState();
    _lastCaptureOverlayTrigger = widget.captureOverlayTrigger;
    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
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
    _focusOpacity = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
      TweenSequenceItem<double>(tween: ConstantTween<double>(1.0), weight: 34),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 48,
      ),
    ]).animate(_focusController);
    _focusScale = Tween<double>(
      begin: 1.18,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeOutBack)).animate(_focusController);
  }

  @override
  void didUpdateWidget(covariant _PreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.captureOverlayTrigger != _lastCaptureOverlayTrigger) {
      _lastCaptureOverlayTrigger = widget.captureOverlayTrigger;
      _overlayController.forward(from: 0.0);
    }
    if (widget.focusIndicatorTrigger != _lastFocusIndicatorTrigger) {
      _lastFocusIndicatorTrigger = widget.focusIndicatorTrigger;
      _focusController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _overlayController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? cameraController = widget.controller;
    final bool initialized = cameraController?.value.isInitialized ?? false;
    return ClipRect(
      child: ColoredBox(
        color: AppColors.black,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (initialized)
              _CoveredCameraPreview(controller: cameraController!),
            IgnorePointer(
              child: FadeTransition(
                opacity: _overlayOpacity,
                child: const ColoredBox(color: AppColors.black),
              ),
            ),
            if (widget.focusIndicatorPosition != null)
              _FocusIndicator(
                position: widget.focusIndicatorPosition!,
                opacity: _focusOpacity,
                scale: _focusScale,
              ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
Point<double>? cameraPreviewPointForTap({
  required Offset tapPosition,
  required Size containerSize,
  required Size? previewSize,
}) {
  if (containerSize.isEmpty || previewSize == null || previewSize.isEmpty) {
    return null;
  }

  final double cameraAspectRatio = previewSize.width / previewSize.height;
  final Size previewChildSize = Size(1 / cameraAspectRatio, 1);
  final double scale = max(
    containerSize.width / previewChildSize.width,
    containerSize.height / previewChildSize.height,
  );
  final Size fittedPreviewSize = previewChildSize * scale;
  final Offset previewOffset = Offset(
    (containerSize.width - fittedPreviewSize.width) / 2,
    (containerSize.height - fittedPreviewSize.height) / 2,
  );
  final Offset previewPosition = tapPosition - previewOffset;
  return Point<double>(
    (previewPosition.dx / fittedPreviewSize.width).clamp(0.0, 1.0),
    (previewPosition.dy / fittedPreviewSize.height).clamp(0.0, 1.0),
  );
}

class _FocusIndicator extends StatelessWidget {
  const _FocusIndicator({
    required this.position,
    required this.opacity,
    required this.scale,
  });

  static const double _size = 68;

  final Offset position;
  final Animation<double> opacity;
  final Animation<double> scale;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - _size / 2,
      top: position.dy - _size / 2,
      width: _size,
      height: _size,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: opacity,
          child: ScaleTransition(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppThemeColors.of(context).accentYellow,
                  width: 1.8,
                ),
              ),
            ),
          ),
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
