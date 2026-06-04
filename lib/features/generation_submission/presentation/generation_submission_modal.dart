import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend_api/domain/prompt_config.dart';
import '../domain/generation_submission_job.dart';
import 'generation_submission_providers.dart';

Future<void> showGenerationSubmissionDebugModal(BuildContext context) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (BuildContext context) {
      return const GenerationSubmissionDebugModal();
    },
  );
}

class GenerationSubmissionDebugModal extends ConsumerStatefulWidget {
  const GenerationSubmissionDebugModal({super.key});

  @override
  ConsumerState<GenerationSubmissionDebugModal> createState() =>
      _GenerationSubmissionDebugModalState();
}

class _GenerationSubmissionDebugModalState
    extends ConsumerState<GenerationSubmissionDebugModal> {
  String? _selectedJobId;
  String? _loadingResultJobId;
  bool _showOriginalImage = false;
  bool _pickingGalleryImage = false;

  @override
  Widget build(BuildContext context) {
    final List<GenerationSubmissionJob> jobs = ref
        .watch(generationSubmissionControllerProvider)
        .jobs;
    final GenerationSubmissionJob? selectedJob = _selectedJob(jobs);

    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.84,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: CupertinoColors.systemBackground,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _ModalHandle(onClose: () => Navigator.of(context).pop()),
                SizedBox(
                  height: 118,
                  child: ListView.separated(
                    key: const ValueKey<String>(
                      'generation-submission-photo-list',
                    ),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: jobs.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (BuildContext context, int index) {
                      if (index == 0) {
                        return _GalleryPickerTile(
                          picking: _pickingGalleryImage,
                          onTap: _pickGalleryImage,
                        );
                      }
                      final GenerationSubmissionJob job = jobs[index - 1];
                      return _JobThumbnail(
                        job: job,
                        selected: selectedJob?.id == job.id,
                        onTap: () => _selectJob(job),
                        onConfirm:
                            job.status ==
                                GenerationSubmissionStatus.awaitingConfirmation
                            ? () => _confirmJob(job)
                            : null,
                        onCancel:
                            job.status ==
                                GenerationSubmissionStatus.awaitingConfirmation
                            ? () => unawaited(_cancelJob(job))
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _ResultPreview(
                    job: selectedJob,
                    loading: _loadingResultJobId == selectedJob?.id,
                    showOriginalImage: _showOriginalImage,
                    onToggleImage: selectedJob == null
                        ? null
                        : () {
                            setState(() {
                              _showOriginalImage = !_showOriginalImage;
                            });
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  GenerationSubmissionJob? _selectedJob(List<GenerationSubmissionJob> jobs) {
    if (jobs.isEmpty) {
      return null;
    }
    final String? selectedJobId = _selectedJobId;
    if (selectedJobId == null) {
      return jobs.first;
    }
    for (final GenerationSubmissionJob job in jobs) {
      if (job.id == selectedJobId) {
        return job;
      }
    }
    return jobs.first;
  }

  void _selectJob(GenerationSubmissionJob job) {
    _debugLog(
      'select job=${job.id} status=${job.status.name} task=${job.taskId ?? 'none'} resultCached=${job.resultUrl != null}',
    );
    setState(() {
      _selectedJobId = job.id;
      _showOriginalImage = false;
    });
    if (job.status == GenerationSubmissionStatus.completed ||
        job.status == GenerationSubmissionStatus.resultProcessingFailed) {
      unawaited(_loadResult(job.id));
    }
  }

  Future<void> _confirmJob(GenerationSubmissionJob job) async {
    _debugLog('confirm job=${job.id}');
    setState(() {
      _selectedJobId = job.id;
      _showOriginalImage = false;
    });
    await ref
        .read(generationSubmissionControllerProvider.notifier)
        .confirmJob(job.id);
  }

  Future<void> _cancelJob(GenerationSubmissionJob job) async {
    _debugLog('cancel job=${job.id}');
    await ref
        .read(generationSubmissionControllerProvider.notifier)
        .cancelJob(job.id);
    if (_selectedJobId == job.id) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedJobId = null;
        _loadingResultJobId = null;
        _showOriginalImage = false;
      });
    }
  }

  Future<void> _loadResult(String jobId) async {
    _debugLog('load result start job=$jobId');
    setState(() {
      _loadingResultJobId = jobId;
    });
    final String? url = await ref
        .read(generationSubmissionControllerProvider.notifier)
        .loadResultUrl(jobId);
    _debugLog(
      'load result finish job=$jobId url=${url == null ? 'none' : 'available'}',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      if (_loadingResultJobId == jobId) {
        _loadingResultJobId = null;
      }
    });
  }

  Future<void> _pickGalleryImage() async {
    if (_pickingGalleryImage) {
      return;
    }

    _debugLog('pick gallery start');
    setState(() {
      _pickingGalleryImage = true;
    });

    try {
      final XFile? file = await ref
          .read(galleryImagePickerProvider)
          .pickImageFromGallery();
      if (file == null) {
        _debugLog('pick gallery canceled');
        return;
      }
      _debugLog('pick gallery success path=${file.path}');
      final PromptSelectionSnapshot promptSelection = ref
          .read(promptSelectionControllerProvider)
          .snapshot;
      await ref
          .read(generationSubmissionControllerProvider.notifier)
          .queueGalleryFile(file, promptSelection: promptSelection);
    } on Object catch (error) {
      _debugLog('pick gallery failure error=$error');
    } finally {
      if (mounted) {
        setState(() {
          _pickingGalleryImage = false;
        });
      }
    }
  }

  void _debugLog(String message) {
    debugPrint('[GenerationSubmissionModal] $message');
  }
}

class _ModalHandle extends StatelessWidget {
  const _ModalHandle({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey3.resolveFrom(context),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          CupertinoButton(
            key: const ValueKey<String>('generation-submission-modal-close'),
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(32),
            onPressed: onClose,
            child: const Icon(CupertinoIcons.xmark_circle_fill),
          ),
        ],
      ),
    );
  }
}

class _GalleryPickerTile extends StatelessWidget {
  const _GalleryPickerTile({required this.picking, required this.onTap});

  final bool picking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('generation-submission-gallery-picker'),
      onTap: picking ? null : onTap,
      child: Container(
        width: 84,
        height: 108,
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          border: Border.all(
            color: CupertinoColors.separator.resolveFrom(context),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: picking
              ? const CupertinoActivityIndicator(
                  key: ValueKey<String>(
                    'generation-submission-gallery-picker-loading',
                  ),
                )
              : const Icon(
                  CupertinoIcons.plus,
                  color: CupertinoColors.activeBlue,
                  size: 30,
                ),
        ),
      ),
    );
  }
}

