import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_corners.dart';
import '../../../theme/app_theme.dart';
import '../domain/generation_submission_job.dart';

enum _GenerationPillMode { confirmation, completed, retry, failure }

/// Renders the actionable or terminal control shown on a thumbnail's front.
///
/// Loading belongs exclusively to the card's Plasma back face, so this widget
/// deliberately has no loading state or animation lifecycle.
@visibleForTesting
class GenerationStatusPill extends StatelessWidget {
  const GenerationStatusPill({
    super.key,
    required this.jobId,
    required this.status,
    required this.onConfirm,
    required this.onRetry,
    this.height = 22,
  });

  final String jobId;
  final GenerationSubmissionStatus status;
  final VoidCallback? onConfirm;
  final VoidCallback? onRetry;
  final double height;

  @override
  Widget build(BuildContext context) {
    final _GenerationPillMode mode = _mode;
    if (mode == _GenerationPillMode.confirmation) {
      return _ConfirmationPill(
        jobId: jobId,
        height: height,
        onPressed: onConfirm,
      );
    }

    final AppThemeColors colors = AppThemeColors.of(context);
    final bool retry = mode == _GenerationPillMode.retry;
    final double size = retry ? 24 : height;
    final IconData icon = switch (mode) {
      _GenerationPillMode.retry => LucideIcons.refreshCcw,
      _GenerationPillMode.completed => LucideIcons.circleCheck,
      _GenerationPillMode.failure => LucideIcons.circleAlert,
      _GenerationPillMode.confirmation => LucideIcons.circleHelp,
    };
    final Color iconColor = switch (mode) {
      _GenerationPillMode.retry => colors.inverseText,
      _GenerationPillMode.completed => AppColors.success,
      _GenerationPillMode.failure => AppColors.danger,
      _GenerationPillMode.confirmation => AppColors.white,
    };
    final Key iconKey = switch (mode) {
      _GenerationPillMode.retry => ValueKey<String>(
        'generation-submission-retry-icon-$jobId',
      ),
      _GenerationPillMode.completed => const ValueKey<String>(
        'generation-submission-status-result-saved',
      ),
      _GenerationPillMode.failure
          when status == GenerationSubmissionStatus.resultProcessingFailed =>
        const ValueKey<String>(
          'generation-submission-status-result-processing-failed',
        ),
      _GenerationPillMode.failure => const ValueKey<String>(
        'generation-submission-status-failed',
      ),
      _GenerationPillMode.confirmation => const ValueKey<String>(
        'generation-submission-status-processing',
      ),
    };
    final Key interactionKey = switch (mode) {
      _GenerationPillMode.retry => ValueKey<String>(
        'generation-submission-retry-$jobId',
      ),
      _GenerationPillMode.completed => ValueKey<String>(
        'generation-submission-completed-$jobId',
      ),
      _GenerationPillMode.failure => ValueKey<String>(
        'generation-submission-failed-$jobId',
      ),
      _GenerationPillMode.confirmation => ValueKey<String>(
        'generation-submission-confirm-$jobId',
      ),
    };
    final String semanticLabel = switch (mode) {
      _GenerationPillMode.retry => context.l10n.generationSubmissionActionRetry,
      _GenerationPillMode.completed =>
        context.l10n.generationSubmissionStatusResultSaved,
      _GenerationPillMode.failure
          when status == GenerationSubmissionStatus.resultProcessingFailed =>
        context.l10n.generationSubmissionStatusResultProcessingFailed,
      _GenerationPillMode.failure =>
        context.l10n.generationSubmissionStatusGenerationFailed,
      _GenerationPillMode.confirmation =>
        context.l10n.generationSubmissionStatusWaitingForConfirmation,
    };

    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: retry,
        enabled: retry && onRetry != null,
        label: semanticLabel,
        child: GestureDetector(
          key: interactionKey,
          behavior: HitTestBehavior.opaque,
          onTap: retry ? onRetry : null,
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: AppCorners.controlDecoration(
                color: retry
                    ? colors.accentYellow.withValues(alpha: 0.8)
                    : AppColors.blackOverlay(0.45),
                borderRadius: BorderRadius.circular(999),
              ),
              child: SizedBox.square(
                dimension: size,
                child: Icon(icon, key: iconKey, color: iconColor, size: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _GenerationPillMode get _mode {
    if (status == GenerationSubmissionStatus.awaitingConfirmation) {
      return _GenerationPillMode.confirmation;
    }
    if (onRetry != null) {
      return _GenerationPillMode.retry;
    }
    if (status == GenerationSubmissionStatus.resultSaved) {
      return _GenerationPillMode.completed;
    }
    return _GenerationPillMode.failure;
  }
}

class _ConfirmationPill extends StatelessWidget {
  const _ConfirmationPill({
    required this.jobId,
    required this.height,
    required this.onPressed,
  });

  final String jobId;
  final double height;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: context.l10n.generationSubmissionStatusWaitingForConfirmation,
      child: GestureDetector(
        key: ValueKey<String>('generation-submission-confirm-$jobId'),
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ExcludeSemantics(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: height,
              child: Padding(
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
            ),
          ),
        ),
      ),
    );
  }
}
