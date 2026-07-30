import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_submission_job.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_remaining_time_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime startedAt = DateTime.utc(2026, 7, 30, 12);

  test('uses max, 50, 30, and 10 second buckets at exact boundaries', () {
    _expectEstimate(
      startedAt: startedAt,
      elapsed: Duration.zero,
      seconds: 70,
      untilNextChange: const Duration(seconds: 20),
    );
    _expectEstimate(
      startedAt: startedAt,
      elapsed: const Duration(seconds: 19, milliseconds: 999),
      seconds: 70,
      untilNextChange: const Duration(milliseconds: 1),
    );
    _expectEstimate(
      startedAt: startedAt,
      elapsed: const Duration(seconds: 20),
      seconds: 50,
      untilNextChange: const Duration(seconds: 20),
    );
    _expectEstimate(
      startedAt: startedAt,
      elapsed: const Duration(seconds: 40),
      seconds: 30,
      untilNextChange: const Duration(seconds: 20),
    );
    _expectEstimate(
      startedAt: startedAt,
      elapsed: const Duration(seconds: 60),
      seconds: 10,
      untilNextChange: const Duration(seconds: 10),
    );
  });

  test('clamps future start times to the maximum estimate', () {
    _expectEstimate(
      startedAt: startedAt,
      elapsed: const Duration(seconds: -5),
      seconds: 70,
      untilNextChange: const Duration(seconds: 25),
    );
  });

  test('switches to finishing after the estimated duration', () {
    final GenerationRemainingTimeEstimate atBoundary =
        GenerationRemainingTimeEstimator.estimate(
          startedAt: startedAt,
          now: startedAt.add(const Duration(seconds: 70)),
          status: GenerationSubmissionStatus.pollingTask,
        );
    final GenerationRemainingTimeEstimate overdue =
        GenerationRemainingTimeEstimator.estimate(
          startedAt: startedAt,
          now: startedAt.add(const Duration(seconds: 90)),
          status: GenerationSubmissionStatus.pollingTask,
        );

    expect(atBoundary.isFinishing, isTrue);
    expect(atBoundary.untilNextChange, isNull);
    expect(overdue.isFinishing, isTrue);
    expect(overdue.untilNextChange, isNull);
  });

  test('completed and result processing force the finishing label', () {
    for (final GenerationSubmissionStatus status
        in <GenerationSubmissionStatus>[
          GenerationSubmissionStatus.completed,
          GenerationSubmissionStatus.processingResultImage,
        ]) {
      final GenerationRemainingTimeEstimate estimate =
          GenerationRemainingTimeEstimator.estimate(
            startedAt: startedAt,
            now: startedAt.add(const Duration(seconds: 5)),
            status: status,
          );

      expect(estimate.isFinishing, isTrue);
      expect(estimate.untilNextChange, isNull);
    }
  });
}

void _expectEstimate({
  required DateTime startedAt,
  required Duration elapsed,
  required int seconds,
  required Duration untilNextChange,
}) {
  final GenerationRemainingTimeEstimate estimate =
      GenerationRemainingTimeEstimator.estimate(
        startedAt: startedAt,
        now: startedAt.add(elapsed),
        status: GenerationSubmissionStatus.pollingTask,
      );

  expect(estimate.seconds, seconds);
  expect(estimate.untilNextChange, untilNextChange);
  expect(estimate.isFinishing, isFalse);
}