class _JobThumbnail extends StatelessWidget {
  const _JobThumbnail({
    required this.job,
    required this.selected,
    required this.onTap,
    required this.onConfirm,
    required this.onCancel,
  });

  final GenerationSubmissionJob job;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = selected
        ? CupertinoColors.activeBlue.resolveFrom(context)
        : CupertinoColors.separator.resolveFrom(context);

    return GestureDetector(
      key: ValueKey<String>('generation-submission-photo-${job.id}'),
      onTap: onTap,
      child: Container(
        width: 84,
        height: 108,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _ThumbnailImage(path: job.imagePath),
            Positioned(
              right: 6,
              top: job.status == GenerationSubmissionStatus.awaitingConfirmation
                  ? 6
                  : null,
              bottom:
                  job.status == GenerationSubmissionStatus.awaitingConfirmation
                  ? null
                  : 6,
              child: _StatusBadge(status: job.status),
            ),
            if (job.status == GenerationSubmissionStatus.awaitingConfirmation)
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: _ConfirmationActions(
                  jobId: job.id,
                  onConfirm: onConfirm,
                  onCancel: onCancel,
                ),
              ),
            Positioned(
              left: 6,
              right: 6,
              top: 6,
              child: _PromptSnapshotBadge(job: job),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return const _MissingOriginalImagePlaceholder();
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        debugPrint(
          '[GenerationSubmissionModal] thumbnail image load failure path=$path error=$error',
        );
        return const _MissingOriginalImagePlaceholder();
      },
    );
  }
}

