import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_ui/my_ui.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/core/app_logger.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../domain/generation_record_state_machine.dart';
import '../domain/generation_submission_job.dart';
import 'generation_remaining_time_estimate.dart';

enum _GenerationPillMode { confirmation, loading, completed, retry, failure }

/// Palettes the loading sheen cycles through, one per generation.
///
/// The palettes remain product-owned while the animation and shader live in
/// `my_ui`. Every entry stays readable behind the black estimate label.
const List<List<Color>> generationPillSheenPalettes = <List<Color>>[
  <Color>[
    Color(0xFFF2C070),
    Color(0xFFEF9A72),
    Color(0xFFE8B4CC),
    Color(0xFFF4E4BC),
  ],
  <Color>[
    Color(0xFFB6D998),
    Color(0xFFD8E8A8),
    Color(0xFF9ED8BC),
    Color(0xFFEDF0D2),
  ],
  <Color>[
    Color(0xFF9EDCC8),
    Color(0xFF9AC2E8),
    Color(0xFFCFE8AE),
    Color(0xFFE6F0DC),
  ],
  <Color>[
    Color(0xFFAEB8EC),
    Color(0xFFE0AEDC),
    Color(0xFF9ECBE0),
    Color(0xFFF0D8C6),
  ],
  <Color>[
    Color(0xFFC9B8F2),
    Color(0xFF9FD8E8),
    Color(0xFFF2B8D2),
    Color(0xFFEFE6BE),
  ],
  <Color>[
    Color(0xFFF2AEC4),
    Color(0xFFE8B0D8),
    Color(0xFFF4CDBC),
    Color(0xFFF0E2D0),
  ],
];

const List<Color> _generationPillConfirmSheenPalette = <Color>[
  AppColors.confirmGreen,
  AppColors.confirmGreen,
  AppColors.confirmGreen,
  AppColors.confirmGreen,
];

/// Picks a stable product palette for [jobId].
@visibleForTesting
List<Color> generationPillSheenPalette(String jobId) {
  int hash = 0x811c9dc5;
  for (int i = 0; i < jobId.length; i++) {
    hash = (hash ^ jobId.codeUnitAt(i)) * 0x01000193 & 0x7fffffff;
  }
  return generationPillSheenPalettes[hash % generationPillSheenPalettes.length];
}

/// Maps generation business state and localized content into a reusable
/// [MyAnimatedStatusPill]. All motion and shader behavior live in `my_ui`.
@visibleForTesting
class GenerationStatusPill extends StatefulWidget {
  const GenerationStatusPill({
    super.key,
    required this.jobId,
    required this.status,
    required this.startedAt,
    required this.onConfirm,
    required this.onRetry,
    this.height = 22,
  });

  final String jobId;
  final GenerationSubmissionStatus status;
  final DateTime? startedAt;
  final VoidCallback? onConfirm;
  final VoidCallback? onRetry;
  final double height;

  @override
  State<GenerationStatusPill> createState() => _GenerationStatusPillState();
}

