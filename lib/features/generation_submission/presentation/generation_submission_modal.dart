import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:progressive_blur/progressive_blur.dart';
import 'package:smooth_corner/smooth_corner.dart';

import '../../../app/app_router.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_corners.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../backend_api/domain/prompt_config.dart';
import '../data/generation_submission_adapters.dart';
import '../domain/generation_submission_job.dart';
import 'generation_hero_photo_view_page_options.dart';
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
  const GenerationSubmissionGalleryPage({this.focusedTaskId, super.key});

  final String? focusedTaskId;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return PopScope<void>(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (bool didPop, void result) {
        if (!didPop) {
          context.go(appHomeRoute);
        }
      },
      child: CupertinoPageScaffold(
        backgroundColor: colors.background,
        child: _GenerationSubmissionGalleryContent(
          focusedTaskId: focusedTaskId,
        ),
      ),
    );
  }
}

class _GenerationSubmissionGalleryContent extends ConsumerStatefulWidget {
  const _GenerationSubmissionGalleryContent({this.focusedTaskId});

  final String? focusedTaskId;

  @override
  ConsumerState<_GenerationSubmissionGalleryContent> createState() =>
      _GenerationSubmissionDebugModalState();
}

enum _GalleryHeroImageKind { original, result }

enum _GalleryHeroArrivalPhase { idle, precaching, animating, done }

class _GalleryHeroDisplayState {
  const _GalleryHeroDisplayState({
    required this.displayedKind,
    required this.phase,
  });

  final _GalleryHeroImageKind displayedKind;
  final _GalleryHeroArrivalPhase phase;
}