class _MissingOriginalImagePlaceholder extends StatelessWidget {
  const _MissingOriginalImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CupertinoColors.systemGrey6.resolveFrom(context),
      child: Center(
        child: Icon(
          CupertinoIcons.photo,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
          size: 30,
        ),
      ),
    );
  }
}

class _PromptSnapshotBadge extends StatelessWidget {
  const _PromptSnapshotBadge({required this.job});

  final GenerationSubmissionJob job;

  @override
  Widget build(BuildContext context) {
    final PromptSelectionSnapshot selection =
        job.promptSelection ?? PromptSelectionSnapshot.fallback;
    final int activeCount = selection.switches.values
        .where((bool selected) => selected)
        .length;
    final String label = activeCount == 0 ? '默认' : '开 $activeCount';

    return Align(
      alignment: Alignment.topLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.black.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: Text(
            label,
            key: ValueKey<String>('generation-submission-prompt-${job.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final GenerationSubmissionStatus status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: SizedBox.square(
        dimension: 26,
        child: Center(child: _statusIcon()),
      ),
    );
  }

  Widget _statusIcon() {
    return switch (status) {
      GenerationSubmissionStatus.awaitingConfirmation => const Icon(
        CupertinoIcons.question_circle_fill,
        key: ValueKey<String>('generation-submission-status-awaiting'),
        color: CupertinoColors.white,
        size: 20,
      ),
      GenerationSubmissionStatus.resultSaved => const Icon(
        CupertinoIcons.check_mark_circled_solid,
        key: ValueKey<String>('generation-submission-status-result-saved'),
        color: CupertinoColors.activeGreen,
        size: 20,
      ),
      GenerationSubmissionStatus.resultProcessingFailed => const Icon(
        CupertinoIcons.exclamationmark_circle_fill,
        key: ValueKey<String>(
          'generation-submission-status-result-processing-failed',
        ),
        color: CupertinoColors.systemRed,
        size: 20,
      ),
      GenerationSubmissionStatus.completed => const Icon(
        CupertinoIcons.check_mark_circled_solid,
        key: ValueKey<String>('generation-submission-status-completed'),
        color: CupertinoColors.activeGreen,
        size: 20,
      ),
      GenerationSubmissionStatus.failed => const Icon(
        CupertinoIcons.exclamationmark_circle_fill,
        key: ValueKey<String>('generation-submission-status-failed'),
        color: CupertinoColors.systemRed,
        size: 20,
      ),
      _ => const CupertinoActivityIndicator(
        key: ValueKey<String>('generation-submission-status-processing'),
        color: CupertinoColors.white,
        radius: 8,
      ),
    };
  }
}

class _ConfirmationActions extends StatelessWidget {
  const _ConfirmationActions({
    required this.jobId,
    required this.onConfirm,
    required this.onCancel,
  });

  final String jobId;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _ThumbnailActionButton(
          key: ValueKey<String>('generation-submission-cancel-$jobId'),
          color: CupertinoColors.systemRed,
          icon: CupertinoIcons.xmark,
          onPressed: onCancel,
        ),
        _ThumbnailActionButton(
          key: ValueKey<String>('generation-submission-confirm-$jobId'),
          color: CupertinoColors.activeGreen,
          icon: CupertinoIcons.check_mark,
          onPressed: onConfirm,
        ),
      ],
    );
  }
}

class _ThumbnailActionButton extends StatelessWidget {
  const _ThumbnailActionButton({
    super.key,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  final Color color;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(999),
        ),
        child: SizedBox.square(
          dimension: 28,
          child: Icon(icon, color: CupertinoColors.white, size: 17),
        ),
      ),
    );
  }
}

class _ResultPreview extends StatelessWidget {
  const _ResultPreview({
    required this.job,
    required this.loading,
    required this.showOriginalImage,
    required this.onToggleImage,
  });

  final GenerationSubmissionJob? job;
  final bool loading;
  final bool showOriginalImage;
  final VoidCallback? onToggleImage;