class _GenerationStatusPillState extends State<GenerationStatusPill>
    with WidgetsBindingObserver {
  late _GenerationPillMode _mode;
  _GenerationPillMode _terminalMode = _GenerationPillMode.completed;
  late DateTime _effectiveStartedAt;
  late DateTime _estimateReferenceNow;
  late GenerationRemainingTimeEstimate _timeEstimate;
  Timer? _estimateTimer;
  bool _tickerModeEnabled = true;

  bool get _isLoading => _mode == _GenerationPillMode.loading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mode = _modeForWidget();
    if (_isTerminalMode(_mode)) {
      _terminalMode = _mode;
    }
    _effectiveStartedAt = widget.startedAt ?? DateTime.now();
    _estimateReferenceNow = DateTime.now();
    _timeEstimate = GenerationRemainingTimeEstimator.estimate(
      startedAt: _effectiveStartedAt,
      now: _estimateReferenceNow,
      status: widget.status,
    );
  }

  @override
  void didUpdateWidget(GenerationStatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    final _GenerationPillMode previousMode = _mode;
    bool estimateInputsChanged = false;
    if (widget.startedAt != oldWidget.startedAt) {
      _effectiveStartedAt = widget.startedAt ?? DateTime.now();
      estimateInputsChanged = true;
    }
    if (widget.status != oldWidget.status) {
      estimateInputsChanged = true;
    }

    final _GenerationPillMode nextMode = _modeForWidget();
    _mode = nextMode;
    if (_isTerminalMode(nextMode)) {
      _terminalMode = nextMode;
    }
    if (estimateInputsChanged) {
      if (previousMode == _GenerationPillMode.loading &&
          _isTerminalMode(nextMode)) {
        _cancelEstimateTimer();
      } else {
        _syncTimeEstimate();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    _syncTimeEstimate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTimeEstimate(rebuild: true);
      return;
    }
    _cancelEstimateTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelEstimateTimer();
    super.dispose();
  }

  _GenerationPillMode _modeForWidget() {
    if (widget.status == GenerationSubmissionStatus.awaitingConfirmation) {
      return _GenerationPillMode.confirmation;
    }
    if (GenerationRecordStateMachine.showsGenerationProgress(widget.status)) {
      return _GenerationPillMode.loading;
    }
    if (widget.onRetry != null) {
      return _GenerationPillMode.retry;
    }
    if (widget.status == GenerationSubmissionStatus.resultSaved) {
      return _GenerationPillMode.completed;
    }
    return _GenerationPillMode.failure;
  }

  bool _isTerminalMode(_GenerationPillMode mode) {
    return mode == _GenerationPillMode.completed ||
        mode == _GenerationPillMode.retry ||
        mode == _GenerationPillMode.failure;
  }

  void _syncTimeEstimate({bool rebuild = false, DateTime? now}) {
    _cancelEstimateTimer();
    _estimateReferenceNow = now ?? DateTime.now();
    final GenerationRemainingTimeEstimate nextEstimate =
        GenerationRemainingTimeEstimator.estimate(
          startedAt: _effectiveStartedAt,
          now: _estimateReferenceNow,
          status: widget.status,
        );
    final bool labelChanged = !_timeEstimate.hasSameLabelAs(nextEstimate);
    if (labelChanged && rebuild && mounted) {
      setState(() {
        _timeEstimate = nextEstimate;
      });
    } else {
      _timeEstimate = nextEstimate;
    }
    _scheduleEstimateTimer();
  }

  void _scheduleEstimateTimer() {
    final Duration? untilNextChange = _timeEstimate.untilNextChange;
    if (!_isLoading ||
        !_canScheduleEstimate ||
        untilNextChange == null ||
        untilNextChange <= Duration.zero) {
      return;
    }
    final DateTime scheduledTransitionAt = _estimateReferenceNow.add(
      untilNextChange,
    );
    _estimateTimer = Timer(untilNextChange, () {
      if (!mounted) {
        return;
      }
      final DateTime actualNow = DateTime.now();
      _syncTimeEstimate(
        rebuild: true,
        now: actualNow.isAfter(scheduledTransitionAt)
            ? actualNow
            : scheduledTransitionAt,
      );
    });
  }

  void _cancelEstimateTimer() {
    _estimateTimer?.cancel();
    _estimateTimer = null;
  }

  bool get _canScheduleEstimate {
    final AppLifecycleState? lifecycleState =
        WidgetsBinding.instance.lifecycleState;
    return _tickerModeEnabled &&
        (lifecycleState == null || lifecycleState == AppLifecycleState.resumed);
  }

  String _resolvedEstimateLabel() {
    final int? estimatedSeconds = _timeEstimate.seconds;
    return estimatedSeconds == null
        ? context.l10n.generationSubmissionEstimatedFinishing
        : context.l10n.generationSubmissionEstimatedRemainingSeconds(
            estimatedSeconds,
          );
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    final List<Color> loadingPalette = generationPillSheenPalette(widget.jobId);
    final String estimateLabel = _resolvedEstimateLabel();
    const TextStyle estimateTextStyle = TextStyle(
      color: AppColors.black,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      height: 1,
      letterSpacing: 0,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    );
    final IconData terminalIcon = switch (_terminalMode) {
      _GenerationPillMode.retry => LucideIcons.refreshCcw,
      _GenerationPillMode.completed => LucideIcons.circleCheck,
      _GenerationPillMode.failure => LucideIcons.circleAlert,
      _GenerationPillMode.confirmation ||
      _GenerationPillMode.loading => LucideIcons.circleHelp,
    };
    final Color terminalIconColor = switch (_terminalMode) {
      _GenerationPillMode.retry => colors.inverseText,
      _GenerationPillMode.completed => AppColors.success,
      _GenerationPillMode.failure => AppColors.danger,
      _GenerationPillMode.confirmation ||
      _GenerationPillMode.loading => AppColors.white,
    };
    final Key terminalIconKey = switch (_terminalMode) {
      _GenerationPillMode.retry => ValueKey<String>(
        'generation-submission-retry-icon-${widget.jobId}',
      ),
      _GenerationPillMode.completed => const ValueKey<String>(
        'generation-submission-status-result-saved',
      ),
      _GenerationPillMode.failure
          when widget.status ==
              GenerationSubmissionStatus.resultProcessingFailed =>
        const ValueKey<String>(
          'generation-submission-status-result-processing-failed',
        ),
      _GenerationPillMode.failure => const ValueKey<String>(
        'generation-submission-status-failed',
      ),
      _GenerationPillMode.confirmation || _GenerationPillMode.loading =>
        const ValueKey<String>('generation-submission-status-processing'),
    };
    final Key interactionKey = switch (_mode) {
      _GenerationPillMode.confirmation => ValueKey<String>(
        'generation-submission-confirm-${widget.jobId}',
      ),
      _GenerationPillMode.loading => ValueKey<String>(
        'generation-submission-estimate-${widget.jobId}',
      ),
      _GenerationPillMode.retry => ValueKey<String>(
        'generation-submission-retry-${widget.jobId}',
      ),
      _GenerationPillMode.completed => ValueKey<String>(
        'generation-submission-completed-${widget.jobId}',
      ),
      _GenerationPillMode.failure => ValueKey<String>(
        'generation-submission-failed-${widget.jobId}',
      ),
    };
    final String semanticLabel = switch (_mode) {
      _GenerationPillMode.confirmation =>
        context.l10n.generationSubmissionStatusWaitingForConfirmation,
      _GenerationPillMode.loading => estimateLabel,
      _GenerationPillMode.retry => context.l10n.generationSubmissionActionRetry,
      _GenerationPillMode.completed =>
        context.l10n.generationSubmissionStatusResultSaved,
      _GenerationPillMode.failure
          when widget.status ==
              GenerationSubmissionStatus.resultProcessingFailed =>
        context.l10n.generationSubmissionStatusResultProcessingFailed,
      _GenerationPillMode.failure =>
        context.l10n.generationSubmissionStatusGenerationFailed,
    };
    final VoidCallback? onPressed = switch (_mode) {
      _GenerationPillMode.confirmation => widget.onConfirm,
      _GenerationPillMode.retry => widget.onRetry,
      _GenerationPillMode.loading ||
      _GenerationPillMode.completed ||
      _GenerationPillMode.failure => null,
    };
    final bool isButton =
        _mode == _GenerationPillMode.confirmation ||
        _mode == _GenerationPillMode.retry;
    final MyAnimatedStatusPillMode packageMode = switch (_mode) {
      _GenerationPillMode.confirmation => MyAnimatedStatusPillMode.action,
      _GenerationPillMode.loading => MyAnimatedStatusPillMode.loading,
      _GenerationPillMode.completed ||
      _GenerationPillMode.retry ||
      _GenerationPillMode.failure => MyAnimatedStatusPillMode.terminal,
    };
    final double terminalSize = _terminalMode == _GenerationPillMode.retry
        ? 24
        : widget.height;

    return MyAnimatedStatusPill(
      mode: packageMode,
      transitionKey: _mode,
      compactWidth: _estimatePillContentWidth(
        context,
        textStyle: estimateTextStyle,
      ),
      style: MyAnimatedStatusPillStyle(
        height: widget.height,
        terminalSize: terminalSize,
        actionBackground: const Color(0x00000000),
        loadingBackground: loadingPalette.first,
        terminalBackground: _terminalMode == _GenerationPillMode.retry
            ? colors.accentYellow.withValues(alpha: 0.8)
            : AppColors.blackOverlay(0.45),
        actionSheenColors: _generationPillConfirmSheenPalette,
        loadingSheenColors: loadingPalette,
      ),
      actionContent: Padding(
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              LucideIcons.check600,
              color: AppColors.success,
              size: 14,
              shadows: <Shadow>[
                Shadow(
                  color: Color(0xB3000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.generationSubmissionActionConfirm,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                shadows: <Shadow>[
                  Shadow(
                    color: Color(0xB3000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      loadingContent: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          estimateLabel,
          key: ValueKey<String>(
            'generation-submission-estimate-label-'
            '${_timeEstimate.seconds ?? 'finishing'}',
          ),
          maxLines: 1,
          softWrap: false,
          style: estimateTextStyle,
        ),
      ),
      terminalContent: Icon(
        terminalIcon,
        key: terminalIconKey,
        color: terminalIconColor,
        size: 14,
      ),
      semanticsLabel: semanticLabel,
      isButton: isButton,
      onPressed: onPressed,
      interactionKey: interactionKey,
      onShaderError: (Object error, StackTrace stackTrace) {
        logAppError('generation_pill_sheen_shader', error, stackTrace);
      },
    );
  }

  double _estimatePillContentWidth(
    BuildContext context, {
    required TextStyle textStyle,
  }) {
    final List<String> labels = <String>[
      context.l10n.generationSubmissionEstimatedRemainingSeconds(
        GenerationRemainingTimeEstimator.maximumSeconds,
      ),
      for (final int seconds
          in GenerationRemainingTimeEstimator.lowerBucketSeconds)
        context.l10n.generationSubmissionEstimatedRemainingSeconds(seconds),
      context.l10n.generationSubmissionEstimatedFinishing,
    ];
    final TextScaler textScaler = MediaQuery.textScalerOf(context);
    final TextDirection textDirection = Directionality.of(context);
    double widestLabel = 0;
    for (final String label in labels) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        maxLines: 1,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      widestLabel = math.max(widestLabel, painter.width);
    }
    return math.max(widget.height, widestLabel + 12);
  }
}
