import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:smooth_corner/smooth_corner.dart';

import '../../../theme/app_colors.dart';
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
      backgroundColor: AppColors.white,
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
  late final PageController _heroPageController = PageController();

  @override
  void dispose() {
    if (_pickingGalleryImage) {
      unawaited(ref.read(galleryImagePickerProvider).cancelActivePick());
    }
    _heroPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<GenerationSubmissionJob> jobs = ref
        .watch(generationSubmissionControllerProvider)
        .jobs;
    final GenerationSubmissionJob? selectedJob = _selectedJob(jobs);
    final int selectedIndex = selectedJob == null
        ? 0
        : jobs.indexWhere((GenerationSubmissionJob job) {
            return job.id == selectedJob.id;
          });
    if (selectedJob != null && selectedIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _syncHeroPageToSelection(selectedIndex, animate: false);
      });
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double topInset = MediaQuery.paddingOf(context).top;
        final double height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final double availableContentHeight = (height - topInset).clamp(
          0.0,
          double.infinity,
        );
        final double maxHeroHeight = (availableContentHeight - 196).clamp(
          0.0,
          availableContentHeight,
        );
        final double heroWidth = constraints.maxWidth.clamp(
          0.0,
          maxHeroHeight * 3 / 4,
        );
        final double heroHeight = heroWidth * 4 / 3;
        final Widget hero = SizedBox(
          width: heroWidth,
          height: heroHeight,
          child: _GalleryHeroPager(
            jobs: jobs,
            selectedJob: selectedJob,
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            pageController: _heroPageController,
            loading: _loadingResultJobId == selectedJob?.id,
            showOriginalImage: _showOriginalImage,
            onPageChanged: _selectJobAtPage,
            onToggleImage: selectedJob == null
                ? null
                : () {
                    setState(() {
                      _showOriginalImage = !_showOriginalImage;
                    });
                  },
          ),
        );
        return Stack(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(top: topInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    height: heroHeight,
                    child: Center(child: hero),
                  ),
                  Expanded(
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
              ),
            ),
            _GalleryCloseButton(onClose: () => Navigator.of(context).pop()),
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

  void _syncHeroPageToSelection(int index, {required bool animate}) {
    if (!_heroPageController.hasClients) {
      return;
    }
    final double? page = _heroPageController.page;
    final int currentPage = page == null
        ? _heroPageController.initialPage
        : page.round();
    if (currentPage == index) {
      return;
    }
    if (animate) {
      unawaited(
        _heroPageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }
    _heroPageController.jumpToPage(index);
  }

  void _selectJobAtPage(int index, List<GenerationSubmissionJob> jobs) {
    if (index < 0 || index >= jobs.length) {
      return;
    }
    _selectJob(jobs[index], syncHeroPage: false);
  }

  void _selectJob(GenerationSubmissionJob job, {bool syncHeroPage = true}) {
    _debugLog(
      'select job=${job.id} status=${job.status.name} task=${job.taskId ?? 'none'} resultCached=${job.resultUrl != null}',
    );
    setState(() {
      _selectedJobId = job.id;
      _showOriginalImage = false;
    });
    if (syncHeroPage) {
      final List<GenerationSubmissionJob> jobs = ref
          .read(generationSubmissionControllerProvider)
          .jobs;
      final int index = jobs.indexWhere((GenerationSubmissionJob item) {
        return item.id == job.id;
      });
      if (index >= 0) {
        _syncHeroPageToSelection(index, animate: true);
      }
    }
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
            decoration: BoxDecoration(color: AppColors.white),
            child: _GenerationSubmissionGalleryContent(),
          ),
        ),
      ),
    );
  }
}

