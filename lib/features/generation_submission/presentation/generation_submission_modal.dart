import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:progressive_blur/progressive_blur.dart';
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
  bool _galleryExportProgressDialogVisible = false;
  late final ValueNotifier<double> _galleryExportProgress =
      ValueNotifier<double>(0);
  List<GenerationSubmissionJob> _jobs = const <GenerationSubmissionJob>[];
  ProviderSubscription<GenerationSubmissionState>? _jobsSubscription;
  StreamSubscription<GalleryImagePickProgress>?
  _galleryExportProgressSubscription;
  late final GalleryImagePicker _galleryImagePicker;
  late final PageController _heroPageController = PageController();

  @override
  void initState() {
    super.initState();
    _galleryImagePicker = ref.read(galleryImagePickerProvider);
    _jobs = ref.read(generationSubmissionControllerProvider).jobs;
    _jobsSubscription = ref.listenManual<GenerationSubmissionState>(
      generationSubmissionControllerProvider,
      (GenerationSubmissionState? previous, GenerationSubmissionState next) {
        if (!mounted) {
          return;
        }
        setState(() {
          _jobs = next.jobs;
        });
      },
    );
  }

  @override
  void dispose() {
    _jobsSubscription?.close();
    _jobsSubscription = null;
    unawaited(_galleryExportProgressSubscription?.cancel());
    _galleryExportProgressSubscription = null;
    _galleryExportProgress.dispose();
    if (_pickingGalleryImage) {
      unawaited(_galleryImagePicker.cancelActivePick());
    }
    _heroPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<GenerationSubmissionJob> jobs = _jobs;
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
        final double maxHeroHeight = (height - 196).clamp(0.0, height);
        final double heroWidth = constraints.maxWidth.clamp(
          0.0,
          maxHeroHeight * 3 / 4,
        );
        final double heroHeight = heroWidth * 4 / 3;
        final double heroTopPadding = topInset;
        final double heroViewportHeight = (heroHeight + heroTopPadding).clamp(
          0.0,
          height,
        );
        final Widget hero = SizedBox(
          width: heroWidth,
          height: heroViewportHeight,
          child: _GalleryHeroPager(
            jobs: jobs,
            selectedJob: selectedJob,
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            pageController: _heroPageController,
            previewSize: Size(heroWidth, heroHeight),
            viewportSize: Size(heroWidth, heroViewportHeight),
            topPadding: heroTopPadding,
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
            onToggleFavorite: selectedJob == null
                ? null
                : () => unawaited(_toggleFavorite(selectedJob)),
          ),
        );
        return Stack(
          children: <Widget>[
            _TopGradientBlur(
              blurHeight: topInset,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    height: heroViewportHeight,
                    child: Center(child: hero),
                  ),
                  Expanded(
                    child: _RelatedMomentsStrip(
                      jobs: jobs,
                      selectedJob: selectedJob,
                      pickingGalleryImage: _pickingGalleryImage,
                      onPickGalleryImage: _pickGalleryImage,
                      onSelectJob: _selectJobFromStrip,
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
            if (_galleryExportProgressDialogVisible)
              _GalleryExportProgressOverlay(
                progressListenable: _galleryExportProgress,
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

  void _selectJobFromStrip(GenerationSubmissionJob job) {
    unawaited(_selectJobFromStripAsync(job));
  }

  Future<void> _selectJobFromStripAsync(GenerationSubmissionJob job) async {
    final _HeroImageSource? imageSource = _heroImageSourceForJob(job);
    if (imageSource is _HeroFileImageSource) {
      await _precacheHeroImage(imageSource.imageProvider);
    }
    if (!mounted) {
      return;
    }
    _selectJob(job);
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

  Future<void> _toggleFavorite(GenerationSubmissionJob job) async {
    _debugLog('toggle favorite job=${job.id}');
    await ref
        .read(generationSubmissionControllerProvider.notifier)
        .toggleResultFavorite(job.id);
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
    _cancelGalleryExportProgressSubscription();
    _galleryExportProgressSubscription = _galleryImagePicker.progressEvents
        .listen(_handleGalleryExportProgress);
    setState(() {
      _pickingGalleryImage = true;
    });
    _galleryExportProgress.value = 0;

    try {
      await _galleryImagePicker.cancelActivePick();
      final PickedGalleryImage? pickedImage = await _galleryImagePicker
          .pickImageFromGallery();
      _cancelGalleryExportProgressSubscription();
      if (mounted) {
        _hideGalleryExportProgressDialog();
      }
      if (!mounted) {
        _debugLog('pick gallery dropped because page was disposed');
        return;
      }
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
      _cancelGalleryExportProgressSubscription();
      if (mounted) {
        _hideGalleryExportProgressDialog();
      }
      if (mounted) {
        setState(() {
          _pickingGalleryImage = false;
        });
        _galleryExportProgress.value = 0;
      }
    }
  }

  void _cancelGalleryExportProgressSubscription() {
    final StreamSubscription<GalleryImagePickProgress>? subscription =
        _galleryExportProgressSubscription;
    _galleryExportProgressSubscription = null;
    unawaited(subscription?.cancel());
  }

  void _handleGalleryExportProgress(GalleryImagePickProgress event) {
    if (!mounted) {
      return;
    }
    final double progress = event.progress.clamp(0.0, 1.0);
    _galleryExportProgress.value = progress;
    if (progress > 0 && progress < 1) {
      _showGalleryExportProgressDialog();
    }
  }

  void _showGalleryExportProgressDialog() {
    if (_galleryExportProgressDialogVisible || !mounted) {
      return;
    }
    setState(() {
      _galleryExportProgressDialogVisible = true;
    });
  }

  void _hideGalleryExportProgressDialog() {
    if (!_galleryExportProgressDialogVisible || !mounted) {
      return;
    }
    setState(() {
      _galleryExportProgressDialogVisible = false;
    });
  }

  void _debugLog(String message) {
    debugPrint('[GenerationSubmissionModal] $message');
  }

  _HeroImageSource? _heroImageSourceForJob(GenerationSubmissionJob job) {
    if (_showOriginalImage ||
        job.status == GenerationSubmissionStatus.resultProcessingFailed ||
        (job.status != GenerationSubmissionStatus.completed &&
            job.status != GenerationSubmissionStatus.resultSaved)) {
      return _HeroFileImageSource(
        path: job.imagePath,
        key: const ValueKey<String>('generation-submission-original-image'),
        failureLogLabel: 'original image',
        failureMessage: 'Original image could not be loaded',
      );
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

  Future<void> _precacheHeroImage(ImageProvider imageProvider) {
    final Completer<void> completer = Completer<void>();
    final ImageStream stream = imageProvider.resolve(
      const ImageConfiguration(),
    );
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo image, bool synchronousCall) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );
    stream.addListener(listener);
    return completer.future.timeout(
      const Duration(milliseconds: 120),
      onTimeout: () {
        stream.removeListener(listener);
      },
    );
  }
}

class _TopGradientBlur extends StatelessWidget {
  const _TopGradientBlur({required this.blurHeight, required this.child});

  final double blurHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (blurHeight <= 0) {
      return child;
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double height = constraints.maxHeight;
        final double blurExtentStop = height > 0
            ? (blurHeight / height).clamp(0.0, 1.0)
            : 0.0;
        if (blurExtentStop <= 0) {
          return child;
        }

        return ProgressiveBlurWidget(
          sigma: 28,
          blurTextureDimensions: 384,
          linearGradientBlur: LinearGradientBlur(
            values: const <double>[1, 0],
            stops: <double>[0, blurExtentStop],
            start: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          child: child,
        );
      },
    );
  }
}

class GenerationSubmissionDebugModal extends StatelessWidget {
  const GenerationSubmissionDebugModal({super.key});

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
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

class _GalleryExportProgressOverlay extends StatelessWidget {
  const _GalleryExportProgressOverlay({required this.progressListenable});

  final ValueListenable<double> progressListenable;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.black.withValues(alpha: 0.18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: _GalleryExportProgressDialog(
              progressListenable: progressListenable,
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryExportProgressDialog extends StatelessWidget {
  const _GalleryExportProgressDialog({required this.progressListenable});

  final ValueListenable<double> progressListenable;

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('Downloading from iCloud'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ValueListenableBuilder<double>(
          valueListenable: progressListenable,
          builder: (BuildContext context, double progress, Widget? child) {
            final double clampedProgress = progress.clamp(0.0, 1.0);
            final int percent = (clampedProgress * 100).round().clamp(0, 100);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Preparing your photo...'),
                const SizedBox(height: 14),
                _GalleryExportProgressBar(progress: clampedProgress),
                const SizedBox(height: 10),
                Text('$percent%'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GalleryExportProgressBar extends StatelessWidget {
  const _GalleryExportProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('generation-gallery-export-progress-bar'),
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.border),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: const DecoratedBox(
              decoration: BoxDecoration(color: AppColors.black),
            ),
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
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final EdgeInsets contentPadding = EdgeInsets.fromLTRB(
      0,
      12,
      0,
      10 + bottomInset,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.white),
      child: Padding(
        padding: contentPadding,
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
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double itemHeight = constraints.maxHeight;
                  final double tileHeight = (itemHeight - 22).clamp(0.0, 280.0);
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

class _GalleryHeroPager extends StatefulWidget {
  const _GalleryHeroPager({
    required this.jobs,
    required this.selectedJob,
    required this.selectedIndex,
    required this.pageController,
    required this.previewSize,
    required this.viewportSize,
    required this.topPadding,
    required this.loading,
    required this.showOriginalImage,
    required this.onPageChanged,
    required this.onToggleImage,
    required this.onToggleFavorite,
  });

  final List<GenerationSubmissionJob> jobs;
  final GenerationSubmissionJob? selectedJob;
  final int selectedIndex;
  final PageController pageController;
  final Size previewSize;
  final Size viewportSize;
  final double topPadding;
  final bool loading;
  final bool showOriginalImage;
  final void Function(int index, List<GenerationSubmissionJob> jobs)
  onPageChanged;
  final VoidCallback? onToggleImage;
  final VoidCallback? onToggleFavorite;

  @override
  State<_GalleryHeroPager> createState() => _GalleryHeroPagerState();
}

class _GalleryHeroPagerState extends State<_GalleryHeroPager> {
  final Map<String, PhotoViewController> _photoControllers =
      <String, PhotoViewController>{};
  final Map<String, Size> _imageSizes = <String, Size>{};
  final Set<String> _resolvingImageSizes = <String>{};

  @override
  void didUpdateWidget(covariant _GalleryHeroPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topPadding != widget.topPadding) {
      _disposePhotoControllers();
    }
    _precacheSelectedAndNeighborImageSizes();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _precacheSelectedAndNeighborImageSizes();
    });
  }

  @override
  void dispose() {
    _disposePhotoControllers();
    super.dispose();
  }

  void _disposePhotoControllers() {
    for (final PhotoViewController controller in _photoControllers.values) {
      controller.dispose();
    }
    _photoControllers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final GenerationSubmissionJob? selectedJob = widget.selectedJob;
    if (selectedJob == null || widget.jobs.isEmpty) {
      return ColoredBox(
        color: AppColors.white,
        child: Padding(
          padding: EdgeInsets.only(top: widget.topPadding),
          child: const Center(
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
            itemCount: widget.jobs.length,
            pageController: widget.pageController,
            customSize: widget.previewSize,
            allowImplicitScrolling: true,
            onPageChanged: (int index) =>
                widget.onPageChanged(index, widget.jobs),
            backgroundDecoration: const BoxDecoration(color: AppColors.white),
            loadingBuilder: (BuildContext context, ImageChunkEvent? progress) {
              return Padding(
                padding: EdgeInsets.only(top: widget.topPadding),
                child: const Center(child: CupertinoActivityIndicator()),
              );
            },
            builder: (BuildContext context, int index) {
              return _pageOptions(widget.jobs[index]);
            },
          ),
          _HeroImageKeyMarker(imageSource: _imageSourceForJob(selectedJob)),
          if (widget.loading)
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
              showingOriginal: widget.showOriginalImage,
              onToggleImage: _canToggleHeroImage(selectedJob)
                  ? widget.onToggleImage
                  : null,
              isFavorite: selectedJob.isResultFavorite,
              onToggleFavorite: _canToggleFavorite(selectedJob)
                  ? widget.onToggleFavorite
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
    final PhotoViewController controller = _controllerForJob(job);

    final _HeroImageSource? imageSource = _imageSourceForJob(job);
    if (imageSource == null) {
      return PhotoViewGalleryPageOptions.customChild(
        child: _placeholderForJob(job),
        controller: controller,
        initialScale: initialScale,
        minScale: minScale,
        maxScale: maxScale,
        disableGestures: true,
      );
    }
    _resolveImageSize(imageSource);

    return PhotoViewGalleryPageOptions(
      imageProvider: imageSource.imageProvider,
      semanticLabel: imageSource.key.value,
      controller: controller,
      initialScale: initialScale,
      minScale: minScale,
      maxScale: maxScale,
      basePosition: _basePositionForSource(imageSource),
      filterQuality: FilterQuality.medium,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        debugPrint(
          '[GenerationSubmissionModal] ${imageSource.failureLogLabel} load failure path=${imageSource.debugPath} error=$error',
        );
        return _HeroImageFailure(message: imageSource.failureMessage);
      },
    );
  }

  PhotoViewController _controllerForJob(GenerationSubmissionJob job) {
    return _photoControllers.putIfAbsent(job.id, () {
      return PhotoViewController();
    });
  }

  Alignment _basePositionForSource(_HeroImageSource imageSource) {
    final double viewportHeight = widget.viewportSize.height;
    final double previewHeight = widget.previewSize.height;
    final double topPadding = widget.topPadding;
    if (viewportHeight <= 0 || previewHeight <= 0 || topPadding <= 0) {
      return Alignment.center;
    }

    final Size? imageSize = _imageSizes[imageSource.debugPath];
    if (imageSize == null || imageSize.width <= 0 || imageSize.height <= 0) {
      return Alignment.center;
    }

    final double containedScale = _containedScale(
      widget.previewSize,
      imageSize,
    );
    final double displayedImageHeight = imageSize.height * containedScale;
    final double extraSpace = viewportHeight - displayedImageHeight;
    if (extraSpace <= 0) {
      return Alignment.center;
    }

    final double defaultTop =
        topPadding + (previewHeight - displayedImageHeight) / 2;
    final double targetAlignmentY = (defaultTop / extraSpace) * 2 - 1;
    return Alignment(0, targetAlignmentY.clamp(-1.0, 1.0));
  }

  double _containedScale(Size viewportSize, Size imageSize) {
    return (viewportSize.width / imageSize.width).clamp(0.0, double.infinity) <
            (viewportSize.height / imageSize.height).clamp(0.0, double.infinity)
        ? viewportSize.width / imageSize.width
        : viewportSize.height / imageSize.height;
  }

  void _resolveImageSize(_HeroImageSource imageSource) {
    final String debugPath = imageSource.debugPath;
    if (_imageSizes.containsKey(debugPath) ||
        _resolvingImageSizes.contains(debugPath)) {
      return;
    }

    _resolvingImageSizes.add(debugPath);
    final ImageStream stream = imageSource.imageProvider.resolve(
      const ImageConfiguration(),
    );
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        stream.removeListener(listener);
        final Size imageSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        if (synchronousCall) {
          _resolvingImageSizes.remove(debugPath);
          _imageSizes[debugPath] = imageSize;
          return;
        }
        _setStateAfterBuild(() {
          _resolvingImageSizes.remove(debugPath);
          _imageSizes[debugPath] = imageSize;
        });
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        _setStateAfterBuild(() {
          _resolvingImageSizes.remove(debugPath);
        });
      },
    );
    stream.addListener(listener);
  }

  void _precacheSelectedAndNeighborImageSizes() {
    final int selectedIndex = widget.selectedIndex;
    for (final int index in <int>[
      selectedIndex,
      selectedIndex - 1,
      selectedIndex + 1,
    ]) {
      if (index < 0 || index >= widget.jobs.length) {
        continue;
      }
      final _HeroImageSource? imageSource = _imageSourceForJob(
        widget.jobs[index],
      );
      if (imageSource == null) {
        continue;
      }
      _resolveImageSize(imageSource);
    }
  }

  void _setStateAfterBuild(VoidCallback update) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(update);
    });
  }

  _HeroImageSource? _imageSourceForJob(GenerationSubmissionJob job) {
    if (widget.showOriginalImage) {
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

  bool _canToggleFavorite(GenerationSubmissionJob job) {
    return job.status == GenerationSubmissionStatus.resultSaved &&
        job.resultAssetId != null &&
        job.resultAssetId!.isNotEmpty;
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
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final bool showingOriginal;
  final VoidCallback? onToggleImage;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

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
                  _FavoriteButton(
                    isFavorite: isFavorite,
                    onPressed: onToggleFavorite,
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

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.onPressed});

  final bool isFavorite;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    return _HeroToolbarButton(
      key: const ValueKey<String>('generation-submission-favorite-toggle'),
      icon: LucideIcons.heart,
      onPressed: onPressed,
      color: isFavorite ? AppColors.accentYellow : AppColors.white,
      opacity: enabled ? 1.0 : 0.38,
    );
  }
}

class _HeroToolbarButton extends StatelessWidget {
  const _HeroToolbarButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.white,
    this.opacity = 1.0,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
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
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
