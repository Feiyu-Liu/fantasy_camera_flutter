import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_corners.dart';
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
    if (mode == _GenerationPillMode.confirmation ||
        mode == _GenerationPillMode.retry) {
      final bool retry = mode == _GenerationPillMode.retry;
      final Color actionColor = retry
          ? AppColors.accentYellow
          : AppColors.success;
      return _ThumbnailTextAction(
        height: height,
        interactionKey: ValueKey<String>(
          retry
              ? 'generation-submission-retry-$jobId'
              : 'generation-submission-confirm-$jobId',
        ),
        iconKey: retry
            ? ValueKey<String>('generation-submission-retry-icon-$jobId')
            : null,
        visualKey: ValueKey<String>(
          retry
              ? 'generation-submission-retry-visual-$jobId'
              : 'generation-submission-confirm-visual-$jobId',
        ),
        icon: retry ? LucideIcons.refreshCcw : LucideIcons.check600,
        label: retry
            ? context.l10n.generationSubmissionActionRetry
            : context.l10n.generationSubmissionActionConfirm,
        semanticLabel: retry
            ? context.l10n.generationSubmissionActionRetry
            : context.l10n.generationSubmissionStatusWaitingForConfirmation,
        color: actionColor,
        onPressed: retry ? onRetry : onConfirm,
      );
    }

    final bool completed = mode == _GenerationPillMode.completed;
    final IconData icon = completed
        ? LucideIcons.circleCheck
        : LucideIcons.circleAlert;
    final Color iconColor = completed ? AppColors.success : AppColors.danger;
    final Key iconKey = completed
        ? const ValueKey<String>('generation-submission-status-result-saved')
        : status == GenerationSubmissionStatus.resultProcessingFailed
        ? const ValueKey<String>(
            'generation-submission-status-result-processing-failed',
          )
        : const ValueKey<String>('generation-submission-status-failed');
    final Key interactionKey = ValueKey<String>(
      completed
          ? 'generation-submission-completed-$jobId'
          : 'generation-submission-failed-$jobId',
    );
    final String semanticLabel = completed
        ? context.l10n.generationSubmissionStatusResultSaved
        : status == GenerationSubmissionStatus.resultProcessingFailed
        ? context.l10n.generationSubmissionStatusResultProcessingFailed
        : context.l10n.generationSubmissionStatusGenerationFailed;

    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: false,
        enabled: false,
        label: semanticLabel,
        child: GestureDetector(
          key: interactionKey,
          behavior: HitTestBehavior.opaque,
          onTap: null,
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: AppCorners.controlDecoration(
                color: AppColors.blackOverlay(0.45),
                borderRadius: BorderRadius.circular(999),
              ),
              child: SizedBox.square(
                dimension: height,
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

class _ThumbnailTextAction extends StatelessWidget {
  const _ThumbnailTextAction({
    required this.height,
    required this.interactionKey,
    required this.iconKey,
    required this.visualKey,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.color,
    required this.onPressed,
  });

  final double height;
  final Key interactionKey;
  final Key? iconKey;
  final Key visualKey;
  final IconData icon;
  final String label;
  final String semanticLabel;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: GestureDetector(
        key: interactionKey,
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ExcludeSemantics(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SizedBox(
                key: visualKey,
                height: height,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 5, 6, 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        icon,
                        key: iconKey,
                        color: color,
                        size: 14,
                        shadows: const <Shadow>[
                          Shadow(
                            color: Color(0xB3000000),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          shadows: const <Shadow>[
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
      ),
    );
  }
}
