import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_submission_job.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_progress_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime startedAt = DateTime.utc(2026, 7, 30, 12);

  test('advances at exact integer percentage boundaries', () {
    _expectEstimate(
      startedAt: startedAt,
      elapsed: Duration.zero,
      percentage: 0,
      untilNextChange: const Duration(milliseconds: 700),
    );
    _expectEstimate(
      startedAt: startedAt,
      elapsed: const Duration(milliseconds: 699, microseconds: 999),
      percentage: 0,
      untilNextChange: const Duration(microseconds: 1),
    );
    _expectEstimate(
      startedAt: startedAt,
      elapsed: const Duration(milliseconds: 700),
      percentage: 1,
      untilNextChange: const Duration(milliseconds: 700),
    );
    _expectEstimate(
      startedAt: startedAt,
      elapsed: const Duration(seconds: 35),
      percentage: 50,
      untilNextChange: const Duration(milliseconds: 700),
    );
    _expectEstimate(
      startedAt: startedAt,
      elapsed: const Duration(seconds: 69, milliseconds: 300),
      percentage: 99,
      untilNextChange: const Duration(milliseconds: 700),
    );
  });

  test('clamps future start times to zero percent', () {
    _expectEstimate(
      startedAt: startedAt,
      elapsed: const Duration(seconds: -5),
      percentage: 0,
      untilNextChange: const Duration(milliseconds: 700),
    );
  });

  test('switches to finishing after the estimated duration', () {
    final GenerationProgressEstimate atBoundary =
        GenerationProgressEstimator.estimate(
          startedAt: startedAt,
          now: startedAt.add(const Duration(seconds: 70)),
          status: GenerationSubmissionStatus.pollingTask,
        );
    final GenerationProgressEstimate overdue =
        GenerationProgressEstimator.estimate(
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
      final GenerationProgressEstimate estimate =
          GenerationProgressEstimator.estimate(
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
  required int percentage,
  required Duration untilNextChange,
}) {
  final GenerationProgressEstimate estimate =
      GenerationProgressEstimator.estimate(
        startedAt: startedAt,
        now: startedAt.add(elapsed),
        status: GenerationSubmissionStatus.pollingTask,
      );

  expect(estimate.percentage, percentage);
  expect(estimate.untilNextChange, untilNextChange);
  expect(estimate.isFinishing, isFalse);
}