class _GenerationSubmissionDebugModalState
    extends ConsumerState<_GenerationSubmissionGalleryContent> {
  String? _selectedJobId;
  String? _loadingResultJobId;
  bool _pickingGalleryImage = false;
  bool _galleryExportProgressDialogVisible = false;
  final Map<String, _GalleryHeroDisplayState> _heroDisplayStates =
      <String, _GalleryHeroDisplayState>{};
  final Set<String> _knownLocalSavedResultJobIds = <String>{};
  bool _hasProcessedInitialJobs = false;
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
    unawaited(_resumeActiveRecordsForGallery());
    _jobs = ref.read(generationSubmissionControllerProvider).jobs;
    _knownLocalSavedResultJobIds.addAll(_localSavedResultJobIds(_jobs));
    _hasProcessedInitialJobs = _jobs.isNotEmpty;
    _selectFocusedTaskIfPresent(_jobs, animate: false);
    _jobsSubscription = ref.listenManual<GenerationSubmissionState>(
      generationSubmissionControllerProvider,
      (GenerationSubmissionState? previous, GenerationSubmissionState next) {
        if (!mounted) {
          return;
        }
        final bool isInitialJobsUpdate = !_hasProcessedInitialJobs;
        final GenerationSubmissionJob? resultArrivalPrecacheJob =
            isInitialJobsUpdate
            ? null
            : _nextUnseenSelectedResultArrivalJob(next.jobs);
        setState(() {
          _jobs = next.jobs;
          _hasProcessedInitialJobs = true;
          if (resultArrivalPrecacheJob != null) {
            _heroDisplayStates[resultArrivalPrecacheJob.id] =
                const _GalleryHeroDisplayState(
                  displayedKind: _GalleryHeroImageKind.original,
                  phase: _GalleryHeroArrivalPhase.precaching,
                );
          }
          _syncHeroDisplayStatesWithJobs(next.jobs);
          _knownLocalSavedResultJobIds.addAll(
            _localSavedResultJobIds(next.jobs),
          );
        });
        if (resultArrivalPrecacheJob != null) {
          unawaited(
            _precacheAndStartResultArrivalAnimation(resultArrivalPrecacheJob),
          );
        }
        _selectFocusedTaskIfPresent(next.jobs, animate: true);
      },
    );
  }

  Future<void> _resumeActiveRecordsForGallery() async {
    try {
      await ref
          .read(generationSubmissionControllerProvider.notifier)
          .resumeActiveRecords();
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'generation submission gallery',
          context: ErrorDescription('while resuming active generation records'),
        ),
      );
    }
  }

  void _selectFocusedTaskIfPresent(
    List<GenerationSubmissionJob> jobs, {
    required bool animate,
  }) {
    final String? focusedTaskId = widget.focusedTaskId;
    if (focusedTaskId == null || focusedTaskId.isEmpty) {
      return;
    }
    final int index = jobs.indexWhere((GenerationSubmissionJob job) {
      return job.taskId == focusedTaskId;
    });
    if (index < 0) {
      return;
    }
    final GenerationSubmissionJob job = jobs[index];
    if (_selectedJobId == job.id) {
      return;
    }
    _selectJob(job, syncHeroPage: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncHeroPageToSelection(index, animate: animate);
    });
  }

  void _syncHeroDisplayStatesWithJobs(List<GenerationSubmissionJob> jobs) {
    final Set<String> jobIds = jobs
        .map((GenerationSubmissionJob job) => job.id)
        .toSet();
    _heroDisplayStates.removeWhere((String jobId, _) {
      return !jobIds.contains(jobId);
    });
    for (final GenerationSubmissionJob job in jobs) {
      final _GalleryHeroDisplayState? current = _heroDisplayStates[job.id];
      if (!_hasLocalSavedResult(job)) {
        if (current != null &&
            current.phase != _GalleryHeroArrivalPhase.precaching &&
            current.phase != _GalleryHeroArrivalPhase.animating) {
          _heroDisplayStates.remove(job.id);
        }
        continue;
      }
      if (current == null && _knownLocalSavedResultJobIds.contains(job.id)) {
        _heroDisplayStates[job.id] = const _GalleryHeroDisplayState(
          displayedKind: _GalleryHeroImageKind.result,
          phase: _GalleryHeroArrivalPhase.done,
        );
      }
    }
  }

  _GalleryHeroDisplayState _heroDisplayStateForJob(
    GenerationSubmissionJob job,
  ) {
    final _GalleryHeroDisplayState? state = _heroDisplayStates[job.id];
    if (state != null) {
      return state;
    }
    if (_hasDisplayableResult(job)) {
      return const _GalleryHeroDisplayState(
        displayedKind: _GalleryHeroImageKind.result,
        phase: _GalleryHeroArrivalPhase.done,
      );
    }
    return const _GalleryHeroDisplayState(
      displayedKind: _GalleryHeroImageKind.original,
      phase: _GalleryHeroArrivalPhase.idle,
    );
  }

  void _setHeroDisplayState(
    String jobId,
    _GalleryHeroDisplayState displayState,
  ) {
    _heroDisplayStates[jobId] = displayState;
  }

  void _resetHeroDisplayStateToResultIfAvailable(GenerationSubmissionJob job) {
    if (_hasDisplayableResult(job)) {
      _setHeroDisplayState(
        job.id,
        const _GalleryHeroDisplayState(
          displayedKind: _GalleryHeroImageKind.result,
          phase: _GalleryHeroArrivalPhase.done,
        ),
      );
      return;
    }
    _heroDisplayStates.remove(job.id);
  }

  void _toggleHeroDisplayState(GenerationSubmissionJob job) {
    final _GalleryHeroDisplayState current = _heroDisplayStateForJob(job);
    final bool showOriginal =
        current.displayedKind == _GalleryHeroImageKind.result;
    _setHeroDisplayState(
      job.id,
      _GalleryHeroDisplayState(
        displayedKind: showOriginal
            ? _GalleryHeroImageKind.original
            : _GalleryHeroImageKind.result,
        phase: _GalleryHeroArrivalPhase.done,
      ),
    );
  }

  void _handleResultArrivalAnimationCompleted(String jobId) {
    if (!mounted) {
      return;
    }
    setState(() {
      _heroDisplayStates[jobId] = const _GalleryHeroDisplayState(
        displayedKind: _GalleryHeroImageKind.result,
        phase: _GalleryHeroArrivalPhase.done,
      );
    });
  }

  void _clearResultArrivalStateForJob(String jobId) {
    final _GalleryHeroDisplayState? current = _heroDisplayStates[jobId];
    if (current == null) {
      return;
    }
    if (current.phase == _GalleryHeroArrivalPhase.precaching ||
        current.phase == _GalleryHeroArrivalPhase.animating) {
      _heroDisplayStates[jobId] = const _GalleryHeroDisplayState(
        displayedKind: _GalleryHeroImageKind.original,
        phase: _GalleryHeroArrivalPhase.idle,
      );
    }
  }

  bool _isResultArrivalInFlight(String jobId) {
    final _GalleryHeroArrivalPhase? phase = _heroDisplayStates[jobId]?.phase;
    return phase == _GalleryHeroArrivalPhase.precaching ||
        phase == _GalleryHeroArrivalPhase.animating;
  }

  bool _hasAnimatedResultArrival(String jobId) {
    final _GalleryHeroDisplayState? state = _heroDisplayStates[jobId];
    return state?.displayedKind == _GalleryHeroImageKind.result &&
        state?.phase == _GalleryHeroArrivalPhase.done;
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
            displayStates: _heroDisplayStates,
            onPageChanged: _selectJobAtPage,
            onToggleImage: selectedJob == null
                ? null
                : () {
                    setState(() {
                      _toggleHeroDisplayState(selectedJob);
                    });
                  },
            onResultArrivalAnimationCompleted:
                _handleResultArrivalAnimationCompleted,
            onToggleFavorite: selectedJob == null
                ? null
                : () => unawaited(_toggleFavorite(selectedJob)),
            onMoreActions: selectedJob == null
                ? null
                : (_HeroMoreAction action) =>
                      unawaited(_performMoreAction(action, selectedJob)),
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
                      onRetryJob: (GenerationSubmissionJob job) {
                        unawaited(_retryJob(job));
                      },
                      onRemoveJob: (GenerationSubmissionJob job) {
                        unawaited(_removeJob(job));
                      },
                    ),
                  ),
                ],
              ),
            ),
            _GalleryCloseButton(onClose: _closeGallery),
            if (_galleryExportProgressDialogVisible)
              _GalleryExportProgressOverlay(
                progressListenable: _galleryExportProgress,
              ),
          ],
        );
      },
    );
  }

  void _closeGallery() {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.go(appHomeRoute);
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

  GenerationSubmissionJob? _nextUnseenSelectedResultArrivalJob(
    List<GenerationSubmissionJob> nextJobs,
  ) {
    final String? selectedJobId =
        _selectedJobId ?? (nextJobs.isEmpty ? null : nextJobs.first.id);
    if (selectedJobId == null ||
        _isResultArrivalInFlight(selectedJobId) ||
        _hasAnimatedResultArrival(selectedJobId)) {
      return null;
    }
    final GenerationSubmissionJob? nextJob = _findJobById(
      nextJobs,
      selectedJobId,
    );
    if (nextJob == null) {
      return null;
    }
    if (_knownLocalSavedResultJobIds.contains(nextJob.id) ||
        !_hasLocalSavedResult(nextJob)) {
      return null;
    }
    return nextJob;
  }

  Iterable<String> _localSavedResultJobIds(List<GenerationSubmissionJob> jobs) {
    return jobs
        .where(_hasLocalSavedResult)
        .map((GenerationSubmissionJob job) => job.id);
  }

  GenerationSubmissionJob? _findJobById(
    List<GenerationSubmissionJob> jobs,
    String id,
  ) {
    for (final GenerationSubmissionJob job in jobs) {
      if (job.id == id) {
        return job;
      }
    }
    return null;
  }

  bool _hasLocalSavedResult(GenerationSubmissionJob job) {
    return job.status == GenerationSubmissionStatus.resultSaved &&
        job.processedResultPath != null;
  }

  bool _hasDisplayableResult(GenerationSubmissionJob job) {
    if (_hasLocalSavedResult(job)) {
      return true;
    }
    return job.status == GenerationSubmissionStatus.completed &&
        job.resultUrl != null;
  }

  Future<void> _precacheAndStartResultArrivalAnimation(
    GenerationSubmissionJob job,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final String? processedResultPath = job.processedResultPath;
    if (processedResultPath == null) {
      _finishPendingResultArrivalPrecache(job.id);
      return;
    }

    final _HeroFileImageSource originalImageSource = _HeroFileImageSource(
      path: job.imagePath,
      key: const ValueKey<String>('generation-submission-original-image'),
      failureLogLabel: 'original image',
      failureMessage: l10n.generationSubmissionOriginalImageLoadFailed,
    );
    final _HeroFileImageSource resultImageSource = _HeroFileImageSource(
      path: processedResultPath,
      key: const ValueKey<String>(
        'generation-submission-processed-result-image',
      ),
      failureLogLabel: 'processed result image',
      failureMessage: l10n.generationSubmissionProcessedResultImageLoadFailed,
    );
    final HeroImagePrecache precache = ref.read(heroImagePrecacheProvider);
    final List<bool> precacheResults = await Future.wait(<Future<bool>>[
      precache(originalImageSource.imageProvider),
      precache(resultImageSource.imageProvider),
    ]);
    if (!mounted) {
      return;
    }

    final bool precached = precacheResults.every((bool result) => result);
    final bool stillSelected = _selectedJob(_jobs)?.id == job.id;
    final bool stillHasLocalResult = _hasLocalSavedResult(
      _findJobById(_jobs, job.id) ?? job,
    );
    final bool shouldAnimate =
        precached && stillSelected && stillHasLocalResult;

    setState(() {
      if (shouldAnimate) {
        _heroDisplayStates[job.id] = const _GalleryHeroDisplayState(
          displayedKind: _GalleryHeroImageKind.original,
          phase: _GalleryHeroArrivalPhase.animating,
        );
      } else if (stillHasLocalResult) {
        _heroDisplayStates[job.id] = const _GalleryHeroDisplayState(
          displayedKind: _GalleryHeroImageKind.result,
          phase: _GalleryHeroArrivalPhase.done,
        );
      } else {
        _heroDisplayStates[job.id] = const _GalleryHeroDisplayState(
          displayedKind: _GalleryHeroImageKind.original,
          phase: _GalleryHeroArrivalPhase.idle,
        );
      }
    });
  }

  void _finishPendingResultArrivalPrecache(String jobId) {
    if (!mounted) {
      return;
    }
    setState(() {
      _clearResultArrivalStateForJob(jobId);
    });
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
      await ref.read(heroImagePrecacheProvider)(imageSource.imageProvider);
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
      if (!_isResultArrivalInFlight(job.id)) {
        _resetHeroDisplayStateToResultIfAvailable(job);
      }
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
      _heroDisplayStates[job.id] = const _GalleryHeroDisplayState(
        displayedKind: _GalleryHeroImageKind.original,
        phase: _GalleryHeroArrivalPhase.idle,
      );
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
        _heroDisplayStates.remove(job.id);
      });
    }
  }

  Future<void> _retryJob(GenerationSubmissionJob job) async {
    _debugLog('retry job=${job.id}');
    setState(() {
      _selectedJobId = job.id;
      _heroDisplayStates[job.id] = const _GalleryHeroDisplayState(
        displayedKind: _GalleryHeroImageKind.original,
        phase: _GalleryHeroArrivalPhase.idle,
      );
    });
    await ref
        .read(generationSubmissionControllerProvider.notifier)
        .retryJob(job.id);
  }

  Future<void> _removeJob(GenerationSubmissionJob job) async {
    _debugLog('remove job=${job.id}');
    await ref
        .read(generationSubmissionControllerProvider.notifier)
        .removeJob(job.id);
    if (!mounted) {
      return;
    }
    setState(() {
      if (_selectedJobId == job.id) {
        _selectedJobId = null;
        _loadingResultJobId = null;
      }
      _heroDisplayStates.remove(job.id);
    });
  }

  Future<void> _toggleFavorite(GenerationSubmissionJob job) async {
    _debugLog('toggle favorite job=${job.id}');
    await ref
        .read(generationSubmissionControllerProvider.notifier)
        .toggleResultFavorite(job.id);
  }

  Future<void> _performMoreAction(
    _HeroMoreAction action,
    GenerationSubmissionJob job,
  ) async {
    final GenerationSubmissionController controller = ref.read(
      generationSubmissionControllerProvider.notifier,
    );
    try {
      switch (action) {
        case _HeroMoreAction.viewInAlbum:
          _debugLog('more action view in album job=${job.id}');
          await controller.openPhotoLibrary(job.id);
        case _HeroMoreAction.saveOriginal:
          _debugLog('more action save original job=${job.id}');
          await controller.saveOriginalToPhotoLibrary(job.id);
        case _HeroMoreAction.retry:
          _debugLog('more action retry job=${job.id}');
          await _retryJob(job);
        case _HeroMoreAction.dislike:
          _debugLog('more action dislike job=${job.id}');
          await controller.submitNegativeFeedback(job.id);
        case _HeroMoreAction.remove:
          _debugLog('more action remove job=${job.id}');
          await _removeJob(job);
      }
    } on Object catch (error) {
      _debugLog(
        'more action failure job=${job.id} action=${action.name} error=$error',
      );
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
      if (url != null && _selectedJob(_jobs)?.id == jobId) {
        _heroDisplayStates[jobId] = const _GalleryHeroDisplayState(
          displayedKind: _GalleryHeroImageKind.result,
          phase: _GalleryHeroArrivalPhase.done,
        );
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
    final AppLocalizations l10n = context.l10n;
    final _GalleryHeroDisplayState displayState = _heroDisplayStateForJob(job);
    if (displayState.displayedKind == _GalleryHeroImageKind.original ||
        displayState.phase == _GalleryHeroArrivalPhase.precaching ||
        displayState.phase == _GalleryHeroArrivalPhase.animating ||
        job.status == GenerationSubmissionStatus.resultProcessingFailed ||
        (job.status != GenerationSubmissionStatus.completed &&
            job.status != GenerationSubmissionStatus.resultSaved)) {
      return _HeroFileImageSource(
        path: job.imagePath,
        key: const ValueKey<String>('generation-submission-original-image'),
        failureLogLabel: 'original image',
        failureMessage: l10n.generationSubmissionOriginalImageLoadFailed,
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
        failureMessage: l10n.generationSubmissionProcessedResultImageLoadFailed,
      );
    }

    final String? resultUrl = job.resultUrl;
    if (resultUrl == null) {
      return _HeroFileImageSource(
        path: job.imagePath,
        key: const ValueKey<String>('generation-submission-original-image'),
        failureLogLabel: 'original image',
        failureMessage: l10n.generationSubmissionOriginalImageLoadFailed,
      );
    }

    return _HeroNetworkImageSource(
      url: resultUrl,
      key: const ValueKey<String>('generation-submission-result-image'),
      failureLogLabel: 'result image',
      failureMessage: l10n.generationSubmissionResultImageLoadFailed,
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
    final AppThemeColors colors = AppThemeColors.of(context);

    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.84,
          child: DecoratedBox(
            decoration: BoxDecoration(color: colors.background),
            child: const _GenerationSubmissionGalleryContent(),
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
      title: Text(context.l10n.generationSubmissionDownloadingFromICloud),
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
                Text(context.l10n.generationSubmissionPreparingPhoto),
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
    final AppThemeColors colors = AppThemeColors.of(context);
    return SizedBox(
      key: const ValueKey<String>('generation-gallery-export-progress-bar'),
      height: 4,
      child: SmoothClipRRect(
        borderRadius: AppCorners.controlBorderRadius,
        smoothness: AppCorners.smoothness,
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.border),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(color: colors.textPrimary),
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
    final AppThemeColors colors = AppThemeColors.of(context);
    return Positioned(
      left: 14,
      top: ((topInset - 44) / 2).clamp(6.0, 20.0),
      child: CupertinoButton(
        key: const ValueKey<String>('generation-submission-modal-close'),
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(44),
        onPressed: onClose,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.shadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SizedBox.square(
            dimension: 36,
            child: Icon(LucideIcons.x, color: colors.textPrimary, size: 18),
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
    required this.onRetryJob,
    required this.onRemoveJob,
  });

  final List<GenerationSubmissionJob> jobs;
  final GenerationSubmissionJob? selectedJob;
  final bool pickingGalleryImage;
  final VoidCallback onPickGalleryImage;
  final ValueChanged<GenerationSubmissionJob> onSelectJob;
  final ValueChanged<GenerationSubmissionJob> onConfirmJob;
  final ValueChanged<GenerationSubmissionJob> onCancelJob;
  final ValueChanged<GenerationSubmissionJob> onRetryJob;
  final ValueChanged<GenerationSubmissionJob> onRemoveJob;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final AppThemeColors colors = AppThemeColors.of(context);
    final EdgeInsets contentPadding = EdgeInsets.fromLTRB(
      0,
      12,
      0,
      10 + bottomInset,
    );

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.background),
      child: Padding(
        padding: contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                context.l10n.generationSubmissionRelatedMoments,
                key: const ValueKey<String>('generation-gallery-related-title'),
                style: TextStyle(
                  color: colors.textPrimary,
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
                  const double captionGap = 10;
                  const double captionHeight = 12;
                  final double tileHeight =
                      (itemHeight - captionGap - captionHeight).clamp(
                        0.0,
                        280.0,
                      );
                  final double tileWidth = tileHeight * 0.72;
                  const int actionTileCount = 1;
                  return ListView.separated(
                    key: const ValueKey<String>(
                      'generation-submission-photo-list',
                    ),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: jobs.length + actionTileCount,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int index) {
                      if (index == 0) {
                        return _GalleryMomentItem(
                          width: tileWidth,
                          height: itemHeight,
                          imageHeight: tileHeight,
                          caption: context.l10n.generationSubmissionImportNew,
                          child: _GalleryPickerTile(
                            width: tileWidth,
                            height: tileHeight,
                            picking: pickingGalleryImage,
                            onTap: onPickGalleryImage,
                          ),
                        );
                      }
                      final GenerationSubmissionJob job =
                          jobs[index - actionTileCount];
                      return _GalleryMomentItem(
                        width: tileWidth,
                        height: itemHeight,
                        imageHeight: tileHeight,
                        caption: _captionForJob(
                          job,
                          defaultMode: context
                              .l10n
                              .generationSubmissionDefaultMomentMode,
                        ),
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
                          onRetry: _canRetryJob(job)
                              ? () => onRetryJob(job)
                              : null,
                          onRemove: _canRetryJob(job)
                              ? () => onRemoveJob(job)
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

  String _captionForJob(
    GenerationSubmissionJob job, {
    required String defaultMode,
  }) {
    final DateTime createdAt = job.createdAt;
    final int hour = createdAt.hour == 0
        ? 12
        : createdAt.hour > 12
        ? createdAt.hour - 12
        : createdAt.hour;
    final String minute = createdAt.minute.toString().padLeft(2, '0');
    final String period = createdAt.hour >= 12 ? 'PM' : 'AM';
    final String mode =
        job.promptSelection?.captureMode.toUpperCase() ?? defaultMode;
    return '$hour:$minute $period — $mode';
  }

  bool _canRetryJob(GenerationSubmissionJob job) {
    return job.status == GenerationSubmissionStatus.failed ||
        job.status == GenerationSubmissionStatus.resultProcessingFailed;
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
    final AppThemeColors colors = AppThemeColors.of(context);
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
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 10,
              height: 1.2,
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
    final AppThemeColors colors = AppThemeColors.of(context);
    return GestureDetector(
      key: const ValueKey<String>('generation-submission-gallery-picker'),
      onTap: picking ? null : onTap,
      child: SmoothContainer(
        width: width,
        height: height,
        borderRadius: AppCorners.controlBorderRadius,
        smoothness: AppCorners.smoothness,
        side: BorderSide(color: colors.border, width: 0.5),
        padding: EdgeInsets.zero,
        color: colors.surface,
        child: Center(
          child: picking
              ? const CupertinoActivityIndicator(
                  key: ValueKey<String>(
                    'generation-submission-gallery-picker-loading',
                  ),
                )
              : Icon(LucideIcons.plus, color: colors.textPrimary, size: 24),
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
    required this.onRetry,
    required this.onRemove,
  });

  final double width;
  final double height;
  final GenerationSubmissionJob job;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    final Color accentYellow = colors.accentYellow;
    final String thumbnailImagePath =
        job.status == GenerationSubmissionStatus.resultSaved &&
            job.processedResultPath != null
        ? job.processedResultPath!
        : job.imagePath;
    return GestureDetector(
      key: ValueKey<String>('generation-submission-photo-${job.id}'),
      onTap: onTap,
      child: SmoothContainer(
        width: width,
        height: height,
        borderRadius: AppCorners.controlBorderRadius,
        smoothness: AppCorners.smoothness,
        side: BorderSide(
          color: selected ? accentYellow : colors.border,
          width: selected ? 3 : 0.5,
        ),
        padding: EdgeInsets.zero,
        child: SmoothClipRRect(
          borderRadius: AppCorners.controlBorderRadius,
          smoothness: AppCorners.smoothness,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _ThumbnailImage(
                key: ValueKey<String>('generation-thumbnail-image-${job.id}'),
                path: thumbnailImagePath,
              ),
              if (onRetry == null &&
                  job.status != GenerationSubmissionStatus.awaitingConfirmation)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: _StatusBadge(status: job.status),
                ),
              if (onRetry != null)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: _ThumbnailActionButton(
                    key: ValueKey<String>(
                      'generation-submission-retry-${job.id}',
                    ),
                    color: accentYellow,
                    icon: LucideIcons.refreshCcw,
                    iconColor: colors.inverseText,
                    onPressed: onRetry,
                  ),
                ),
              if (onRemove != null)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: _ThumbnailActionButton(
                    key: ValueKey<String>(
                      'generation-submission-remove-${job.id}',
                    ),
                    color: AppColors.danger,
                    icon: LucideIcons.x,
                    onPressed: onRemove,
                  ),
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
      ),
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({super.key, required this.path});

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
    final AppThemeColors colors = AppThemeColors.of(context);
    return ColoredBox(
      color: colors.surfaceMuted,
      child: Center(
        child: Icon(LucideIcons.image, color: colors.textSecondary, size: 24),
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
    final String label = activeCount == 0
        ? context.l10n.generationSubmissionDefaultPromptBadge
        : '+$activeCount';

    return Align(
      alignment: Alignment.topLeft,
      child: DecoratedBox(
        decoration: AppCorners.controlDecoration(
          color: AppColors.blackOverlay(0.45),
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
      decoration: AppCorners.controlDecoration(
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
        LucideIcons.circleHelp,
        key: const ValueKey<String>('generation-submission-status-awaiting'),
        color: AppColors.white,
        size: 16,
      ),
      GenerationSubmissionStatus.resultSaved => Icon(
        LucideIcons.circleCheck,
        key: const ValueKey<String>(
          'generation-submission-status-result-saved',
        ),
        color: AppColors.success,
        size: 16,
      ),
      GenerationSubmissionStatus.resultProcessingFailed => Icon(
        LucideIcons.circleAlert,
        key: const ValueKey<String>(
          'generation-submission-status-result-processing-failed',
        ),
        color: AppColors.danger,
        size: 16,
      ),
      GenerationSubmissionStatus.completed => Icon(
        LucideIcons.download,
        key: const ValueKey<String>('generation-submission-status-completed'),
        color: AppColors.white,
        size: 16,
      ),
      GenerationSubmissionStatus.failed => Icon(
        LucideIcons.circleAlert,
        key: const ValueKey<String>('generation-submission-status-failed'),
        color: AppColors.danger,
        size: 16,
      ),
      GenerationSubmissionStatus.queued ||
      GenerationSubmissionStatus.preparingUploadImage ||
      GenerationSubmissionStatus.readingFile ||
      GenerationSubmissionStatus.creatingUpload ||
      GenerationSubmissionStatus.uploading ||
      GenerationSubmissionStatus.creatingTask ||
      GenerationSubmissionStatus.submitted => Icon(
        LucideIcons.cloudUpload,
        key: const ValueKey<String>('generation-submission-status-uploading'),
        color: AppColors.white,
        size: 15,
      ),
      GenerationSubmissionStatus.uploadedWaitingTask ||
      GenerationSubmissionStatus.pollingTask ||
      GenerationSubmissionStatus
          .processingResultImage => CupertinoActivityIndicator(
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
          icon: LucideIcons.x,
          onPressed: onCancel,
        ),
        _ThumbnailActionButton(
          key: ValueKey<String>('generation-submission-confirm-$jobId'),
          color: AppColors.success,
          icon: LucideIcons.check,
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
    this.iconColor = AppColors.white,
  });

  final Color color;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: DecoratedBox(
        decoration: AppCorners.controlDecoration(
          color: color.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: SizedBox.square(
          dimension: 24,
          child: Icon(icon, color: iconColor, size: 14),
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
    required this.displayStates,
    required this.onPageChanged,
    required this.onToggleImage,
    required this.onResultArrivalAnimationCompleted,
    required this.onToggleFavorite,
    required this.onMoreActions,
  });

  final List<GenerationSubmissionJob> jobs;
  final GenerationSubmissionJob? selectedJob;
  final int selectedIndex;
  final PageController pageController;
  final Size previewSize;
  final Size viewportSize;
  final double topPadding;
  final bool loading;
  final Map<String, _GalleryHeroDisplayState> displayStates;
  final void Function(int index, List<GenerationSubmissionJob> jobs)
  onPageChanged;
  final VoidCallback? onToggleImage;
  final ValueChanged<String> onResultArrivalAnimationCompleted;
  final VoidCallback? onToggleFavorite;
  final ValueChanged<_HeroMoreAction>? onMoreActions;

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
    final AppThemeColors colors = AppThemeColors.of(context);
    if (selectedJob == null || widget.jobs.isEmpty) {
      return ColoredBox(
        color: colors.background,
        child: Padding(
          padding: EdgeInsets.only(top: widget.topPadding),
          child: Center(
            child: Text(
              context.l10n.generationSubmissionSelectMoment,
              key: const ValueKey<String>('generation-gallery-empty-hero'),
              style: TextStyle(
                color: colors.textSecondary,
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
      color: colors.background,
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
            backgroundDecoration: BoxDecoration(color: colors.background),
            loadingBuilder: (BuildContext context, ImageChunkEvent? progress) {
              return Padding(
                padding: EdgeInsets.only(top: widget.topPadding),
                child: Center(
                  child: CupertinoActivityIndicator(
                    color: colors.textSecondary,
                  ),
                ),
              );
            },
            builder: (BuildContext context, int index) {
              return _pageOptions(widget.jobs[index]);
            },
          ),
          if (widget.loading)
            Center(
              child: CupertinoActivityIndicator(
                key: const ValueKey<String>(
                  'generation-submission-result-loading',
                ),
                color: colors.textSecondary,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: _HeroToolbar(
              selectedJob: selectedJob,
              showingOriginal:
                  _displayStateForJob(selectedJob).displayedKind ==
                  _GalleryHeroImageKind.original,
              onToggleImage: _canToggleHeroImage(selectedJob)
                  ? widget.onToggleImage
                  : null,
              isFavorite: selectedJob.isResultFavorite,
              onToggleFavorite: _canToggleFavorite(selectedJob)
                  ? widget.onToggleFavorite
                  : null,
              onMoreActions: widget.onMoreActions,
            ),
          ),
        ],
      ),
    );
  }

  PhotoViewGalleryPageOptions _pageOptions(GenerationSubmissionJob job) {
    final PhotoViewController controller = _controllerForJob(job);

    final _HeroImageSource? imageSource = _imageSourceForJob(job);
    if (imageSource == null) {
      return PhotoViewGalleryPageOptions.customChild(
        child: _placeholderForJob(job),
        controller: controller,
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        disableGestures: true,
      );
    }
    final _HeroImageSource originalImageSource = _originalImageSourceForJob(
      job,
    );
    _resolveImageSize(imageSource);
    _resolveImageSize(originalImageSource);

    final bool shouldAnimateResultArrival = _shouldAnimateResultArrival(job);
    final Size imageSize = shouldAnimateResultArrival
        ? _childSizeForSource(originalImageSource)
        : _childSizeForSource(imageSource);

    Widget errorBuilder(BuildContext context, Object error, StackTrace? stack) {
      debugPrint(
        '[GenerationSubmissionModal] ${imageSource.failureLogLabel} load failure path=${imageSource.debugPath} error=$error',
      );
      return _HeroImageFailure(message: imageSource.failureMessage);
    }

    if (shouldAnimateResultArrival) {
      return generationHeroBlurredSwapPageOptions(
        originalImageProvider: originalImageSource.imageProvider,
        replacementImageProvider: imageSource.imageProvider,
        childSize: imageSize,
        controller: controller,
        basePosition: _basePositionForSource(originalImageSource),
        semanticLabel: imageSource.key.value,
        originalMarkerKey: originalImageSource.key,
        replacementMarkerKey: ValueKey<String>(
          '${imageSource.key.value}-arrival-animation-${job.id}',
        ),
        originalErrorBuilder:
            (BuildContext context, Object error, StackTrace? stack) {
              debugPrint(
                '[GenerationSubmissionModal] ${originalImageSource.failureLogLabel} load failure path=${originalImageSource.debugPath} error=$error',
              );
              return _HeroImageFailure(
                message: originalImageSource.failureMessage,
              );
            },
        replacementErrorBuilder: errorBuilder,
        onCompleted: () => widget.onResultArrivalAnimationCompleted(job.id),
      );
    }

    return generationHeroImagePageOptions(
      imageProvider: imageSource.imageProvider,
      childSize: imageSize,
      controller: controller,
      basePosition: _basePositionForSource(imageSource),
      semanticLabel: imageSource.key.value,
      markerKey: imageSource.key,
      errorBuilder: errorBuilder,
    );
  }

  Size _childSizeForSource(_HeroImageSource imageSource) {
    final Size? imageSize = _imageSizes[imageSource.debugPath];
    if (imageSize != null && imageSize.width > 0 && imageSize.height > 0) {
      return imageSize;
    }
    if (widget.previewSize.width > 0 && widget.previewSize.height > 0) {
      return widget.previewSize;
    }
    return const Size(1, 1);
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
    final _GalleryHeroDisplayState displayState = _displayStateForJob(job);
    if (displayState.displayedKind == _GalleryHeroImageKind.original &&
        displayState.phase != _GalleryHeroArrivalPhase.animating) {
      return _originalImageSourceForJob(job);
    }

    if (_shouldUseOriginalAsHero(job)) {
      return _originalImageSourceForJob(job);
    }

    if (job.status == GenerationSubmissionStatus.resultProcessingFailed) {
      return _originalImageSourceForJob(job);
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
        failureMessage:
            context.l10n.generationSubmissionProcessedResultImageLoadFailed,
      );
    }

    final String? resultUrl = job.resultUrl;
    if (resultUrl == null) {
      return _originalImageSourceForJob(job);
    }

    return _HeroNetworkImageSource(
      url: resultUrl,
      key: const ValueKey<String>('generation-submission-result-image'),
      failureLogLabel: 'result image',
      failureMessage: context.l10n.generationSubmissionResultImageLoadFailed,
    );
  }

  _HeroImageSource _originalImageSourceForJob(GenerationSubmissionJob job) {
    return _HeroFileImageSource(
      path: job.imagePath,
      key: const ValueKey<String>('generation-submission-original-image'),
      failureLogLabel: 'original image',
      failureMessage: context.l10n.generationSubmissionOriginalImageLoadFailed,
    );
  }

  bool _shouldAnimateResultArrival(GenerationSubmissionJob job) {
    return _displayStateForJob(job).phase == _GalleryHeroArrivalPhase.animating;
  }

  _GalleryHeroDisplayState _displayStateForJob(GenerationSubmissionJob job) {
    final _GalleryHeroDisplayState? state = widget.displayStates[job.id];
    if (state != null) {
      return state;
    }
    if (job.status == GenerationSubmissionStatus.resultSaved &&
        job.processedResultPath != null) {
      return const _GalleryHeroDisplayState(
        displayedKind: _GalleryHeroImageKind.result,
        phase: _GalleryHeroArrivalPhase.done,
      );
    }
    return const _GalleryHeroDisplayState(
      displayedKind: _GalleryHeroImageKind.original,
      phase: _GalleryHeroArrivalPhase.idle,
    );
  }

  Widget _placeholderForJob(GenerationSubmissionJob job) {
    final String text;
    if (job.status == GenerationSubmissionStatus.completed ||
        job.status == GenerationSubmissionStatus.resultSaved) {
      text = context.l10n.generationSubmissionTapToLoadResult;
    } else {
      text = _statusText(context.l10n, job.status).toUpperCase();
    }

    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: AppThemeColors.of(context).textSecondary,
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

  static String _statusText(
    AppLocalizations localizations,
    GenerationSubmissionStatus status,
  ) {
    return switch (status) {
      GenerationSubmissionStatus.failed =>
        localizations.generationSubmissionStatusGenerationFailed,
      GenerationSubmissionStatus.awaitingConfirmation =>
        localizations.generationSubmissionStatusWaitingForConfirmation,
      GenerationSubmissionStatus.preparingUploadImage =>
        localizations.generationSubmissionStatusPreparingUploadImage,
      GenerationSubmissionStatus.processingResultImage =>
        localizations.generationSubmissionStatusProcessingResultImage,
      GenerationSubmissionStatus.resultSaved =>
        localizations.generationSubmissionStatusResultSaved,
      GenerationSubmissionStatus.resultProcessingFailed =>
        localizations.generationSubmissionStatusResultProcessingFailed,
      GenerationSubmissionStatus.uploadedWaitingTask ||
      GenerationSubmissionStatus.submitted ||
      GenerationSubmissionStatus.pollingTask =>
        localizations.generationSubmissionStatusWaitingForGenerationResult,
      _ => localizations.generationSubmissionStatusPreparingGenerationTask,
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

class _HeroImageFailure extends StatelessWidget {
  const _HeroImageFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return ColoredBox(
      color: colors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            key: const ValueKey<String>('generation-gallery-hero-failure'),
            style: TextStyle(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

enum _HeroMoreAction { viewInAlbum, saveOriginal, retry, dislike, remove }

class _HeroMoreActionItem {
  const _HeroMoreActionItem({
    required this.action,
    required this.title,
    required this.icon,
    required this.enabled,
    this.destructive = false,
  });

  final _HeroMoreAction action;
  final String title;
  final IconData icon;
  final bool enabled;
  final bool destructive;
}

class _HeroToolbar extends StatefulWidget {
  const _HeroToolbar({
    required this.selectedJob,
    required this.showingOriginal,
    required this.onToggleImage,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onMoreActions,
  });

  final GenerationSubmissionJob selectedJob;
  final bool showingOriginal;
  final VoidCallback? onToggleImage;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final ValueChanged<_HeroMoreAction>? onMoreActions;

  @override
  State<_HeroToolbar> createState() => _HeroToolbarState();
}

class _HeroToolbarState extends State<_HeroToolbar>
    with SingleTickerProviderStateMixin {
  static const Duration _expandDuration = Duration(milliseconds: 500);
  static const Duration _collapseDuration = Duration(milliseconds: 220);
  static const double _collapsedWidth = 116;
  static const double _collapsedHeight = 44;
  static const double _expandedWidth = 220;
  static const double _expandedHeight = 232;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _expandDuration,
    reverseDuration: _collapseDuration,
  );
  late final Animation<double> _expandCurve = CurvedAnimation(
    parent: _controller,
    curve: const ElasticOutCurve(1.2),
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<double> _toolsOpacity = Tween<double>(begin: 1, end: 0)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.34, curve: Curves.easeOut),
          reverseCurve: const Interval(0.48, 1, curve: Curves.easeIn),
        ),
      );
  late final Animation<double> _menuOpacity = Tween<double>(begin: 0, end: 1)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.42, 1, curve: Curves.easeOut),
          reverseCurve: const Interval(0.72, 1, curve: Curves.easeOutCubic),
        ),
      );
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _HeroToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onMoreActions != widget.onMoreActions && _expanded) {
      _setExpanded(false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setExpanded(bool expanded) {
    if (_expanded == expanded) {
      return;
    }
    setState(() {
      _expanded = expanded;
    });
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.value = expanded ? 1 : 0;
      return;
    }
    if (expanded) {
      unawaited(_controller.forward());
    } else {
      unawaited(_controller.reverse());
    }
  }

  Future<void> _selectAction(_HeroMoreActionItem item) async {
    debugPrint(
      '[GenerationSubmissionModal] hero toolbar action selected action=${item.action.name} enabled=${item.enabled}',
    );
    if (!item.enabled) {
      _setExpanded(false);
      return;
    }
    _setExpanded(false);
    await Future<void>.delayed(_collapseDuration);
    if (!mounted) {
      return;
    }
    widget.onMoreActions?.call(item.action);
  }

  void _handleExpandedMenuTap(Offset localPosition) {
    if (!_expanded) {
      return;
    }
    const double topPadding = 10;
    const double itemHeight = 42;
    final int index = ((localPosition.dy - topPadding) / itemHeight).floor();
    final List<_HeroMoreActionItem> items = _items;
    if (index < 0 || index >= items.length) {
      return;
    }
    unawaited(_selectAction(items[index]));
  }

  List<_HeroMoreActionItem> get _items {
    final AppLocalizations l10n = context.l10n;
    return <_HeroMoreActionItem>[
      _HeroMoreActionItem(
        action: _HeroMoreAction.viewInAlbum,
        title: l10n.generationSubmissionActionViewInAlbum,
        icon: LucideIcons.images,
        enabled: _canViewInAlbum,
      ),
      _HeroMoreActionItem(
        action: _HeroMoreAction.saveOriginal,
        title: l10n.generationSubmissionActionSaveOriginal,
        icon: LucideIcons.download,
        enabled: widget.selectedJob.canSaveOriginalToPhotoLibrary,
      ),
      _HeroMoreActionItem(
        action: _HeroMoreAction.retry,
        title: l10n.generationSubmissionActionRetry,
        icon: LucideIcons.refreshCcw,
        enabled: _canRetry,
      ),
      _HeroMoreActionItem(
        action: _HeroMoreAction.dislike,
        title: l10n.generationSubmissionActionDislikeImage,
        icon: LucideIcons.thumbsDown,
        enabled: _canDislike,
      ),
      _HeroMoreActionItem(
        action: _HeroMoreAction.remove,
        title: l10n.generationSubmissionActionRemove,
        icon: LucideIcons.trash2,
        enabled: true,
        destructive: true,
      ),
    ];
  }

  bool get _canViewInAlbum {
    return (widget.selectedJob.resultAssetId != null &&
            widget.selectedJob.resultAssetId!.isNotEmpty) ||
        widget.selectedJob.imagePath.isNotEmpty;
  }

  bool get _canRetry {
    return widget.selectedJob.status == GenerationSubmissionStatus.failed ||
        widget.selectedJob.status ==
            GenerationSubmissionStatus.resultProcessingFailed;
  }

  bool get _canDislike {
    return widget.selectedJob.taskId != null &&
        widget.selectedJob.taskId!.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _expandCurve,
      builder: (BuildContext context, Widget? child) {
        final double height = lerpDouble(
          _collapsedHeight,
          _expandedHeight,
          _expandCurve.value,
        )!;
        return SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              if (_expanded)
                Positioned.fill(
                  child: GestureDetector(
                    key: const ValueKey<String>(
                      'generation-submission-more-dismiss-layer',
                    ),
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (_) => _setExpanded(false),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedBuilder(
                  animation: _expandCurve,
                  builder: (BuildContext context, Widget? child) {
                    final double value = _expandCurve.value;
                    final double width = lerpDouble(
                      _collapsedWidth,
                      _expandedWidth,
                      value,
                    )!;
                    final double height = lerpDouble(
                      _collapsedHeight,
                      _expandedHeight,
                      value,
                    )!;
                    final double radius = lerpDouble(
                      _collapsedHeight / 2,
                      28,
                      value,
                    )!;
                    final SmoothRectangleBorder toolbarShape =
                        SmoothRectangleBorder(
                          borderRadius: BorderRadius.circular(radius),
                          smoothness: 0.8,
                          side: BorderSide(
                            color: AppColors.white.withValues(alpha: 0.18),
                            width: 0.5,
                          ),
                        );
                    return GestureDetector(
                      key: const ValueKey<String>(
                        'generation-submission-more-hit-region',
                      ),
                      behavior: HitTestBehavior.translucent,
                      onTapUp: _expanded
                          ? (TapUpDetails details) {
                              _handleExpandedMenuTap(details.localPosition);
                            }
                          : null,
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: ClipPath(
                          clipper: ShapeBorderClipper(shape: toolbarShape),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                color: AppColors.blackOverlay(0.42),
                                shape: toolbarShape,
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  IgnorePointer(
                                    ignoring: _expanded,
                                    child: FadeTransition(
                                      opacity: _toolsOpacity,
                                      child: ScaleTransition(
                                        scale: Tween<double>(
                                          begin: 1,
                                          end: 0.94,
                                        ).animate(_expandCurve),
                                        child: _CollapsedHeroTools(
                                          showingOriginal:
                                              widget.showingOriginal,
                                          onToggleImage: widget.onToggleImage,
                                          isFavorite: widget.isFavorite,
                                          onToggleFavorite:
                                              widget.onToggleFavorite,
                                          onMorePressed:
                                              widget.onMoreActions == null
                                              ? null
                                              : () => _setExpanded(true),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IgnorePointer(
                                    ignoring: !_expanded,
                                    child: FadeTransition(
                                      opacity: _menuOpacity,
                                      child: _ExpandedHeroMenu(
                                        animation: _controller,
                                        items: _items,
                                        onSelected: (_HeroMoreActionItem item) {
                                          unawaited(_selectAction(item));
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CollapsedHeroTools extends StatelessWidget {
  const _CollapsedHeroTools({
    required this.showingOriginal,
    required this.onToggleImage,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onMorePressed,
  });

  final bool showingOriginal;
  final VoidCallback? onToggleImage;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onMorePressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ImageToggleButton(
            showingOriginal: showingOriginal,
            onPressed: onToggleImage,
          ),
          _FavoriteButton(isFavorite: isFavorite, onPressed: onToggleFavorite),
          _HeroToolbarButton(
            key: const ValueKey<String>('generation-submission-more-actions'),
            icon: LucideIcons.moreHorizontal,
            onPressed: onMorePressed,
          ),
        ],
      ),
    );
  }
}

class _ExpandedHeroMenu extends StatelessWidget {
  const _ExpandedHeroMenu({
    required this.animation,
    required this.items,
    required this.onSelected,
  });

  final Animation<double> animation;
  final List<_HeroMoreActionItem> items;
  final ValueChanged<_HeroMoreActionItem> onSelected;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 230,
        maxHeight: 230,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int index = 0; index < items.length; index += 1)
                _ExpandedHeroMenuItem(
                  item: items[index],
                  animation: _itemAnimation(index),
                  onPressed: () => onSelected(items[index]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Animation<double> _itemAnimation(int index) {
    final double start = (0.42 + index * 0.055).clamp(0.0, 0.86);
    final double end = (start + 0.34).clamp(start, 1.0);
    return CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.74, 1, curve: Curves.easeOutCubic),
    );
  }
}

class _ExpandedHeroMenuItem extends StatelessWidget {
  const _ExpandedHeroMenuItem({
    required this.item,
    required this.animation,
    required this.onPressed,
  });

  final _HeroMoreActionItem item;
  final Animation<double> animation;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color color = item.enabled
        ? item.destructive
              ? AppColors.danger
              : AppColors.white
        : AppColors.white.withValues(alpha: 0.38);
    return GestureDetector(
      key: ValueKey<String>('generation-submission-more-${item.action.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        height: 42,
        child: AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? child) {
            return Opacity(
              opacity: animation.value,
              child: Transform.translate(
                offset: Offset(0, (1 - animation.value) * 10),
                child: child,
              ),
            );
          },
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 34,
                child: Icon(item.icon, color: color, size: 18),
              ),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
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
    final Color accentYellow = AppThemeColors.of(context).accentYellow;

    return _HeroToolbarButton(
      key: const ValueKey<String>('generation-submission-favorite-toggle'),
      icon: LucideIcons.heart,
      onPressed: onPressed,
      color: isFavorite ? accentYellow : AppColors.white,
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
