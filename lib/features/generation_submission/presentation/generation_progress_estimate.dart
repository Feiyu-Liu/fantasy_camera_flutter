import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/generation_submission_job.dart';

class GenerationProgressEstimate {
  const GenerationProgressEstimate.percentage({
    required int this.percentage,
    required this.untilNextChange,
  });

  const GenerationProgressEstimate.finishing()
    : percentage = null,
      untilNextChange = null;

  final int? percentage;
  final Duration? untilNextChange;

  bool get isFinishing => percentage == null;

  bool hasSameLabelAs(GenerationProgressEstimate other) {
    return percentage == other.percentage;
  }
}

class GenerationProgressEstimator {
  const GenerationProgressEstimator._();

  static const Duration estimatedDuration = Duration(seconds: 70);
  static const int maximumDisplayedPercentage = 99;
  static const int _percentageScale = 100;

  static GenerationProgressEstimate estimate({
    required DateTime startedAt,
    required DateTime now,
    required GenerationSubmissionStatus status,
  }) {
    if (_isFinishingStatus(status)) {
      return const GenerationProgressEstimate.finishing();
    }

    final int estimatedMicroseconds = estimatedDuration.inMicroseconds;
    final int elapsedMicroseconds = now
        .difference(startedAt)
        .inMicroseconds
        .clamp(0, estimatedMicroseconds);
    if (elapsedMicroseconds >= estimatedMicroseconds) {
      return const GenerationProgressEstimate.finishing();
    }

    final int percentage =
        ((elapsedMicroseconds * _percentageScale) ~/ estimatedMicroseconds)
            .clamp(0, maximumDisplayedPercentage);
    final int nextPercentage = percentage + 1;
    final int nextBoundaryMicroseconds =
        (estimatedMicroseconds * nextPercentage + _percentageScale - 1) ~/
        _percentageScale;

    return GenerationProgressEstimate.percentage(
      percentage: percentage,
      untilNextChange: Duration(
        microseconds: nextBoundaryMicroseconds - elapsedMicroseconds,
      ),
    );
  }

  static bool _isFinishingStatus(GenerationSubmissionStatus status) {
    return status == GenerationSubmissionStatus.completed ||
        status == GenerationSubmissionStatus.processingResultImage;
  }
}

/// Keeps an estimated generation percentage synchronized with app lifecycle.
class GenerationProgressTicker extends ChangeNotifier
    with WidgetsBindingObserver {
  GenerationProgressTicker({
    required DateTime? startedAt,
    required GenerationSubmissionStatus status,
    required bool active,
  }) {
    final DateTime now = DateTime.now();
    _sourceStartedAt = startedAt;
    _startedAt = startedAt ?? now;
    _status = status;
    _active = active;
    _referenceNow = now;
    _estimate = GenerationProgressEstimator.estimate(
      startedAt: _startedAt,
      now: now,
      status: status,
    );
    WidgetsBinding.instance.addObserver(this);
    _sync(notify: false);
  }

  late DateTime? _sourceStartedAt;
  late DateTime _startedAt;
  late GenerationSubmissionStatus _status;
  late bool _active;
  late DateTime _referenceNow;
  late GenerationProgressEstimate _estimate;
  Timer? _timer;
  bool _tickerModeEnabled = true;

  GenerationProgressEstimate get estimate => _estimate;

  void update({
    required DateTime? startedAt,
    required GenerationSubmissionStatus status,
    required bool active,
    bool preserveEstimateWhenInactive = false,
  }) {
    final bool startedAtChanged = startedAt != _sourceStartedAt;
    final bool statusChanged = status != _status;
    final bool wasActive = _active;
    if (startedAtChanged) {
      _sourceStartedAt = startedAt;
      _startedAt = startedAt ?? DateTime.now();
    }
    _status = status;
    _active = active;

    if (!active && wasActive && preserveEstimateWhenInactive) {
      _cancelTimer();
      return;
    }
    if (startedAtChanged || statusChanged || active != wasActive) {
      _sync();
    }
  }

  void setTickerModeEnabled(bool enabled) {
    if (_tickerModeEnabled == enabled) {
      return;
    }
    _tickerModeEnabled = enabled;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync();
    } else {
      _cancelTimer();
    }
  }

  void _sync({bool notify = true, DateTime? now}) {
    _cancelTimer();
    _referenceNow = now ?? DateTime.now();
    final GenerationProgressEstimate nextEstimate =
        GenerationProgressEstimator.estimate(
          startedAt: _startedAt,
          now: _referenceNow,
          status: _status,
        );
    final bool changed = !_estimate.hasSameLabelAs(nextEstimate);
    _estimate = nextEstimate;
    if (changed && notify) {
      notifyListeners();
    }
    _scheduleTimer();
  }

  void _scheduleTimer() {
    final Duration? untilNextChange = _estimate.untilNextChange;
    if (!_active ||
        !_canSchedule ||
        untilNextChange == null ||
        untilNextChange <= Duration.zero) {
      return;
    }
    final DateTime scheduledTransitionAt = _referenceNow.add(untilNextChange);
    _timer = Timer(untilNextChange, () {
      final DateTime actualNow = DateTime.now();
      _sync(
        now: actualNow.isAfter(scheduledTransitionAt)
            ? actualNow
            : scheduledTransitionAt,
      );
    });
  }

  bool get _canSchedule {
    final AppLifecycleState? lifecycleState =
        WidgetsBinding.instance.lifecycleState;
    return _tickerModeEnabled &&
        (lifecycleState == null || lifecycleState == AppLifecycleState.resumed);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimer();
    super.dispose();
  }
}
