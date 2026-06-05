import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend_api/domain/prompt_config.dart';
import '../data/generation_submission_adapters.dart';
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

class GenerationSubmissionGalleryPage extends StatelessWidget {
  const GenerationSubmissionGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: _GenerationSubmissionGalleryContent(),
    );
  }
}

class _GenerationSubmissionGalleryContent extends ConsumerStatefulWidget {
  const _GenerationSubmissionGalleryContent();

  @override
  ConsumerState<_GenerationSubmissionGalleryContent> createState() =>
      _GenerationSubmissionDebugModalState();
}

class _GenerationSubmissionDebugModalState
    extends ConsumerState<_GenerationSubmissionGalleryContent> {
  String? _selectedJobId;
  String? _loadingResultJobId;
  bool _showOriginalImage = false;
  bool _pickingGalleryImage = false;

  @override
  void dispose() {
    if (_pickingGalleryImage) {
      unawaited(ref.read(galleryImagePickerProvider).cancelActivePick());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<GenerationSubmissionJob> jobs = ref
        .watch(generationSubmissionControllerProvider)
        .jobs;
    final GenerationSubmissionJob? selectedJob = _selectedJob(jobs);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final double bottomHeight = (height * 0.28).clamp(250.0, 304.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _GalleryHeader(onClose: () => Navigator.of(context).pop()),
            Expanded(
              child: _GalleryHeroPreview(
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
            SizedBox(
              height: bottomHeight,
              child: _RelatedMomentsStrip(
                jobs: jobs,
                selectedJob: selectedJob,
                pickingGalleryImage: _pickingGalleryImage,
                onPickGalleryImage: _pickGalleryImage,
                onSelectJob: _selectJob,
                onConfirmJob: _confirmJob,
                onCancelJob: (GenerationSubmissionJob job) {
                  unawaited(_cancelJob(job));
                },
              ),
            ),
          ],
        );
      },
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
      _debugLog('pick gallery ignored because picker is active');
      return;
    }

    _debugLog('pick gallery start');
    setState(() {
      _pickingGalleryImage = true;
    });

    try {
      await ref.read(galleryImagePickerProvider).cancelActivePick();
      final PickedGalleryImage? pickedImage = await ref
          .read(galleryImagePickerProvider)
          .pickImageFromGallery();
      if (pickedImage == null) {
        _debugLog('pick gallery canceled');
        return;
      }
      final XFile file = pickedImage.file;
      _debugLog('pick gallery success path=${file.path}');
      final PromptSelectionSnapshot promptSelection = ref
          .read(promptSelectionControllerProvider)
          .snapshot;
      await ref
          .read(generationSubmissionControllerProvider.notifier)
          .queueGalleryFile(
            file,
            originalAssetId: pickedImage.assetId,
            promptSelection: promptSelection,
          );
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

class GenerationSubmissionDebugModal extends StatelessWidget {
  const GenerationSubmissionDebugModal({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.84,
          child: const DecoratedBox(
            decoration: BoxDecoration(color: CupertinoColors.white),
            child: _GenerationSubmissionGalleryContent(),
          ),
        ),
      ),
    );
  }
}

class _GalleryHeader extends StatelessWidget {
  const _GalleryHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 79,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: CupertinoColors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
          ),
        ),
        child: SafeArea(
          bottom: false,
          minimum: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              const Text(
                'JOURNAL / HIGHLIGHTS',
                key: ValueKey<String>('generation-gallery-title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: CupertinoColors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              Positioned(
                left: 14,
                child: CupertinoButton(
                  key: const ValueKey<String>(
                    'generation-submission-modal-close',
                  ),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(44),
                  onPressed: onClose,
                  child: const Icon(
                    CupertinoIcons.xmark,
                    color: CupertinoColors.black,
                    size: 20,
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

class _RelatedMomentsStrip extends StatelessWidget {
  const _RelatedMomentsStrip({
    required this.jobs,
    required this.selectedJob,
    required this.pickingGalleryImage,
    required this.onPickGalleryImage,
    required this.onSelectJob,
    required this.onConfirmJob,
    required this.onCancelJob,
  });

  final List<GenerationSubmissionJob> jobs;
  final GenerationSubmissionJob? selectedJob;
  final bool pickingGalleryImage;
  final VoidCallback onPickGalleryImage;
  final ValueChanged<GenerationSubmissionJob> onSelectJob;
  final ValueChanged<GenerationSubmissionJob> onConfirmJob;
  final ValueChanged<GenerationSubmissionJob> onCancelJob;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'RELATED MOMENTS',
                  key: ValueKey<String>('generation-gallery-related-title'),
                  style: TextStyle(
                    color: CupertinoColors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                height: 0.5,
                child: ColoredBox(color: Color(0xFFEEEEEE)),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double itemHeight = constraints.maxHeight;
                    final double tileHeight = (itemHeight - 28).clamp(
                      120.0,
                      220.0,
                    );
                    final double tileWidth = tileHeight * 0.72;
                    return ListView.separated(
                      key: const ValueKey<String>(
                        'generation-submission-photo-list',
                      ),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: jobs.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == 0) {
                          return _GalleryMomentItem(
                            width: tileWidth,
                            height: itemHeight,
                            imageHeight: tileHeight,
                            caption: 'IMPORT — NEW',
                            child: _GalleryPickerTile(
                              width: tileWidth,
                              height: tileHeight,
                              picking: pickingGalleryImage,
                              onTap: onPickGalleryImage,
                            ),
                          );
                        }
                        final GenerationSubmissionJob job = jobs[index - 1];
                        return _GalleryMomentItem(
                          width: tileWidth,
                          height: itemHeight,
                          imageHeight: tileHeight,
                          caption: _captionForJob(job),
                          child: _JobThumbnail(
                            width: tileWidth,
                            height: tileHeight,
                            job: job,
                            selected: selectedJob?.id == job.id,
                            onTap: () => onSelectJob(job),
                            onConfirm:
                                job.status ==
                                    GenerationSubmissionStatus
                                        .awaitingConfirmation
                                ? () => onConfirmJob(job)
                                : null,
                            onCancel:
                                job.status ==
                                    GenerationSubmissionStatus
                                        .awaitingConfirmation
                                ? () => onCancelJob(job)
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _captionForJob(GenerationSubmissionJob job) {
    final DateTime createdAt = job.createdAt;
    final int hour = createdAt.hour == 0
        ? 12
        : createdAt.hour > 12
        ? createdAt.hour - 12
        : createdAt.hour;
    final String minute = createdAt.minute.toString().padLeft(2, '0');
    final String period = createdAt.hour >= 12 ? 'PM' : 'AM';
    final String mode =
        job.promptSelection?.captureMode.toUpperCase() ?? 'MOMENT';
    return '$hour:$minute $period — $mode';
  }
}

class _GalleryMomentItem extends StatelessWidget {
  const _GalleryMomentItem({
    required this.width,
    required this.height,
    required this.imageHeight,
    required this.caption,
    required this.child,
  });

  final double width;
  final double height;
  final double imageHeight;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: width, height: imageHeight, child: child),
          const SizedBox(height: 10),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
            style: const TextStyle(
              color: Color(0xFF777777),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryPickerTile extends StatelessWidget {
  const _GalleryPickerTile({
    required this.width,
    required this.height,
    required this.picking,
    required this.onTap,
  });

  final double width;
  final double height;
  final bool picking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('generation-submission-gallery-picker'),
      onTap: picking ? null : onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          border: Border.all(color: const Color(0xFFDDDDDD), width: 0.5),
        ),
        child: Center(
          child: picking
              ? const CupertinoActivityIndicator(
                  key: ValueKey<String>(
                    'generation-submission-gallery-picker-loading',
                  ),
                )
              : const Icon(
                  CupertinoIcons.add,
                  color: CupertinoColors.black,
                  size: 24,
                ),
        ),
      ),
    );
  }
}

class _JobThumbnail extends StatelessWidget {
  const _JobThumbnail({
    required this.width,
    required this.height,
    required this.job,
    required this.selected,
    required this.onTap,
    required this.onConfirm,
    required this.onCancel,
  });

  final double width;
  final double height;
  final GenerationSubmissionJob job;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey<String>('generation-submission-photo-${job.id}'),
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? CupertinoColors.black : const Color(0xFFDDDDDD),
            width: selected ? 1.5 : 0.5,
          ),
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
      color: const Color(0xFFF5F5F5),
      child: Center(
        child: Icon(
          CupertinoIcons.photo,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
          size: 24,
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
    final String label = activeCount == 0 ? 'DEFAULT' : '+$activeCount';

    return Align(
      alignment: Alignment.topLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Text(
            label,
            key: ValueKey<String>('generation-submission-prompt-${job.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, this.includeTestKey = true});

  final GenerationSubmissionStatus status;
  final bool includeTestKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: SizedBox.square(
        dimension: 22,
        child: Center(child: _statusIcon()),
      ),
    );
  }

  Widget _statusIcon() {
    return switch (status) {
      GenerationSubmissionStatus.awaitingConfirmation => Icon(
        CupertinoIcons.question_circle_fill,
        key: includeTestKey
            ? const ValueKey<String>('generation-submission-status-awaiting')
            : null,
        color: CupertinoColors.white,
        size: 16,
      ),
      GenerationSubmissionStatus.resultSaved => Icon(
        CupertinoIcons.check_mark_circled_solid,
        key: includeTestKey
            ? const ValueKey<String>(
                'generation-submission-status-result-saved',
              )
            : null,
        color: CupertinoColors.activeGreen,
        size: 16,
      ),
      GenerationSubmissionStatus.resultProcessingFailed => Icon(
        CupertinoIcons.exclamationmark_circle_fill,
        key: includeTestKey
            ? const ValueKey<String>(
                'generation-submission-status-result-processing-failed',
              )
            : null,
        color: CupertinoColors.systemRed,
        size: 16,
      ),
      GenerationSubmissionStatus.completed => Icon(
        CupertinoIcons.check_mark_circled_solid,
        key: includeTestKey
            ? const ValueKey<String>('generation-submission-status-completed')
            : null,
        color: CupertinoColors.activeGreen,
        size: 16,
      ),
      GenerationSubmissionStatus.failed => Icon(
        CupertinoIcons.exclamationmark_circle_fill,
        key: includeTestKey
            ? const ValueKey<String>('generation-submission-status-failed')
            : null,
        color: CupertinoColors.systemRed,
        size: 16,
      ),
      _ => CupertinoActivityIndicator(
        key: includeTestKey
            ? const ValueKey<String>('generation-submission-status-processing')
            : null,
        color: CupertinoColors.white,
        radius: 6,
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
          color: color.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: SizedBox.square(
          dimension: 24,
          child: Icon(icon, color: CupertinoColors.white, size: 14),
        ),
      ),
    );
  }
}

class _GalleryHeroPreview extends StatelessWidget {
  const _GalleryHeroPreview({
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
      return const ColoredBox(
        color: CupertinoColors.white,
        child: Center(
          child: Text(
            'SELECT A MOMENT',
            key: ValueKey<String>('generation-gallery-empty-hero'),
            style: TextStyle(
              color: Color(0xFFBBBBBB),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: CupertinoColors.white,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _previewContent(job),
          // Hero Overlay: FEATURED Badge and Location
          Positioned(
            left: 24,
            bottom: 32,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xFFF8E71C)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      'FEATURED',
                      style: TextStyle(
                        color: CupertinoColors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '■ ${job.promptSelection?.captureMode.toUpperCase() ?? 'MOMENT'}, PARIS',
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    shadows: <Shadow>[
                      Shadow(
                        color: Color(0x80000000),
                        offset: Offset(0, 1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_shouldShowStatusOverlay(job))
            Positioned(
              left: 24,
              top: 24,
              right: 24,
              child: _HeroStatusLabel(
                status: job.status,
                message: _heroStatusMessage(job),
              ),
            ),
          if (loading)
            const Center(
              child: CupertinoActivityIndicator(
                key: ValueKey<String>('generation-submission-result-loading'),
                color: CupertinoColors.white,
              ),
            ),
          if (_shouldShowToggle(job))
            Positioned(
              right: 24,
              bottom: 24,
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
      return _HeroFileImage(
        path: job.imagePath,
        key: const ValueKey<String>('generation-submission-original-image'),
        failureLogLabel: 'original image',
        failureMessage: 'Original image could not be loaded',
      );
    }

    if (_shouldUseOriginalAsHero(job)) {
      return _HeroFileImage(
        path: job.imagePath,
        key: const ValueKey<String>('generation-submission-original-image'),
        failureLogLabel: 'original image',
        failureMessage: 'Original image could not be loaded',
      );
    }

    if (job.status == GenerationSubmissionStatus.resultProcessingFailed) {
      return _HeroFileImage(
        path: job.imagePath,
        key: const ValueKey<String>('generation-submission-original-image'),
        failureLogLabel: 'original image',
        failureMessage: 'Original image could not be loaded',
      );
    }

    if (job.status != GenerationSubmissionStatus.completed &&
        job.status != GenerationSubmissionStatus.resultSaved) {
      return Center(
        child: Text(
          _statusText(job.status).toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFBBBBBB),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      );
    }

    final String? processedResultPath = job.processedResultPath;
    if (processedResultPath != null) {
      return _HeroFileImage(
        path: processedResultPath,
        key: const ValueKey<String>(
          'generation-submission-processed-result-image',
        ),
        failureLogLabel: 'processed result image',
        failureMessage: 'Processed result image could not be loaded',
      );
    }

    final String? resultUrl = job.resultUrl;
    if (resultUrl == null) {
      return const Center(
        child: Text(
          'TAP TO LOAD RESULT',
          style: TextStyle(
            color: Color(0xFFBBBBBB),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      );
    }

    return Image.network(
      resultUrl,
      key: const ValueKey<String>('generation-submission-result-image'),
      fit: BoxFit.cover,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        debugPrint(
          '[GenerationSubmissionModal] result image load failure url=$resultUrl error=$error',
        );
        return const Center(
          child: Text(
            'IMAGE LOAD FAILURE',
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

  bool _shouldUseOriginalAsHero(GenerationSubmissionJob job) {
    return job.status != GenerationSubmissionStatus.completed &&
        job.status != GenerationSubmissionStatus.resultSaved;
  }

  bool _shouldShowToggle(GenerationSubmissionJob job) {
    return job.status == GenerationSubmissionStatus.completed ||
        job.status == GenerationSubmissionStatus.resultSaved ||
        job.status == GenerationSubmissionStatus.resultProcessingFailed;
  }

  bool _shouldShowStatusOverlay(GenerationSubmissionJob job) {
    return job.status != GenerationSubmissionStatus.resultSaved &&
        (showOriginalImage ||
            job.status != GenerationSubmissionStatus.completed ||
            loading);
  }

  String _heroStatusMessage(GenerationSubmissionJob job) {
    if (loading) {
      return 'LOADING RESULT';
    }
    if (job.status == GenerationSubmissionStatus.resultProcessingFailed) {
      return (job.resultSaveErrorMessage ?? 'RESULT PROCESSING FAILED')
          .toUpperCase();
    }
    return _statusText(job.status).toUpperCase();
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

class _HeroFileImage extends StatelessWidget {
  const _HeroFileImage({
    super.key,
    required this.path,
    required this.failureLogLabel,
    required this.failureMessage,
  });

  final String path;
  final String failureLogLabel;
  final String failureMessage;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return _HeroImageFailure(message: failureMessage);
    }
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        debugPrint(
          '[GenerationSubmissionModal] $failureLogLabel load failure path=$path error=$error',
        );
        return _HeroImageFailure(message: failureMessage);
      },
    );
  }
}

class _HeroImageFailure extends StatelessWidget {
  const _HeroImageFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CupertinoColors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            key: const ValueKey<String>('generation-gallery-hero-failure'),
            style: const TextStyle(color: CupertinoColors.secondaryLabel),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _HeroStatusLabel extends StatelessWidget {
  const _HeroStatusLabel({required this.status, required this.message});

  final GenerationSubmissionStatus status;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.black.withValues(alpha: 0.64),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _StatusBadge(status: status, includeTestKey: false),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                key: const ValueKey<String>('generation-gallery-hero-status'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
