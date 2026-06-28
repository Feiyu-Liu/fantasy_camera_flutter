import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:smooth_corner/smooth_corner.dart';

import 'camera_ui_models.dart';
import 'camera_ui_tokens.dart';
import '../../../../theme/app_corners.dart';
import '../../../../theme/app_colors.dart';

enum CameraGalleryBadgeStatus { none, success, failure }

class CameraPhotoUi extends StatelessWidget {
  const CameraPhotoUi({
    super.key,
    this.tokens = const CameraUiTokens(),
    this.viewfinder,
    this.galleryPreview,
    this.message,
    this.modes = const <CameraUiMode>[],
    this.selectedModeId,
    this.modeExtensions = const <String, List<Widget>>{},
    this.zoomStops = const <CameraZoomStop>[],
    this.currentDisplayZoom = 1.0,
    this.controlsRotationTurns = 0,
    this.zoomEnabled = true,
    this.galleryEnabled = true,
    this.galleryBadgeStatus = CameraGalleryBadgeStatus.none,
    this.shutterEnabled = true,
    this.shutterBusy = false,
    this.flashMode = CameraFlashUiMode.off,
    this.flashEnabled = true,
    this.flashBusy = false,
    this.cameraFacing = CameraFacingUi.unknown,
    this.flipEnabled = true,
    this.flipBusy = false,
    this.onFlashPressed,
    this.onTimerPressed,
    this.onBrightnessPressed,
    this.leadingContent,
    this.trailingContent,
    this.trailingIcon = LucideIcons.images,
    this.trailingTooltip = 'Switch UI',
    this.onShutterPressed,
    this.onFlipCameraPressed,
    this.onGalleryPressed,
    this.onTrailingPressed,
    this.onModeSelected,
    this.onZoomStopSelected,
    this.onZoomDragStart,
    this.onZoomDragUpdate,
    this.onZoomDragEnd,
  });

  final CameraUiTokens tokens;
  final Widget? viewfinder;
  final Widget? galleryPreview;
  final String? message;
  final List<CameraUiMode> modes;
  final String? selectedModeId;
  final Map<String, List<Widget>> modeExtensions;
  final List<CameraZoomStop> zoomStops;
  final double currentDisplayZoom;
  final double controlsRotationTurns;
  final bool zoomEnabled;
  final bool galleryEnabled;
  final CameraGalleryBadgeStatus galleryBadgeStatus;
  final bool shutterEnabled;
  final bool shutterBusy;
  final CameraFlashUiMode flashMode;
  final bool flashEnabled;
  final bool flashBusy;
  final CameraFacingUi cameraFacing;
  final bool flipEnabled;
  final bool flipBusy;
  final VoidCallback? onFlashPressed;
  final VoidCallback? onTimerPressed;
  final VoidCallback? onBrightnessPressed;
  final Widget? leadingContent;
  final Widget? trailingContent;
  final IconData trailingIcon;
  final String trailingTooltip;
  final VoidCallback? onShutterPressed;
  final VoidCallback? onFlipCameraPressed;
  final VoidCallback? onGalleryPressed;
  final VoidCallback? onTrailingPressed;
  final ValueChanged<String>? onModeSelected;
  final ValueChanged<double>? onZoomStopSelected;
  final VoidCallback? onZoomDragStart;
  final ValueChanged<double>? onZoomDragUpdate;
  final ValueChanged<double>? onZoomDragEnd;