class _GalleryCloseButton extends StatelessWidget {
  const _GalleryCloseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.paddingOf(context).top;
    return Positioned(
      left: 14,
      top: (topInset - 4).clamp(8.0, 54.0),
      child: CupertinoButton(
        key: const ValueKey<String>('generation-submission-modal-close'),
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(44),
        onPressed: onClose,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.shadowBlack10,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SizedBox.square(
            dimension: 36,
            child: Icon(CupertinoIcons.xmark, color: AppColors.black, size: 18),
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
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
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
                    color: AppColors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(
                height: 0.5,
                child: ColoredBox(color: AppColors.borderSubtle),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double itemHeight = constraints.maxHeight;
                    final double tileHeight = (itemHeight - 22).clamp(
                      0.0,
                      280.0,
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
              color: AppColors.textMuted,
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
          color: AppColors.surface,
          border: Border.all(color: AppColors.border, width: 0.5),
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
                  color: AppColors.black,
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
            color: selected ? AppColors.accentYellow : AppColors.border,
            width: selected ? 3 : 0.5,
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
      color: AppColors.surfaceMuted,
      child: Center(
        child: Icon(
          CupertinoIcons.photo,
          color: AppColors.secondaryLabel.resolveFrom(context),
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
          color: AppColors.blackOverlay(0.45),
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
              color: AppColors.white,
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
  const _StatusBadge({required this.status});

  final GenerationSubmissionStatus status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.blackOverlay(0.45),
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
        key: const ValueKey<String>('generation-submission-status-awaiting'),
        color: AppColors.white,
        size: 16,
      ),
      GenerationSubmissionStatus.resultSaved => Icon(
        CupertinoIcons.check_mark_circled_solid,
        key: const ValueKey<String>(
          'generation-submission-status-result-saved',
        ),
        color: AppColors.success,
        size: 16,
      ),
      GenerationSubmissionStatus.resultProcessingFailed => Icon(
        CupertinoIcons.exclamationmark_circle_fill,
        key: const ValueKey<String>(
          'generation-submission-status-result-processing-failed',
        ),
        color: AppColors.danger,
        size: 16,
      ),
      GenerationSubmissionStatus.completed => Icon(
        CupertinoIcons.check_mark_circled_solid,
        key: const ValueKey<String>('generation-submission-status-completed'),
        color: AppColors.success,
        size: 16,
      ),
      GenerationSubmissionStatus.failed => Icon(
        CupertinoIcons.exclamationmark_circle_fill,
        key: const ValueKey<String>('generation-submission-status-failed'),
        color: AppColors.danger,
        size: 16,
      ),
      _ => CupertinoActivityIndicator(
        key: const ValueKey<String>('generation-submission-status-processing'),
        color: AppColors.white,
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
          color: AppColors.danger,
          icon: CupertinoIcons.xmark,
          onPressed: onCancel,
        ),
        _ThumbnailActionButton(
          key: ValueKey<String>('generation-submission-confirm-$jobId'),
          color: AppColors.success,
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
          child: Icon(icon, color: AppColors.white, size: 14),
        ),
      ),
    );
  }
}

class _GalleryHeroPager extends StatelessWidget {
  const _GalleryHeroPager({
    required this.jobs,
    required this.selectedJob,
    required this.selectedIndex,
    required this.pageController,
    required this.loading,
    required this.showOriginalImage,
    required this.onPageChanged,
    required this.onToggleImage,
  });

  final List<GenerationSubmissionJob> jobs;
  final GenerationSubmissionJob? selectedJob;
  final int selectedIndex;
  final PageController pageController;
  final bool loading;
  final bool showOriginalImage;
  final void Function(int index, List<GenerationSubmissionJob> jobs)
  onPageChanged;
  final VoidCallback? onToggleImage;

  @override
  Widget build(BuildContext context) {
    final GenerationSubmissionJob? selectedJob = this.selectedJob;
    if (selectedJob == null || jobs.isEmpty) {
      return const ColoredBox(
        color: AppColors.white,
        child: Center(
          child: Text(
            'SELECT A MOMENT',
            key: ValueKey<String>('generation-gallery-empty-hero'),
            style: TextStyle(
              color: AppColors.textPlaceholder,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppColors.white,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PhotoViewGallery.builder(
            key: const ValueKey<String>('generation-gallery-hero-pager'),
            itemCount: jobs.length,
            pageController: pageController,
            onPageChanged: (int index) => onPageChanged(index, jobs),
            backgroundDecoration: const BoxDecoration(color: AppColors.white),
            loadingBuilder: (BuildContext context, ImageChunkEvent? progress) {
              return const Center(child: CupertinoActivityIndicator());
            },
            builder: (BuildContext context, int index) {
              return _pageOptions(jobs[index]);
            },
          ),
          _HeroImageKeyMarker(imageSource: _imageSourceForJob(selectedJob)),
          if (loading)
            const Center(
              child: CupertinoActivityIndicator(
                key: ValueKey<String>('generation-submission-result-loading'),
                color: AppColors.white,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: _HeroToolbar(
              showingOriginal: showOriginalImage,
              onToggleImage: _canToggleHeroImage(selectedJob)
                  ? onToggleImage
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  PhotoViewGalleryPageOptions _pageOptions(GenerationSubmissionJob job) {
    const PhotoViewComputedScale minScale = PhotoViewComputedScale.contained;
    const PhotoViewComputedScale initialScale =
        PhotoViewComputedScale.contained;
    final PhotoViewComputedScale maxScale = PhotoViewComputedScale.covered * 3;

    final _HeroImageSource? imageSource = _imageSourceForJob(job);
    if (imageSource == null) {
      return PhotoViewGalleryPageOptions.customChild(
        child: _placeholderForJob(job),
        initialScale: initialScale,
        minScale: minScale,
        maxScale: maxScale,
        disableGestures: true,
      );
    }

    return PhotoViewGalleryPageOptions(
      imageProvider: imageSource.imageProvider,
      semanticLabel: imageSource.key.value,
      initialScale: initialScale,
      minScale: minScale,
      maxScale: maxScale,
      basePosition: Alignment.center,
      filterQuality: FilterQuality.medium,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        debugPrint(
          '[GenerationSubmissionModal] ${imageSource.failureLogLabel} load failure path=${imageSource.debugPath} error=$error',
        );
        return _HeroImageFailure(message: imageSource.failureMessage);
      },
    );
  }

  _HeroImageSource? _imageSourceForJob(GenerationSubmissionJob job) {
    if (showOriginalImage) {
      return _HeroFileImageSource(
        path: job.imagePath,
        key: const ValueKey<String>('generation-submission-original-image'),
        failureLogLabel: 'original image',
        failureMessage: 'Original image could not be loaded',
      );
    }

    if (_shouldUseOriginalAsHero(job)) {
      return _HeroFileImageSource(
        path: job.imagePath,
        key: const ValueKey<String>('generation-submission-original-image'),
        failureLogLabel: 'original image',
        failureMessage: 'Original image could not be loaded',
      );
    }

    if (job.status == GenerationSubmissionStatus.resultProcessingFailed) {
      return _HeroFileImageSource(
        path: job.imagePath,
        key: const ValueKey<String>('generation-submission-original-image'),
        failureLogLabel: 'original image',
        failureMessage: 'Original image could not be loaded',
      );
    }

    if (job.status != GenerationSubmissionStatus.completed &&
        job.status != GenerationSubmissionStatus.resultSaved) {
      return null;
    }

    final String? processedResultPath = job.processedResultPath;
    if (processedResultPath != null) {
      return _HeroFileImageSource(
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
      return null;
    }

    return _HeroNetworkImageSource(
      url: resultUrl,
      key: const ValueKey<String>('generation-submission-result-image'),
      failureLogLabel: 'result image',
      failureMessage: 'Result image could not be loaded',
    );
  }

  Widget _placeholderForJob(GenerationSubmissionJob job) {
    final String text;
    if (job.status == GenerationSubmissionStatus.completed ||
        job.status == GenerationSubmissionStatus.resultSaved) {
      text = 'TAP TO LOAD RESULT';
    } else {
      text = _statusText(job.status).toUpperCase();
    }

    return Center(
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPlaceholder,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  bool _shouldUseOriginalAsHero(GenerationSubmissionJob job) {
    return job.status != GenerationSubmissionStatus.completed &&
        job.status != GenerationSubmissionStatus.resultSaved;
  }

  bool _canToggleHeroImage(GenerationSubmissionJob job) {
    if (job.imagePath.isEmpty) {
      return false;
    }

    return switch (job.status) {
      GenerationSubmissionStatus.completed => job.resultUrl != null,
      GenerationSubmissionStatus.resultSaved => job.processedResultPath != null,
      _ => false,
    };
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

abstract class _HeroImageSource {
  const _HeroImageSource({
    required this.path,
    required this.key,
    required this.failureLogLabel,
    required this.failureMessage,
  });

  final String path;
  final ValueKey<String> key;
  final String failureLogLabel;
  final String failureMessage;

  ImageProvider get imageProvider;

  String get debugPath => path;
}

class _HeroFileImageSource extends _HeroImageSource {
  const _HeroFileImageSource({
    required super.path,
    required super.key,
    required super.failureLogLabel,
    required super.failureMessage,
  });

  @override
  ImageProvider get imageProvider => FileImage(File(path));
}

class _HeroNetworkImageSource extends _HeroImageSource {
  const _HeroNetworkImageSource({
    required String url,
    required super.key,
    required super.failureLogLabel,
    required super.failureMessage,
  }) : super(path: url);

  @override
  ImageProvider get imageProvider => NetworkImage(path);

  @override
  String get debugPath => path;
}

class _HeroImageKeyMarker extends StatelessWidget {
  const _HeroImageKeyMarker({required this.imageSource});

  final _HeroImageSource? imageSource;

  @override
  Widget build(BuildContext context) {
    final _HeroImageSource? imageSource = this.imageSource;
    if (imageSource == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(child: SizedBox.shrink(key: imageSource.key));
  }
}

class _HeroImageFailure extends StatelessWidget {
  const _HeroImageFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            key: const ValueKey<String>('generation-gallery-hero-failure'),
            style: TextStyle(
              color: AppColors.secondaryLabel.resolveFrom(context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _HeroToolbar extends StatelessWidget {
  const _HeroToolbar({
    required this.showingOriginal,
    required this.onToggleImage,
  });

  final bool showingOriginal;
  final VoidCallback? onToggleImage;

  @override
  Widget build(BuildContext context) {
    final SmoothRectangleBorder toolbarShape = SmoothRectangleBorder(
      borderRadius: BorderRadius.circular(999),
      smoothness: 0.8,
      side: BorderSide(
        color: AppColors.white.withValues(alpha: 0.18),
        width: 0.5,
      ),
    );

    return Center(
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: toolbarShape),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: AppColors.blackOverlay(0.42),
              shape: toolbarShape,
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _ImageToggleButton(
                    showingOriginal: showingOriginal,
                    onPressed: onToggleImage,
                  ),
                  const _HeroToolbarButton(
                    key: ValueKey<String>('generation-submission-more-actions'),
                    icon: LucideIcons.moreHorizontal,
                    onPressed: _noop,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _noop() {}

class _ImageToggleButton extends StatelessWidget {
  const _ImageToggleButton({
    required this.showingOriginal,
    required this.onPressed,
  });

  final bool showingOriginal;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    return _HeroToolbarButton(
      key: const ValueKey<String>('generation-submission-image-toggle'),
      icon: showingOriginal ? LucideIcons.sparkles : LucideIcons.image,
      onPressed: onPressed,
      opacity: enabled ? 1.0 : 0.38,
    );
  }
}

class _HeroToolbarButton extends StatelessWidget {
  const _HeroToolbarButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.opacity = 1.0,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(36),
      onPressed: onPressed,
      child: Opacity(
        opacity: opacity,
        child: SizedBox.square(
          dimension: 36,
          child: Icon(icon, color: AppColors.white, size: 18),
        ),
      ),
    );
  }
}
