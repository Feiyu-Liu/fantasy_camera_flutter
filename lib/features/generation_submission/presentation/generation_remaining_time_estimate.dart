import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/generation_submission_job.dart';

class GenerationRemainingTimeEstimate {
  const GenerationRemainingTimeEstimate.seconds({
    required int this.seconds,
    required this.untilNextChange,
  });

  const GenerationRemainingTimeEstimate.finishing()
    : seconds = null,
      untilNextChange = null;

  final int? seconds;
  final Duration? untilNextChange;

  bool get isFinishing => seconds == null;

  bool hasSameLabelAs(GenerationRemainingTimeEstimate other) {
    return seconds == other.seconds;
  }
}

class GenerationRemainingTimeEstimator {
  const GenerationRemainingTimeEstimator._();

  static const int maximumSeconds = 70;
  static const Duration estimatedDuration = Duration(seconds: maximumSeconds);
  static const List<int> lowerBucketSeconds = <int>[50, 30, 10];

  static GenerationRemainingTimeEstimate estimate({
    required DateTime startedAt,
    required DateTime now,
    required GenerationSubmissionStatus status,
  }) {
    if (_isFinishingStatus(status)) {
      return const GenerationRemainingTimeEstimate.finishing();
    }

    final int elapsedMicroseconds = now.difference(startedAt).inMicroseconds;
    final int remainingMicroseconds =
        estimatedDuration.inMicroseconds - elapsedMicroseconds;
    if (remainingMicroseconds <= 0) {
      return const GenerationRemainingTimeEstimate.finishing();
    }

    int displayedSeconds = maximumSeconds;
    for (final int bucketSeconds in lowerBucketSeconds) {
      final int bucketMicroseconds = Duration(
        seconds: bucketSeconds,
      ).inMicroseconds;
      if (remainingMicroseconds > bucketMicroseconds) {
        return GenerationRemainingTimeEstimate.seconds(
          seconds: displayedSeconds,
          untilNextChange: Duration(
            microseconds: remainingMicroseconds - bucketMicroseconds,
          ),
        );
      }
      displayedSeconds = bucketSeconds;
    }

    return GenerationRemainingTimeEstimate.seconds(
      seconds: displayedSeconds,
      untilNextChange: Duration(microseconds: remainingMicroseconds),
    );
  }

  static bool _isFinishingStatus(GenerationSubmissionStatus status) {
    return status == GenerationSubmissionStatus.completed ||
        status == GenerationSubmissionStatus.processingResultImage;
  }
}

/// Keeps a bucketed remaining-time estimate synchronized with app lifecycle.
class GenerationRemainingTimeTicker extends ChangeNotifier
    with WidgetsBindingObserver {
  GenerationRemainingTimeTicker({
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
    _estimate = GenerationRemainingTimeEstimator.estimate(
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
  late GenerationRemainingTimeEstimate _estimate;
  Timer? _timer;
  bool _tickerModeEnabled = true;

  GenerationRemainingTimeEstimate get estimate => _estimate;

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
    final GenerationRemainingTimeEstimate nextEstimate =
        GenerationRemainingTimeEstimator.estimate(
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