  @override
  Widget build(BuildContext context) {
    final String? selectedMode = selectedModeId;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: tokens.backgroundColor,
      child: Column(
        children: <Widget>[
          CameraPhotoTopBar(
            tokens: tokens,
            flashMode: flashMode,
            flashEnabled: flashEnabled,
            flashBusy: flashBusy,
            onFlashPressed: onFlashPressed,
            onTimerPressed: onTimerPressed,
            onBrightnessPressed: onBrightnessPressed,
            leadingContent: leadingContent,
            trailingIcon: trailingIcon,
            trailingTooltip: trailingTooltip,
            trailingContent: trailingContent,
            controlsRotationTurns: controlsRotationTurns,
            onTrailingPressed: onTrailingPressed,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double viewfinderHeight = constraints.maxWidth * 4 / 3;

                return Column(
                  children: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      height: viewfinderHeight,
                      child: CameraPhotoViewfinder(
                        tokens: tokens,
                        viewfinder: viewfinder,
                        message: message,
                        zoomStops: zoomStops,
                        currentDisplayZoom: currentDisplayZoom,
                        controlsRotationTurns: controlsRotationTurns,
                        zoomEnabled: zoomEnabled,
                        onZoomStopSelected: onZoomStopSelected,
                        onZoomDragStart: onZoomDragStart,
                        onZoomDragUpdate: onZoomDragUpdate,
                        onZoomDragEnd: onZoomDragEnd,
                      ),
                    ),
                    Expanded(
                      child: CameraPhotoModeExpansionMotion(
                        tokens: tokens,
                        modes: modes,
                        selectedModeId: selectedMode,
                        modeExtensions: modeExtensions,
                        reduceMotion: reduceMotion,
                        onModeSelected: onModeSelected,
                        bottomControls: CameraPhotoBottomControls(
                          tokens: tokens,
                          galleryPreview: galleryPreview,
                          controlsRotationTurns: controlsRotationTurns,
                          galleryEnabled: galleryEnabled,
                          galleryBadgeStatus: galleryBadgeStatus,
                          shutterEnabled: shutterEnabled,
                          shutterBusy: shutterBusy,
                          cameraFacing: cameraFacing,
                          flipEnabled: flipEnabled,
                          flipBusy: flipBusy,
                          onGalleryPressed: onGalleryPressed,
                          onShutterPressed: onShutterPressed,
                          onFlipCameraPressed: onFlipCameraPressed,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CameraPhotoTopBar extends StatelessWidget {
  const CameraPhotoTopBar({
    required this.tokens,
    super.key,
    this.flashMode = CameraFlashUiMode.off,
    this.flashEnabled = true,
    this.flashBusy = false,
    this.onFlashPressed,
    this.onTimerPressed,
    this.onBrightnessPressed,
    this.leadingContent,
    this.trailingContent,
    this.trailingIcon = LucideIcons.images,
    this.trailingTooltip = 'Switch UI',
    this.controlsRotationTurns = 0,
    this.onTrailingPressed,
  });

  final CameraUiTokens tokens;
  final CameraFlashUiMode flashMode;
  final bool flashEnabled;
  final bool flashBusy;
  final VoidCallback? onFlashPressed;
  final VoidCallback? onTimerPressed;
  final VoidCallback? onBrightnessPressed;
  final Widget? leadingContent;
  final Widget? trailingContent;
  final IconData trailingIcon;
  final String trailingTooltip;
  final double controlsRotationTurns;
  final VoidCallback? onTrailingPressed;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: tokens.backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: tokens.topBarHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: tokens.dividerColor,
                width: tokens.dividerWidth,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: tokens.topBarButtonSize,
                child: _TopBarSlot(
                  tokens: tokens,
                  borderRight: true,
                  child: leadingContent ?? const SizedBox.shrink(),
                ),
              ),
              SizedBox(
                width: tokens.topBarButtonSize,
                child: _TopBarSlot(
                  tokens: tokens,
                  borderRight: true,
                  child: CameraPhotoFlashButton(
                    tokens: tokens,
                    mode: flashMode,
                    enabled: flashEnabled,
                    busy: flashBusy,
                    rotationTurns: controlsRotationTurns,
                    onPressed: onFlashPressed,
                  ),
                ),
              ),
              const Spacer(flex: 5),
              SizedBox(
                width: tokens.topBarTrailingWidth,
                child: _TopBarSlot(
                  tokens: tokens,
                  borderLeft: true,
                  child:
                      trailingContent ??
                      _TopBarButton(
                        tokens: tokens,
                        icon: trailingIcon,
                        rotationTurns: controlsRotationTurns,
                        onPressed: onTrailingPressed ?? onBrightnessPressed,
                        tooltip: trailingTooltip,
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

class CameraPhotoViewfinder extends StatelessWidget {
  const CameraPhotoViewfinder({
    required this.tokens,
    super.key,
    this.viewfinder,
    this.message,
    this.zoomStops = const <CameraZoomStop>[],
    this.currentDisplayZoom = 1.0,
    this.controlsRotationTurns = 0,
    this.zoomEnabled = true,
    this.onZoomStopSelected,
    this.onZoomDragStart,
    this.onZoomDragUpdate,
    this.onZoomDragEnd,
  });

  final CameraUiTokens tokens;
  final Widget? viewfinder;
  final String? message;
  final List<CameraZoomStop> zoomStops;
  final double currentDisplayZoom;
  final double controlsRotationTurns;
  final bool zoomEnabled;
  final ValueChanged<double>? onZoomStopSelected;
  final VoidCallback? onZoomDragStart;
  final ValueChanged<double>? onZoomDragUpdate;
  final ValueChanged<double>? onZoomDragEnd;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: tokens.viewfinderColor,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ?viewfinder,
          if (message != null)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: tokens.viewfinderMessageMargin,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.viewfinderColor.withValues(
                      alpha: tokens.viewfinderMessageOverlayOpacity,
                    ),
                    borderRadius: BorderRadius.circular(
                      tokens.viewfinderMessageRadius,
                    ),
                  ),
                  child: Padding(
                    padding: tokens.viewfinderMessagePadding,
                    child: Text(
                      message!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: tokens.viewfinderMessageTextStyle.copyWith(
                        color: tokens.inverseTextColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (zoomStops.isNotEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: tokens.zoomSafeAreaPadding,
                  child: CameraPhotoZoomSlider(
                    tokens: tokens,
                    stops: zoomStops,
                    currentDisplayZoom: currentDisplayZoom,
                    rotationTurns: controlsRotationTurns,
                    enabled: zoomEnabled,
                    onStopSelected: onZoomStopSelected,
                    onDragStart: onZoomDragStart,
                    onDragUpdate: onZoomDragUpdate,
                    onDragEnd: onZoomDragEnd,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CameraPhotoZoomSlider extends StatefulWidget {
  const CameraPhotoZoomSlider({
    required this.tokens,
    required this.stops,
    required this.currentDisplayZoom,
    super.key,
    this.rotationTurns = 0,
    this.enabled = true,
    this.onStopSelected,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final CameraUiTokens tokens;
  final List<CameraZoomStop> stops;
  final double currentDisplayZoom;
  final double rotationTurns;
  final bool enabled;
  final ValueChanged<double>? onStopSelected;
  final VoidCallback? onDragStart;
  final ValueChanged<double>? onDragUpdate;
  final ValueChanged<double>? onDragEnd;

  @override
  State<CameraPhotoZoomSlider> createState() => _CameraPhotoZoomSliderState();
}

class _CameraPhotoZoomSliderState extends State<CameraPhotoZoomSlider> {
  bool _isDragging = false;
  bool _isPressed = false;
  double? _dragLeft;

  bool get _canInteract =>
      widget.enabled &&
      widget.stops.length > 1 &&
      widget.onStopSelected != null;

  @override
  void didUpdateWidget(covariant CameraPhotoZoomSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging &&
        oldWidget.currentDisplayZoom != widget.currentDisplayZoom) {
      _dragLeft = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<CameraZoomStop> sortedStops = _sortedStops();
    if (sortedStops.isEmpty) {
      return const SizedBox.shrink();
    }
    final int currentIndex = _reachedStopIndex(
      widget.currentDisplayZoom,
      sortedStops,
    );
    final double? nextStopFactor = currentIndex < sortedStops.length - 1
        ? sortedStops[currentIndex + 1].factor
        : null;

    return SizedBox(
      width: _trackWidthFor(sortedStops.length, widget.tokens),
      height: widget.tokens.zoomTrackHeight,
      child: Opacity(
        opacity: widget.enabled ? 1.0 : widget.tokens.zoomDisabledOpacity,
        child: _CameraPhotoZoomPillTrack(
          tokens: widget.tokens,
          stops: sortedStops,
          currentIndex: currentIndex,
          currentZoomLabel: _zoomLabel(
            widget.currentDisplayZoom,
            nextStopFactor: nextStopFactor,
          ),
          isDragging: _isDragging,
          isPressed: _isPressed,
          rotationTurns: widget.rotationTurns,
          dragLeft: _dragLeft,
          onStopSelected: _canInteract
              ? (int index) {
                  HapticFeedback.selectionClick();
                  widget.onStopSelected!(sortedStops[index].factor);
                }
              : null,
          onDragStart: _handleDragStart,
          onDragUpdate: _handleDragUpdate,
          onDragEnd: () => _handleDragEnd(sortedStops),
          onDragCancel: _handleDragCancel,
          onPressedChanged: _handlePressedChanged,
        ),
      ),
    );
  }

  List<CameraZoomStop> _sortedStops() {
    final List<CameraZoomStop> normalized =
        widget.stops
            .where(
              (CameraZoomStop stop) => stop.factor.isFinite && stop.factor > 0,
            )
            .toList()
          ..sort(
            (CameraZoomStop first, CameraZoomStop second) =>
                first.factor.compareTo(second.factor),
          );
    return normalized;
  }

  void _handlePressedChanged(bool pressed) {
    if (_isPressed == pressed || _isDragging) {
      return;
    }
    setState(() {
      _isPressed = pressed;
    });
  }

  void _handleDragStart(double initialLeft) {
    setState(() {
      _isDragging = true;
      _isPressed = true;
      _dragLeft = initialLeft;
    });
  }

  void _handleDragUpdate(double delta, double maxLeft) {
    if (!_isDragging) {
      return;
    }
    setState(() {
      _dragLeft = (_dragLeft ?? 0) + delta;
      _dragLeft = _dragLeft!.clamp(0.0, maxLeft).toDouble();
    });
  }

  void _handleDragEnd(List<CameraZoomStop> sortedStops) {
    final int currentIndex = _reachedStopIndex(
      widget.currentDisplayZoom,
      sortedStops,
    );
    final double resolvedLeft = _dragLeft ?? currentIndex.toDouble();
    final int targetIndex = _indexFromDragLeft(
      resolvedLeft,
      sortedStops.length,
    );
    setState(() {
      _isDragging = false;
      _isPressed = false;
      _dragLeft = null;
    });

    if (_canInteract && sortedStops.isNotEmpty) {
      final int safeIndex = targetIndex.clamp(0, sortedStops.length - 1);
      HapticFeedback.selectionClick();
      widget.onStopSelected!(sortedStops[safeIndex].factor);
    }
  }

  void _handleDragCancel() {
    setState(() {
      _isDragging = false;
      _isPressed = false;
      _dragLeft = null;
    });
  }

  static int _reachedStopIndex(double zoom, List<CameraZoomStop> stops) {
    int reachedIndex = 0;
    for (int index = 0; index < stops.length; index++) {
      if (zoom >= stops[index].factor) {
        reachedIndex = index;
      } else {
        break;
      }
    }
    return reachedIndex;
  }

  static int _indexFromDragLeft(double left, int itemCount) {
    if (itemCount <= 0) {
      return 0;
    }
    return left.round().clamp(0, itemCount - 1);
  }

  static double _trackWidthFor(int itemCount, CameraUiTokens tokens) {
    return (itemCount * tokens.zoomTrackItemWidth)
        .clamp(tokens.zoomTrackMinWidth, tokens.zoomTrackMaxWidth)
        .toDouble();
  }

  static String _zoomLabel(double factor, {double? nextStopFactor}) {
    double normalized = (factor * 10).roundToDouble() / 10;
    if (nextStopFactor != null &&
        factor < nextStopFactor &&
        normalized >= nextStopFactor) {
      normalized = (factor * 10).floorToDouble() / 10;
    }
    if (normalized == normalized.roundToDouble()) {
      return '${normalized.toInt()}x';
    }
    final String text = normalized.toStringAsFixed(1);
    if (normalized < 1 && text.startsWith('0')) {
      return '${text.substring(1)}x';
    }
    return '${text}x';
  }
}

class _CameraPhotoZoomPillTrack extends StatelessWidget {
  const _CameraPhotoZoomPillTrack({
    required this.tokens,
    required this.stops,
    required this.currentIndex,
    required this.currentZoomLabel,
    required this.isDragging,
    required this.isPressed,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.onPressedChanged,
    this.rotationTurns = 0,
    this.dragLeft,
    this.onStopSelected,
  });

  final CameraUiTokens tokens;
  final List<CameraZoomStop> stops;
  final int currentIndex;
  final String currentZoomLabel;
  final bool isDragging;
  final bool isPressed;
  final double rotationTurns;
  final double? dragLeft;
  final ValueChanged<int>? onStopSelected;
  final ValueChanged<double> onDragStart;
  final void Function(double delta, double maxLeft) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;
  final ValueChanged<bool> onPressedChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tokens.zoomTrackHeight,
      padding: tokens.zoomPillPadding,
      decoration: ShapeDecoration(
        color: tokens.zoomPillOuterColor.withValues(
          alpha: tokens.zoomPillOuterOpacity,
        ),
        shape: SmoothRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.zoomPillOuterRadius),
          smoothness: tokens.zoomPillSmoothness,
        ),
      ),
      child: Container(
        decoration: ShapeDecoration(
          color: tokens.zoomPillInnerColor,
          shape: SmoothRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.zoomPillInnerRadius),
            smoothness: tokens.zoomPillSmoothness,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double trackWidth = constraints.maxWidth;
                final double trackHeight = constraints.maxHeight;
                if (stops.isEmpty || trackWidth <= 0 || trackHeight <= 0) {
                  return const SizedBox.shrink();
                }

                final double itemWidth = trackWidth / stops.length;
                final double maxLeft = trackWidth - itemWidth;
                final int resolvedIndex = currentIndex.clamp(
                  0,
                  stops.length - 1,
                );
                final double thumbLeft = isDragging
                    ? _clampDragLeft(
                        (dragLeft ?? resolvedIndex.toDouble()) * itemWidth,
                        maxLeft,
                      )
                    : resolvedIndex * itemWidth;
                final double thumbScale = isPressed
                    ? tokens.zoomThumbPressedScale
                    : 1.0;

                return Stack(
                  children: <Widget>[
                    AnimatedPositioned(
                      duration: isDragging
                          ? Duration.zero
                          : tokens.zoomThumbMotionDuration,
                      curve: tokens.zoomMotionCurve,
                      left: thumbLeft,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: IgnorePointer(
                        child: Center(
                          child: AnimatedScale(
                            scale: thumbScale,
                            duration: tokens.zoomThumbScaleDuration,
                            curve: tokens.zoomMotionCurve,
                            child: Container(
                              width: tokens.zoomThumbSize,
                              height: tokens.zoomThumbSize,
                              decoration: BoxDecoration(
                                color: tokens.zoomThumbColor,
                                borderRadius: BorderRadius.circular(
                                  tokens.zoomThumbRadius,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List<Widget>.generate(stops.length, (
                        int index,
                      ) {
                        final CameraZoomStop stop = stops[index];
                        final bool selected = index == resolvedIndex;
                        final String label = selected
                            ? currentZoomLabel
                            : stop.label;
                        return Expanded(
                          child: GestureDetector(
                            onTap: onStopSelected == null
                                ? null
                                : () => onStopSelected!(index),
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: Padding(
                                padding: tokens.zoomLabelPadding,
                                child: _RotatingCameraControl(
                                  tokens: tokens,
                                  turns: rotationTurns,
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        (selected
                                                ? tokens
                                                      .zoomSelectedLabelTextStyle
                                                : tokens
                                                      .zoomUnselectedLabelTextStyle)
                                            .copyWith(
                                              color: selected
                                                  ? tokens
                                                        .zoomSelectedLabelColor
                                                  : tokens
                                                        .zoomUnselectedLabelColor,
                                            ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    AnimatedPositioned(
                      duration: isDragging
                          ? Duration.zero
                          : tokens.zoomThumbMotionDuration,
                      curve: tokens.zoomMotionCurve,
                      left: thumbLeft,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (_) => onPressedChanged(true),
                        onPointerUp: (_) => onPressedChanged(false),
                        onPointerCancel: (_) => onPressedChanged(false),
                        child: GestureDetector(
                          key: const Key('camera_photo_zoom_thumb'),
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: (_) =>
                              onDragStart(resolvedIndex.toDouble()),
                          onHorizontalDragUpdate: (DragUpdateDetails details) =>
                              onDragUpdate(
                                details.delta.dx / itemWidth,
                                maxLeft / itemWidth,
                              ),
                          onHorizontalDragEnd: (_) => onDragEnd(),
                          onHorizontalDragCancel: onDragCancel,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static double _clampDragLeft(double left, double maxLeft) {
    return left.clamp(0.0, maxLeft).toDouble();
  }
}

class CameraPhotoModeExpansionMotion extends StatefulWidget {
  const CameraPhotoModeExpansionMotion({
    required this.tokens,
    required this.modes,
    required this.selectedModeId,
    required this.modeExtensions,
    required this.reduceMotion,
    required this.bottomControls,
    super.key,
    this.onModeSelected,
  });

  final CameraUiTokens tokens;
  final List<CameraUiMode> modes;
  final String? selectedModeId;
  final Map<String, List<Widget>> modeExtensions;
  final bool reduceMotion;
  final Widget bottomControls;
  final ValueChanged<String>? onModeSelected;

  @override
  State<CameraPhotoModeExpansionMotion> createState() =>
      _CameraPhotoModeExpansionMotionState();
}

class _CameraPhotoModeExpansionMotionState
    extends State<CameraPhotoModeExpansionMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _expansionAnimation;
  late List<Widget> _displayExtensionChildren;

  @override
  void initState() {
    super.initState();
    _displayExtensionChildren = _selectedExtensionChildren;
    _controller = AnimationController(
      duration: _duration,
      value: _selectedExtensionVisible ? 1 : 0,
      vsync: this,
    )..addStatusListener(_handleAnimationStatus);
    _expansionAnimation = _buildExpansionAnimation();
  }

  @override
  void didUpdateWidget(covariant CameraPhotoModeExpansionMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = _duration;
    if (oldWidget.reduceMotion != widget.reduceMotion) {
      _expansionAnimation = _buildExpansionAnimation();
    }

    final List<Widget> selectedChildren = _selectedExtensionChildren;
    if (selectedChildren.isNotEmpty) {
      _displayExtensionChildren = selectedChildren;
    }

    if (_selectedExtensionVisible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Duration get _duration => widget.reduceMotion
      ? Duration.zero
      : widget.tokens.modeExtensionMotionDuration;

  List<Widget> get _selectedExtensionChildren {
    final String? selectedModeId = widget.selectedModeId;
    if (selectedModeId == null) {
      return const <Widget>[];
    }
    return widget.modeExtensions[selectedModeId] ?? const <Widget>[];
  }

  bool get _selectedExtensionVisible => _selectedExtensionChildren.isNotEmpty;

  Animation<double> _buildExpansionAnimation() {
    return CurvedAnimation(
      parent: _controller,
      curve: widget.tokens.standardEaseOutCurve,
      reverseCurve: widget.tokens.standardEaseInCurve,
    );
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || _selectedExtensionVisible) {
      return;
    }
    if (_displayExtensionChildren.isEmpty) {
      return;
    }
    setState(() {
      _displayExtensionChildren = const <Widget>[];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (widget.modes.isNotEmpty && widget.selectedModeId != null)
          CameraPhotoModeSelector(
            tokens: widget.tokens,
            modes: widget.modes,
            selectedModeId: widget.selectedModeId!,
            extensionChildren: _displayExtensionChildren,
            expansionAnimation: _expansionAnimation,
            onModeSelected: widget.onModeSelected,
          ),
        const Spacer(),
        AnimatedBuilder(
          animation: _expansionAnimation,
          builder: (BuildContext context, Widget? child) {
            final double offset =
                -widget.tokens.collapsedBottomControlsVisualLift *
                (1 - _expansionAnimation.value);
            return Transform.translate(offset: Offset(0, offset), child: child);
          },
          child: widget.bottomControls,
        ),
      ],
    );
  }
}

class CameraPhotoPromptOptions extends StatelessWidget {
  const CameraPhotoPromptOptions({
    required this.children,
    required this.tokens,
    required this.expansionAnimation,
    super.key,
  });

  final CameraUiTokens tokens;
  final List<Widget> children;
  final Animation<double> expansionAnimation;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && expansionAnimation.value == 0) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: expansionAnimation,
      builder: (BuildContext context, Widget? child) {
        return IgnorePointer(
          ignoring: expansionAnimation.value <= 0.01,
          child: ClipRect(
            child: SizedBox(
              height:
                  tokens.modeExtensionExpandedHeight * expansionAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.backgroundColor,
          border: Border(
            bottom: BorderSide(
              color: tokens.dividerColor,
              width: tokens.dividerWidth,
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double horizontalPadding = 12;
            final double minContentWidth =
                constraints.maxWidth > horizontalPadding * 2
                ? constraints.maxWidth - horizontalPadding * 2
                : 0;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minContentWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (int index = 0; index < children.length; index++)
                        _CameraPhotoModeExtensionChild(
                          tokens: tokens,
                          animation: expansionAnimation,
                          index: index,
                          child: children[index],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class CameraPhotoModeSelector extends StatelessWidget {
  const CameraPhotoModeSelector({
    required this.tokens,
    required this.modes,
    required this.selectedModeId,
    required this.extensionChildren,
    required this.expansionAnimation,
    super.key,
    this.onModeSelected,
  });

  final CameraUiTokens tokens;
  final List<CameraUiMode> modes;
  final String selectedModeId;
  final List<Widget> extensionChildren;
  final Animation<double> expansionAnimation;
  final ValueChanged<String>? onModeSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.backgroundColor,
          border: Border(
            top: BorderSide(
              color: tokens.dividerColor,
              width: tokens.dividerWidth,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: tokens.modeRowHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: tokens.dividerColor,
                      width: tokens.dividerWidth,
                    ),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            for (final CameraUiMode mode in modes)
                              CameraPhotoModeItem(
                                tokens: tokens,
                                mode: mode,
                                selected: mode.id == selectedModeId,
                                onPressed: onModeSelected == null
                                    ? null
                                    : () => onModeSelected!(mode.id),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            CameraPhotoPromptOptions(
              tokens: tokens,
              expansionAnimation: expansionAnimation,
              children: extensionChildren,
            ),
          ],
        ),
      ),
    );
  }
}

class CameraPhotoModeItem extends StatelessWidget {
  const CameraPhotoModeItem({
    required this.tokens,
    required this.mode,
    required this.selected,
    super.key,
    this.onPressed,
  });

  final CameraUiTokens tokens;
  final CameraUiMode mode;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color color = selected
        ? tokens.primaryTextColor
        : tokens.inactiveColor;
    return GestureDetector(
      onTap: onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onPressed!();
            },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: tokens.modeItemWidth,
        height: double.infinity,
        child: Padding(
          padding: tokens.modeItemPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    mode.label,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style:
                        (selected
                                ? tokens.modeSelectedTextStyle
                                : tokens.modeUnselectedTextStyle)
                            .copyWith(color: color),
                  ),
                ),
              ),
              if (selected)
                Container(
                  key: ValueKey<String>(
                    'camera-photo-mode-indicator-${mode.id}',
                  ),
                  margin: EdgeInsets.only(top: tokens.modeIndicatorTopMargin),
                  width: tokens.modeIndicatorWidth,
                  height: tokens.modeIndicatorHeight,
                  color: tokens.primaryTextColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraPhotoModeExtensionChild extends StatelessWidget {
  const _CameraPhotoModeExtensionChild({
    required this.tokens,
    required this.animation,
    required this.index,
    required this.child,
  });

  final CameraUiTokens tokens;
  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double start =
        (tokens.modeExtensionInitialDelay +
                index * tokens.modeExtensionStaggerDelay)
            .clamp(0.0, 0.82);
    final double end = (start + tokens.modeExtensionItemDuration).clamp(
      0.0,
      1.0,
    );
    final Animation<double> reveal = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: tokens.standardEaseOutCurve),
      reverseCurve: Interval(start, end, curve: tokens.standardEaseInCurve),
    );
    return FadeTransition(
      opacity: reveal,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: tokens.modeExtensionSlideOffset,
          end: Offset.zero,
        ).animate(reveal),
        child: child,
      ),
    );
  }
}

class CameraPhotoBottomControls extends StatelessWidget {
  const CameraPhotoBottomControls({
    required this.tokens,
    super.key,
    this.galleryPreview,
    this.controlsRotationTurns = 0,
    this.galleryEnabled = true,
    this.galleryBadgeStatus = CameraGalleryBadgeStatus.none,
    this.shutterEnabled = true,
    this.shutterBusy = false,
    this.cameraFacing = CameraFacingUi.unknown,
    this.flipEnabled = true,
    this.flipBusy = false,
    this.onGalleryPressed,
    this.onShutterPressed,
    this.onFlipCameraPressed,
  });

  final CameraUiTokens tokens;
  final Widget? galleryPreview;
  final double controlsRotationTurns;
  final bool galleryEnabled;
  final CameraGalleryBadgeStatus galleryBadgeStatus;
  final bool shutterEnabled;
  final bool shutterBusy;
  final CameraFacingUi cameraFacing;
  final bool flipEnabled;
  final bool flipBusy;
  final VoidCallback? onGalleryPressed;
  final VoidCallback? onShutterPressed;
  final VoidCallback? onFlipCameraPressed;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: tokens.backgroundColor,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: tokens.bottomControlsHeight,
          child: Padding(
            padding: tokens.bottomControlsPadding,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: CameraPhotoGalleryButton(
                    tokens: tokens,
                    preview: galleryPreview,
                    rotationTurns: controlsRotationTurns,
                    badgeStatus: galleryBadgeStatus,
                    onPressed: galleryEnabled ? onGalleryPressed : null,
                  ),
                ),
                CameraPhotoShutterButton(
                  tokens: tokens,
                  enabled: shutterEnabled,
                  busy: shutterBusy,
                  onPressed: onShutterPressed,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: CameraPhotoFlipButton(
                    tokens: tokens,
                    facing: cameraFacing,
                    enabled: flipEnabled,
                    busy: flipBusy,
                    rotationTurns: controlsRotationTurns,
                    onPressed: onFlipCameraPressed,
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

class CameraPhotoGalleryButton extends StatelessWidget {
  const CameraPhotoGalleryButton({
    required this.tokens,
    super.key,
    this.preview,
    this.rotationTurns = 0,
    this.badgeStatus = CameraGalleryBadgeStatus.none,
    this.onPressed,
  });

  final CameraUiTokens tokens;
  final Widget? preview;
  final double rotationTurns;
  final CameraGalleryBadgeStatus badgeStatus;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color? badgeColor = _galleryBadgeColor(badgeStatus);
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          SmoothClipRRect(
            borderRadius: AppCorners.controlBorderRadius,
            smoothness: AppCorners.smoothness,
            side: BorderSide(
              color: tokens.primaryTextColor,
              width: tokens.dividerWidth,
            ),
            child: SizedBox(
              width: tokens.galleryButtonSize,
              height: tokens.galleryButtonSize,
              child: _RotatingCameraControl(
                tokens: tokens,
                turns: rotationTurns,
                child: preview ?? CameraCheckerboardThumbnail(tokens: tokens),
              ),
            ),
          ),
          if (badgeColor != null)
            Positioned(
              top: -2,
              right: -2,
              child: DecoratedBox(
                key: const ValueKey<String>('camera-gallery-result-badge'),
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.62),
                      blurRadius: 4,
                      spreadRadius: 0.4,
                    ),
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.34),
                      blurRadius: 7,
                      spreadRadius: 1.2,
                    ),
                  ],
                ),
                child: const SizedBox(width: 5, height: 5),
              ),
            ),
        ],
      ),
    );
  }

  Color? _galleryBadgeColor(CameraGalleryBadgeStatus status) {
    return switch (status) {
      CameraGalleryBadgeStatus.none => null,
      CameraGalleryBadgeStatus.success => AppColors.success,
      CameraGalleryBadgeStatus.failure => AppColors.danger,
    };
  }
}

class CameraPhotoShutterButton extends StatefulWidget {
  const CameraPhotoShutterButton({
    required this.tokens,
    super.key,
    this.enabled = true,
    this.busy = false,
    this.onPressed,
  });

  final CameraUiTokens tokens;
  final bool enabled;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  State<CameraPhotoShutterButton> createState() =>
      _CameraPhotoShutterButtonState();
}

class _CameraPhotoShutterButtonState extends State<CameraPhotoShutterButton> {
  bool _pressed = false;

  bool get _canPress =>
      widget.enabled && !widget.busy && widget.onPressed != null;

  void _handleTapDown(TapDownDetails details) {
    if (!_canPress) {
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _pressed = true;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_canPress) {
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _pressed = false;
    });
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    if (!_pressed) {
      return;
    }
    setState(() {
      _pressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _canPress ? _handleTapDown : null,
      onTapUp: _canPress ? _handleTapUp : null,
      onTapCancel: _canPress ? _handleTapCancel : null,
      child: Opacity(
        opacity: widget.enabled ? 1.0 : widget.tokens.disabledOpacity,
        child: SizedBox(
          width: widget.tokens.shutterSize,
          height: widget.tokens.shutterSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.tokens.primaryTextColor,
                width: widget.tokens.shutterOuterBorderWidth,
              ),
            ),
            child: Padding(
              padding: widget.tokens.shutterInnerPadding,
              child: AnimatedScale(
                scale: _pressed ? widget.tokens.shutterPressedScale : 1.0,
                duration: widget.tokens.shutterPressDuration,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.tokens.primaryTextColor,
                  ),
                  child: widget.busy
                      ? Center(
                          child: SizedBox.square(
                            dimension: widget.tokens.shutterBusyIndicatorSize,
                            child: CupertinoActivityIndicator(
                              color: widget.tokens.backgroundColor,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CameraPhotoFlashButton extends StatelessWidget {
  const CameraPhotoFlashButton({
    required this.tokens,
    super.key,
    this.mode = CameraFlashUiMode.off,
    this.enabled = true,
    this.busy = false,
    this.rotationTurns = 0,
    this.onPressed,
  });

  final CameraUiTokens tokens;
  final CameraFlashUiMode mode;
  final bool enabled;
  final bool busy;
  final double rotationTurns;
  final VoidCallback? onPressed;

  bool get _canPress =>
      enabled && !busy && mode != CameraFlashUiMode.unavailable;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = switch (mode) {
      CameraFlashUiMode.on => tokens.accentColor,
      CameraFlashUiMode.off => tokens.primaryTextColor,
      CameraFlashUiMode.unavailable => tokens.inactiveColor,
    };

    return _TopBarButton(
      tokens: tokens,
      icon: mode == CameraFlashUiMode.off
          ? LucideIcons.flashlightOff
          : LucideIcons.flashlight,
      iconColor: busy ? tokens.inactiveColor : iconColor,
      borderRight: true,
      rotationTurns: rotationTurns,
      onPressed: _canPress
          ? () {
              HapticFeedback.selectionClick();
              onPressed!();
            }
          : null,
      tooltip: 'Flash',
    );
  }
}

class CameraPhotoFlipButton extends StatelessWidget {
  const CameraPhotoFlipButton({
    required this.tokens,
    super.key,
    this.facing = CameraFacingUi.unknown,
    this.enabled = true,
    this.busy = false,
    this.rotationTurns = 0,
    this.onPressed,
  });

  final CameraUiTokens tokens;
  final CameraFacingUi facing;
  final bool enabled;
  final bool busy;
  final double rotationTurns;
  final VoidCallback? onPressed;

  bool get _canPress => enabled && !busy && onPressed != null;

  @override
  Widget build(BuildContext context) {
    final double opacity = enabled ? 1.0 : tokens.disabledOpacity;
    return Semantics(
      label: 'Flip camera',
      button: true,
      enabled: _canPress,
      child: CupertinoButton(
        onPressed: _canPress ? onPressed : null,
        minimumSize: Size.square(tokens.flipButtonSize),
        padding: EdgeInsets.zero,
        child: Opacity(
          opacity: opacity,
          child: _RotatingCameraControl(
            tokens: tokens,
            turns: rotationTurns,
            child: busy
                ? SizedBox.square(
                    dimension: tokens.flipBusyIndicatorSize,
                    child: CupertinoActivityIndicator(
                      color: tokens.primaryTextColor,
                    ),
                  )
                : Icon(
                    facing == CameraFacingUi.front
                        ? LucideIcons.camera
                        : LucideIcons.switchCamera,
                    color: tokens.primaryTextColor,
                    size: tokens.flipIconSize,
                  ),
          ),
        ),
      ),
    );
  }
}

class CameraCheckerboardThumbnail extends StatelessWidget {
  const CameraCheckerboardThumbnail({required this.tokens, super.key});

  final CameraUiTokens tokens;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: CameraCheckerboardPainter(tokens: tokens));
  }
}

class CameraCheckerboardPainter extends CustomPainter {
  const CameraCheckerboardPainter({required this.tokens});

  final CameraUiTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final int cells = tokens.checkerboardCells;
    final double cellSize = size.width / cells;

    for (int i = 0; i < cells; i++) {
      for (int j = 0; j < cells; j++) {
        paint.color = (i + j).isEven
            ? tokens.checkerboardLightColor
            : tokens.checkerboardDarkColor;
        canvas.drawRect(
          Rect.fromLTWH(i * cellSize, j * cellSize, cellSize, cellSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopBarSlot extends StatelessWidget {
  const _TopBarSlot({
    required this.tokens,
    required this.child,
    this.borderLeft = false,
    this.borderRight = false,
  });

  final CameraUiTokens tokens;
  final Widget child;
  final bool borderLeft;
  final bool borderRight;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: borderLeft || borderRight
            ? Border(
                left: borderLeft
                    ? BorderSide(
                        color: tokens.dividerColor,
                        width: tokens.dividerWidth,
                      )
                    : BorderSide.none,
                right: BorderSide(
                  color: borderRight
                      ? tokens.dividerColor
                      : CupertinoColors.transparent,
                  width: borderRight ? tokens.dividerWidth : 0,
                ),
              )
            : null,
      ),
      child: child,
    );
  }
}

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
    required this.tokens,
    required this.icon,
    required this.tooltip,
    this.iconColor,
    this.borderRight = false,
    this.rotationTurns = 0,
    this.onPressed,
  });

  final CameraUiTokens tokens;
  final IconData icon;
  final String tooltip;
  final Color? iconColor;
  final bool borderRight;
  final double rotationTurns;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: borderRight
            ? Border(
                right: BorderSide(
                  color: tokens.dividerColor,
                  width: tokens.dividerWidth,
                ),
              )
            : null,
      ),
      child: Semantics(
        label: tooltip,
        button: true,
        enabled: onPressed != null,
        child: CupertinoButton(
          onPressed: onPressed,
          minimumSize: Size.square(tokens.topBarButtonSize),
          padding: EdgeInsets.zero,
          child: _RotatingCameraControl(
            tokens: tokens,
            turns: rotationTurns,
            child: Icon(
              icon,
              color: iconColor ?? tokens.primaryTextColor,
              size: tokens.topBarIconSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _RotatingCameraControl extends StatelessWidget {
  const _RotatingCameraControl({
    required this.tokens,
    required this.turns,
    required this.child,
  });

  final CameraUiTokens tokens;
  final double turns;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: turns,
      duration: tokens.rotationDuration,
      curve: tokens.rotationCurve,
      child: child,
    );
  }
}