  @override
  Widget build(BuildContext context) {
    final GenerationSubmissionJob? job = this.job;
    if (job == null) {
      return const Center(
        child: Text(
          'Capture a photo to inspect generation results',
          style: TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _previewContent(job),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: _ImageToggleButton(
              showingOriginal: showOriginalImage,
              onPressed: onToggleImage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewContent(GenerationSubmissionJob job) {
    if (showOriginalImage) {
      return Image.file(
        File(job.imagePath),
        key: const ValueKey<String>('generation-submission-original-image'),
        fit: BoxFit.contain,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          debugPrint(
            '[GenerationSubmissionModal] original image load failure path=${job.imagePath} error=$error',
          );
          return const Center(
            child: Text(
              'Original image could not be loaded',
              style: TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          );
        },
      );
    }

    if (loading) {
      return const Center(
        child: CupertinoActivityIndicator(
          key: ValueKey<String>('generation-submission-result-loading'),
        ),
      );
    }

    if (job.status == GenerationSubmissionStatus.processingResultImage) {
      return const Center(
        child: CupertinoActivityIndicator(
          key: ValueKey<String>('generation-submission-result-processing'),
        ),
      );
    }

    if (job.status == GenerationSubmissionStatus.resultProcessingFailed) {
      return Center(
        child: Text(
          job.resultSaveErrorMessage ?? 'Result processing failed',
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (job.status != GenerationSubmissionStatus.completed &&
        job.status != GenerationSubmissionStatus.resultSaved) {
      return Center(
        child: Text(
          _statusText(job.status),
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      );
    }

    final String? processedResultPath = job.processedResultPath;
    if (processedResultPath != null) {
      return Image.file(
        File(processedResultPath),
        key: const ValueKey<String>(
          'generation-submission-processed-result-image',
        ),
        fit: BoxFit.contain,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          debugPrint(
            '[GenerationSubmissionModal] processed result image load failure path=$processedResultPath error=$error',
          );
          return const Center(
            child: Text(
              'Processed result image could not be loaded',
              style: TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          );
        },
      );
    }

    final String? resultUrl = job.resultUrl;
    if (resultUrl == null) {
      return const Center(
        child: Text(
          'Tap completed photo to load result',
          style: TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      );
    }

    return Image.network(
      resultUrl,
      key: const ValueKey<String>('generation-submission-result-image'),
      fit: BoxFit.contain,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        debugPrint(
          '[GenerationSubmissionModal] result image load failure url=$resultUrl error=$error',
        );
        return const Center(
          child: Text(
            'Result image could not be loaded',
            style: TextStyle(color: CupertinoColors.secondaryLabel),
          ),
        );
      },
      loadingBuilder:
          (BuildContext context, Widget child, ImageChunkEvent? progress) {
            if (progress == null) {
              return child;
            }
            return const Center(child: CupertinoActivityIndicator());
          },
    );
  }

  static String _statusText(GenerationSubmissionStatus status) {
    return switch (status) {
      GenerationSubmissionStatus.failed => 'Generation failed',
      GenerationSubmissionStatus.awaitingConfirmation =>
        'Waiting for confirmation',
      GenerationSubmissionStatus.preparingUploadImage =>
        'Preparing upload image',
      GenerationSubmissionStatus.processingResultImage =>
        'Processing result image',
      GenerationSubmissionStatus.resultSaved => 'Result saved',
      GenerationSubmissionStatus.resultProcessingFailed =>
        'Result processing failed',
      GenerationSubmissionStatus.submitted ||
      GenerationSubmissionStatus.pollingTask => 'Waiting for generation result',
      _ => 'Preparing generation task',
    };
  }
}

class _ImageToggleButton extends StatelessWidget {
  const _ImageToggleButton({
    required this.showingOriginal,
    required this.onPressed,
  });

  final bool showingOriginal;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = CupertinoColors.black.withValues(alpha: 0.68);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: CupertinoButton(
        key: const ValueKey<String>('generation-submission-image-toggle'),
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(44),
        onPressed: onPressed,
        child: Icon(
          showingOriginal ? CupertinoIcons.sparkles : CupertinoIcons.photo,
          color: CupertinoColors.white,
          size: 22,
        ),
      ),
    );
  }
}
