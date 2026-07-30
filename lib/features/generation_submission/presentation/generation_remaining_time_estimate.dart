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
