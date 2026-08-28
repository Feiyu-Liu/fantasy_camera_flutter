import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_ui/my_ui.dart' show GridSquareAnimation;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:progressive_blur/progressive_blur.dart';
import 'package:smooth_corner/smooth_corner.dart';

import '../../../app/app_router.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/core/app_logger.dart';
import '../../../shared/presentation/widgets/app_blur_navigation_bar.dart';
import '../../../shared/toast/app_toast.dart';
import '../../../theme/app_corners.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../backend_api/domain/prompt_config.dart';
import '../../camera/presentation/camera_ui/camera_photo_option_button.dart';
import '../../camera/presentation/camera_ui/camera_ui_models.dart';
import '../../camera/presentation/camera_ui/camera_ui_tokens.dart';
import '../data/generation_submission_adapters.dart';
import '../domain/generation_record.dart';
import '../domain/generation_record_state_machine.dart';
import '../domain/generation_submission_job.dart';
import 'generation_hero_photo_view_page_options.dart';
import 'generation_image_mosaic_repository.dart';
import 'generation_progress_estimate.dart';
import 'generation_status_pill.dart';
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
          showNavigationBar: true,
        ),
      ),
    );
  }
}

class _GenerationSubmissionGalleryContent extends ConsumerStatefulWidget {
  const _GenerationSubmissionGalleryContent({
    this.focusedTaskId,
    this.showNavigationBar = false,
  });

  final String? focusedTaskId;
  final bool showNavigationBar;

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
  bool _confirmationGuideDismissed = false;
  bool _showConfirmationGuide = false;
  final Map<String, _GalleryHeroDisplayState> _heroDisplayStates =
      <String, _GalleryHeroDisplayState>{};
  final Set<String> _knownLocalSavedResultJobIds = <String>{};
  bool _hasProcessedInitialJobs = false;
  bool _markResultNotificationsSeenScheduled = false;
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
    if (widget.focusedTaskId != null && widget.focusedTaskId!.isNotEmpty) {
      unawaited(_refreshFocusedTaskFromNotification(widget.focusedTaskId!));
    }
    if (ref.read(galleryResumeActiveRecordsOnOpenProvider)) {
      unawaited(_resumeActiveRecordsForGallery());
    }
    _jobs = ref.read(generationSubmissionControllerProvider).jobs;
    _knownLocalSavedResultJobIds.addAll(_localSavedResultJobIds(_jobs));
    _hasProcessedInitialJobs = _jobs.isNotEmpty;
    _selectFocusedTaskIfPresent(_jobs, animate: false);
    _scheduleMarkResultNotificationsSeen();
    unawaited(_loadConfirmationGuideState());
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
        _scheduleMarkResultNotificationsSeen();
      },
    );
  }

  Future<void> _refreshFocusedTaskFromNotification(String taskId) async {
    try {
      await ref
          .read(generationSubmissionControllerProvider.notifier)
          .refreshTaskFromNotification(taskId);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'generation submission gallery',
          context: ErrorDescription(
            'while refreshing focused notification task',
          ),
        ),
      );
    }
  }

  void _scheduleMarkResultNotificationsSeen() {
    if (_markResultNotificationsSeenScheduled) {
      return;
    }
    _markResultNotificationsSeenScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markResultNotificationsSeenScheduled = false;
      if (!mounted) {
        return;
      }
      ref
          .read(generationResultNotificationControllerProvider.notifier)
          .markAllSeen();
    });
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
        final double navigationHeight = widget.showNavigationBar
            ? topInset + AppBlurNavigationBar.contentHeight
            : 0;
        final double height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final double contentHeight = (height - navigationHeight).clamp(
          0.0,
          height,
        );
        final double layoutHeight = widget.showNavigationBar
            ? contentHeight
            : height;
        const double heroStripGap = 12;
        final double maxHeroHeight = (layoutHeight - 196 - heroStripGap).clamp(
          0.0,
          layoutHeight,
        );
        final double heroWidth = constraints.maxWidth.clamp(
          0.0,
          maxHeroHeight * 3 / 4,
        );
        final double heroHeight = heroWidth * 4 / 3;
        final double heroTopPadding = widget.showNavigationBar ? 0 : topInset;
        final double actualHeroViewportHeight = (heroHeight + heroTopPadding)
            .clamp(0.0, layoutHeight);
        final Widget hero = SizedBox(
          width: heroWidth,
          height: actualHeroViewportHeight,
          child: _GalleryHeroPager(
            jobs: jobs,
            selectedJob: selectedJob,
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            pageController: _heroPageController,
            previewSize: Size(heroWidth, heroHeight),
            viewportSize: Size(heroWidth, actualHeroViewportHeight),
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
            onUpdatePromptSelection: selectedJob == null
                ? null
                : (PromptSelectionSnapshot promptSelection) => unawaited(
                    _updatePendingPromptSelection(selectedJob, promptSelection),
                  ),
            onMoreActions: selectedJob == null
                ? null
                : (_HeroMoreAction action) =>
                      unawaited(_performMoreAction(action, selectedJob)),
          ),
        );
        final Widget galleryContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: actualHeroViewportHeight,
              child: Center(child: hero),
            ),
            const SizedBox(height: heroStripGap),
            Expanded(
              child: _RelatedMomentsStrip(
                jobs: jobs,
                selectedJob: selectedJob,
                pickingGalleryImage: _pickingGalleryImage,
                onPickGalleryImage: _pickGalleryImage,
                onSelectJob: _selectJobFromStrip,
                onConfirmJob: (GenerationSubmissionJob job) {
                  unawaited(_dismissConfirmationGuide());
                  unawaited(_confirmJob(job));
                },
                showConfirmationGuide:
                    !_confirmationGuideDismissed && _showConfirmationGuide,
                onDismissConfirmationGuide: _dismissConfirmationGuide,
                onCancelJob: (GenerationSubmissionJob job) {
                  unawaited(_dismissConfirmationGuide());
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
        );
        if (!widget.showNavigationBar) {
          return Stack(
            children: <Widget>[
              _TopGradientBlur(blurHeight: topInset, child: galleryContent),
              if (_galleryExportProgressDialogVisible)
                _GalleryExportProgressOverlay(
                  progressListenable: _galleryExportProgress,
                ),
            ],
          );
        }
        return Stack(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(top: navigationHeight),
              child: SizedBox(height: contentHeight, child: galleryContent),
            ),
            if (widget.showNavigationBar)
              AppBlurNavigationBar(
                topInset: topInset,
                title: context.l10n.generationSubmissionGalleryTitle,
                backButtonKey: const ValueKey<String>(
                  'generation-gallery-back-button',
                ),
                onBackPressed: _closeGallery,
              ),
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

  Future<void> _dismissConfirmationGuide() async {
    if (_confirmationGuideDismissed) {
      return;
    }
    setState(() {
      _confirmationGuideDismissed = true;
      _showConfirmationGuide = false;
    });
    try {
      await ref
          .read(generationSubmissionGuideRepositoryProvider)
          .markConfirmationGuideSeen();
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'generation submission gallery',
          context: ErrorDescription(
            'while dismissing confirmation guide tooltip',
          ),
        ),
      );
    }
  }

  Future<void> _loadConfirmationGuideState() async {
    try {
      final bool seen = await ref
          .read(generationSubmissionGuideRepositoryProvider)
          .isConfirmationGuideSeen();
      if (!mounted || seen) {
        return;
      }
      setState(() {
        _showConfirmationGuide = true;
      });
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'generation submission gallery',
          context: ErrorDescription('while loading confirmation guide state'),
        ),
      );
    }
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
        job.hasProcessedResultPath;
  }

  bool _hasMissingSavedResult(GenerationSubmissionJob job) {
    return job.hasMissingSavedResult;
  }

  bool _hasDisplayableResult(GenerationSubmissionJob job) {
    return job.hasResultDisplayTarget;
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
    if (job.status == GenerationSubmissionStatus.resultProcessingFailed) {
      unawaited(_loadResult(job.id));
    }
  }

  Future<void> _confirmJob(GenerationSubmissionJob job) async {
    _debugLog('confirm job=${job.id}');
    final bool canGenerate = await _ensureCreditsBeforeGeneration();
    if (!canGenerate) {
      return;
    }
    setState(() {
      _selectedJobId = job.id;
      _heroDisplayStates[job.id] = const _GalleryHeroDisplayState(
        displayedKind: _GalleryHeroImageKind.original,
        phase: _GalleryHeroArrivalPhase.idle,
      );
    });
    try {
      await ref
          .read(generationSubmissionControllerProvider.notifier)
          .confirmJob(job.id);
      _showToastForFailedUserSubmission(job.id);
    } on Object catch (error) {
      _debugLog('confirm job failure job=${job.id} error=$error');
      if (!mounted) {
        return;
      }
      ref
          .read(appToastServiceProvider)
          .showGenerationSubmitFailure(localizations: context.l10n);
    }
  }

  Future<void> _updatePendingPromptSelection(
    GenerationSubmissionJob job,
    PromptSelectionSnapshot promptSelection,
  ) async {
    if (job.status != GenerationSubmissionStatus.awaitingConfirmation) {
      return;
    }
    _debugLog(
      'update prompt selection job=${job.id} prompt=${promptSelection.promptStyle}/${promptSelection.captureMode} switches=${promptSelection.switches}',
    );
    try {
      await ref
          .read(generationSubmissionControllerProvider.notifier)
          .updatePendingPromptSelection(job.id, promptSelection);
    } on Object catch (error) {
      _debugLog('update prompt selection failure job=${job.id} error=$error');
    }
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
    final bool canGenerate = await _ensureCreditsBeforeGeneration();
    if (!canGenerate) {
      return;
    }
    setState(() {
      _selectedJobId = job.id;
      _heroDisplayStates[job.id] = const _GalleryHeroDisplayState(
        displayedKind: _GalleryHeroImageKind.original,
        phase: _GalleryHeroArrivalPhase.idle,
      );
    });
    try {
      await ref
          .read(generationSubmissionControllerProvider.notifier)
          .retryJob(job.id);
      _showToastForFailedUserSubmission(job.id);
    } on Object catch (error) {
      _debugLog('retry job failure job=${job.id} error=$error');
      _showToastForFailedUserSubmission(job.id, fallbackErrorCode: null);
    }
  }

  Future<bool> _ensureCreditsBeforeGeneration() async {
    final bool canGenerate = await ref
        .read(generationSubmissionControllerProvider.notifier)
        .hasSufficientCreditsForGeneration();
    if (canGenerate) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    _openPaywallForInsufficientCredits();
    return false;
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
    try {
      await ref
          .read(generationSubmissionControllerProvider.notifier)
          .toggleResultFavorite(job.id);
    } on Object catch (error) {
      _debugLog('toggle favorite failure job=${job.id} error=$error');
      if (!mounted) {
        return;
      }
      ref.read(appToastServiceProvider).showFavoriteFailure(context.l10n);
    }
  }

  Future<void> _performMoreAction(
    _HeroMoreAction action,
    GenerationSubmissionJob job,
  ) async {
    final GenerationSubmissionController controller = ref.read(
      generationSubmissionControllerProvider.notifier,
    );
    switch (action) {
      case _HeroMoreAction.viewInAlbum:
        _debugLog('more action view in album job=${job.id}');
        try {
          await controller.openPhotoLibrary(job.id);
        } on Object catch (error) {
          _debugLog('open photo library failure job=${job.id} error=$error');
          if (!mounted) {
            return;
          }
          ref
              .read(appToastServiceProvider)
              .showOpenPhotoLibraryFailure(context.l10n);
        }
      case _HeroMoreAction.saveOriginal:
        _debugLog('more action save original job=${job.id}');
        try {
          await controller.saveOriginalToPhotoLibrary(job.id);
          if (!mounted) {
            return;
          }
          ref
              .read(appToastServiceProvider)
              .showSaveOriginalSuccess(context.l10n);
        } on Object catch (error) {
          _debugLog('save original failure job=${job.id} error=$error');
          if (!mounted) {
            return;
          }
          ref
              .read(appToastServiceProvider)
              .showSaveOriginalFailure(context.l10n);
        }
      case _HeroMoreAction.retry:
        _debugLog('more action retry job=${job.id}');
        await _retryJob(job);
      case _HeroMoreAction.dislike:
        _debugLog('more action dislike job=${job.id}');
        await _submitNegativeFeedbackWithReason(job);
      case _HeroMoreAction.remove:
        _debugLog('more action remove job=${job.id}');
        await _removeJob(job);
    }
  }

  Future<void> _submitNegativeFeedbackWithReason(
    GenerationSubmissionJob job,
  ) async {
    final String? note = await showCupertinoDialog<String?>(
      context: context,
      builder: (BuildContext context) {
        return const _DislikeFeedbackDialog();
      },
    );
    if (!mounted || note == null) {
      return;
    }
    try {
      await ref
          .read(generationSubmissionControllerProvider.notifier)
          .submitNegativeFeedback(job.id, note: note);
      if (!mounted) {
        return;
      }
      ref.read(appToastServiceProvider).showFeedbackSuccess(context.l10n);
    } on Object catch (error) {
      _debugLog('submit negative feedback failure job=${job.id} error=$error');
      if (!mounted) {
        return;
      }
      ref.read(appToastServiceProvider).showFeedbackFailure(context.l10n);
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
      if (!mounted) {
        return;
      }
      ref
          .read(appToastServiceProvider)
          .showGalleryImportFailure(context.l10n, error);
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

  void _showToastForFailedUserSubmission(
    String jobId, {
    String? fallbackErrorCode,
  }) {
    final GenerationSubmissionJob? updatedJob = _findJobById(
      ref.read(generationSubmissionControllerProvider).jobs,
      jobId,
    );
    if (updatedJob == null) {
      if (_isInsufficientCreditsErrorCode(fallbackErrorCode)) {
        _openPaywallForInsufficientCredits();
        return;
      }
      ref
          .read(appToastServiceProvider)
          .showGenerationSubmitFailure(
            localizations: context.l10n,
            errorCode: fallbackErrorCode,
          );
      return;
    }
    final String? errorCode = updatedJob.errorCode ?? fallbackErrorCode;
    if (updatedJob.status == GenerationSubmissionStatus.awaitingConfirmation &&
        _isInsufficientCreditsErrorCode(errorCode)) {
      _openPaywallForInsufficientCredits();
      return;
    }
    switch (updatedJob.status) {
      case GenerationSubmissionStatus.failed:
        ref
            .read(appToastServiceProvider)
            .showGenerationSubmitFailure(
              localizations: context.l10n,
              errorCode: errorCode,
              failureStage: updatedJob.failureStage,
            );
      case GenerationSubmissionStatus.resultProcessingFailed:
        ref.read(appToastServiceProvider).showResultSaveFailure(context.l10n);
      case GenerationSubmissionStatus.awaitingConfirmation:
      case GenerationSubmissionStatus.queued:
      case GenerationSubmissionStatus.preparingUploadImage:
      case GenerationSubmissionStatus.readingFile:
      case GenerationSubmissionStatus.creatingUpload:
      case GenerationSubmissionStatus.uploading:
      case GenerationSubmissionStatus.uploadedWaitingTask:
      case GenerationSubmissionStatus.creatingTask:
      case GenerationSubmissionStatus.submitted:
      case GenerationSubmissionStatus.pollingTask:
      case GenerationSubmissionStatus.completed:
      case GenerationSubmissionStatus.processingResultImage:
      case GenerationSubmissionStatus.resultSaved:
        break;
    }
  }

  void _openPaywallForInsufficientCredits() {
    if (!mounted) {
      return;
    }
    ref
        .read(appToastServiceProvider)
        .showGenerationSubmitFailure(
          localizations: context.l10n,
          errorCode: 'insufficient_credits',
        );
    unawaited(context.push(creditPurchaseRoute));
  }

  bool _isInsufficientCreditsErrorCode(String? errorCode) {
    return errorCode == 'insufficient_credits' ||
        errorCode == 'insufficient_credit' ||
        errorCode == 'credits_insufficient' ||
        errorCode == 'not_enough_credits';
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
    appDebugLog('GenerationSubmissionModal', message);
  }

  _HeroImageSource? _heroImageSourceForJob(GenerationSubmissionJob job) {
    final AppLocalizations l10n = context.l10n;
    final _GalleryHeroDisplayState displayState = _heroDisplayStateForJob(job);
    if (displayState.displayedKind == _GalleryHeroImageKind.original ||
        displayState.phase == _GalleryHeroArrivalPhase.precaching ||
        displayState.phase == _GalleryHeroArrivalPhase.animating ||
        job.status == GenerationSubmissionStatus.resultProcessingFailed ||
        job.status != GenerationSubmissionStatus.resultSaved) {
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

    if (_hasMissingSavedResult(job)) {
      return _HeroUnavailableImageSource(
        key: const ValueKey<String>(
          'generation-submission-processed-result-image-missing',
        ),
        failureLogLabel: 'processed result image',
        failureMessage: l10n.generationSubmissionProcessedResultImageLoadFailed,
      );
    }

    return _HeroFileImageSource(
      path: job.imagePath,
      key: const ValueKey<String>('generation-submission-original-image'),
      failureLogLabel: 'original image',
      failureMessage: l10n.generationSubmissionOriginalImageLoadFailed,
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

class _DislikeFeedbackDialog extends StatefulWidget {
  const _DislikeFeedbackDialog();

  @override
  State<_DislikeFeedbackDialog> createState() => _DislikeFeedbackDialogState();
}

class _DislikeFeedbackDialogState extends State<_DislikeFeedbackDialog> {
  static const int _maxNoteLength = 2000;

  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop<String>(_noteController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    final AppLocalizations l10n = context.l10n;
    return CupertinoAlertDialog(
      title: Text(l10n.generationSubmissionDislikeFeedbackTitle),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CupertinoTextField(
              key: const ValueKey<String>('generation-submission-dislike-note'),
              controller: _noteController,
              maxLength: _maxNoteLength,
              maxLines: 4,
              minLines: 3,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              placeholder: l10n.generationSubmissionDislikeFeedbackPlaceholder,
              textInputAction: TextInputAction.newline,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              placeholderStyle: TextStyle(
                color: colors.textMuted,
                fontSize: 14,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop<String?>(null),
          child: Text(l10n.commonCancel),
        ),
        CupertinoDialogAction(
          onPressed: _submit,
          isDefaultAction: true,
          child: Text(l10n.generationSubmissionDislikeFeedbackSubmit),
        ),
      ],
    );
  }
}

class _RelatedMomentsStrip extends StatefulWidget {
  const _RelatedMomentsStrip({
    required this.jobs,
    required this.selectedJob,
    required this.pickingGalleryImage,
    required this.onPickGalleryImage,
    required this.onSelectJob,
    required this.onConfirmJob,
    required this.showConfirmationGuide,
    required this.onDismissConfirmationGuide,
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
  final bool showConfirmationGuide;
  final VoidCallback onDismissConfirmationGuide;
  final ValueChanged<GenerationSubmissionJob> onCancelJob;
  final ValueChanged<GenerationSubmissionJob> onRetryJob;
  final ValueChanged<GenerationSubmissionJob> onRemoveJob;

  @override
  State<_RelatedMomentsStrip> createState() => _RelatedMomentsStripState();
}

class _RelatedMomentsStripState extends State<_RelatedMomentsStrip> {
  static const Duration _insertDuration = Duration(milliseconds: 260);
  static const Duration _removeDuration = Duration(milliseconds: 220);
  static const double _horizontalPadding = 24;
  static const double _itemGap = 8;
  static const double _thumbnailAspectRatio = 3 / 4;

  late GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late final ScrollController _scrollController = ScrollController()
    ..addListener(_syncAnimationActivity);
  late final JustTheController _confirmationGuideTooltipController =
      JustTheController();
  late List<GenerationSubmissionJob> _displayJobs =
      List<GenerationSubmissionJob>.of(widget.jobs);
  final Set<String> _insertingJobIds = <String>{};
  bool _hasSyncedInitialJobs = false;
  bool _confirmationGuideSyncScheduled = false;
  bool _animationActivitySyncScheduled = false;
  double? _itemExtent;
  Set<String> _animationActiveJobIds = <String>{};
  String? _pendingConfirmationGuideJobId;
  String? _confirmationGuideAnchorJobId;

  @override
  void initState() {
    super.initState();
    _syncConfirmationGuideAnchor();
  }

  @override
  void didUpdateWidget(covariant _RelatedMomentsStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDisplayJobs(widget.jobs);
    _syncConfirmationGuideAnchor();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_syncAnimationActivity)
      ..dispose();
    _confirmationGuideTooltipController.dispose();
    super.dispose();
  }

  void _syncDisplayJobs(List<GenerationSubmissionJob> nextJobs) {
    if (!_hasSyncedInitialJobs && _displayJobs.isEmpty && nextJobs.isNotEmpty) {
      _hasSyncedInitialJobs = true;
      _resetAnimatedList(nextJobs);
      return;
    }
    _hasSyncedInitialJobs = true;
    if (_sameJobOrder(_displayJobs, nextJobs)) {
      _displayJobs = List<GenerationSubmissionJob>.of(nextJobs);
      return;
    }

    final AnimatedListState? listState = _listKey.currentState;
    final Set<String> previousIds = _displayJobs
        .map((GenerationSubmissionJob job) => job.id)
        .toSet();
    final Set<String> nextIds = nextJobs
        .map((GenerationSubmissionJob job) => job.id)
        .toSet();
    if (listState == null || _commonJobOrderChanged(previousIds, nextJobs)) {
      _resetAnimatedList(nextJobs);
      return;
    }

    for (int index = _displayJobs.length - 1; index >= 0; index -= 1) {
      final GenerationSubmissionJob job = _displayJobs[index];
      if (nextIds.contains(job.id)) {
        continue;
      }
      final GenerationSubmissionJob removedJob = _displayJobs.removeAt(index);
      listState.removeItem(index + 1, (
        BuildContext context,
        Animation<double> animation,
      ) {
        return _AnimatedGalleryJobListItem(
          key: ValueKey<String>(
            'generation-submission-removed-photo-${removedJob.id}',
          ),
          job: removedJob,
          selected: false,
          animationActive: false,
          animation: animation,
          removing: true,
          onTap: () {},
          onConfirm: null,
          onCancel: null,
          onRetry: null,
          onRemove: null,
          hasConfirmationGuideAnchor: false,
          confirmationGuideTooltipController:
              _confirmationGuideTooltipController,
          onDismissConfirmationGuide: widget.onDismissConfirmationGuide,
        );
      }, duration: _motionDuration(_removeDuration));
    }

    int displayIndex = 0;
    for (final GenerationSubmissionJob nextJob in nextJobs) {
      if (displayIndex < _displayJobs.length &&
          _displayJobs[displayIndex].id == nextJob.id) {
        _displayJobs[displayIndex] = nextJob;
        displayIndex += 1;
        continue;
      }

      if (previousIds.contains(nextJob.id)) {
        _resetAnimatedList(nextJobs);
        return;
      }

      _insertingJobIds.add(nextJob.id);
      _displayJobs.insert(displayIndex, nextJob);
      listState.insertItem(
        displayIndex + 1,
        duration: _motionDuration(_insertDuration),
      );
      displayIndex += 1;
    }

    _displayJobs = List<GenerationSubmissionJob>.of(_displayJobs);
    _scheduleAnimationActivitySync();
  }

  void _resetAnimatedList(List<GenerationSubmissionJob> nextJobs) {
    _insertingJobIds.clear();
    _listKey = GlobalKey<AnimatedListState>();
    _displayJobs = List<GenerationSubmissionJob>.of(nextJobs);
    _scheduleAnimationActivitySync();
  }

  void _scheduleAnimationActivitySync() {
    if (_animationActivitySyncScheduled) {
      return;
    }
    _animationActivitySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationActivitySyncScheduled = false;
      if (mounted) {
        _syncAnimationActivity();
      }
    });
  }

  void _syncAnimationActivity() {
    final double? itemExtent = _itemExtent;
    if (!mounted ||
        itemExtent == null ||
        itemExtent <= 0 ||
        !_scrollController.hasClients) {
      return;
    }
    final ScrollPosition position = _scrollController.position;
    final double visibleLeft = math.max(
      0,
      position.pixels - _horizontalPadding,
    );
    final double visibleRight = math.max(
      visibleLeft,
      position.pixels + position.viewportDimension - _horizontalPadding,
    );
    final int firstListIndex = math.max(
      0,
      (visibleLeft / itemExtent).floor() - 1,
    );
    final int lastListIndex = math.min(
      _displayJobs.length,
      (visibleRight / itemExtent).ceil() + 1,
    );
    final Set<String> nextActiveJobIds = <String>{
      for (
        int listIndex = firstListIndex;
        listIndex <= lastListIndex;
        listIndex += 1
      )
        if (listIndex > 0 && listIndex - 1 < _displayJobs.length)
          _displayJobs[listIndex - 1].id,
    };
    if (setEquals(_animationActiveJobIds, nextActiveJobIds)) {
      return;
    }
    setState(() => _animationActiveJobIds = nextActiveJobIds);
  }

  bool _sameJobOrder(
    List<GenerationSubmissionJob> previousJobs,
    List<GenerationSubmissionJob> nextJobs,
  ) {
    if (previousJobs.length != nextJobs.length) {
      return false;
    }
    for (int index = 0; index < previousJobs.length; index += 1) {
      if (previousJobs[index].id != nextJobs[index].id) {
        return false;
      }
    }
    return true;
  }

  bool _commonJobOrderChanged(
    Set<String> previousIds,
    List<GenerationSubmissionJob> nextJobs,
  ) {
    final Set<String> nextIds = nextJobs
        .map((GenerationSubmissionJob job) => job.id)
        .toSet();
    final List<String> previousCommonIds = _displayJobs
        .where((GenerationSubmissionJob job) => nextIds.contains(job.id))
        .map((GenerationSubmissionJob job) => job.id)
        .toList(growable: false);
    final List<String> nextCommonIds = nextJobs
        .where((GenerationSubmissionJob job) => previousIds.contains(job.id))
        .map((GenerationSubmissionJob job) => job.id)
        .toList(growable: false);
    return !listEquals(previousCommonIds, nextCommonIds);
  }

  Duration _motionDuration(Duration duration) {
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return reduceMotion ? Duration.zero : duration;
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final AppThemeColors colors = AppThemeColors.of(context);
    final EdgeInsets contentPadding = EdgeInsets.fromLTRB(
      0,
      12,
      0,
      14 + bottomInset,
    );

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.background),
      child: Padding(
        padding: contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double itemHeight = constraints.maxHeight;
                  const double captionGap = 6;
                  const double captionHeight = 12;
                  final double tileHeight =
                      (itemHeight - captionGap - captionHeight).clamp(
                        0.0,
                        280.0,
                      );
                  final double tileWidth = tileHeight * _thumbnailAspectRatio;
                  final double itemExtent = tileWidth + _itemGap;
                  if (_itemExtent != itemExtent) {
                    _itemExtent = itemExtent;
                    _scheduleAnimationActivitySync();
                  }
                  final String? confirmationGuideAnchorJobId =
                      _confirmationGuideAnchorJobId;
                  _scheduleConfirmationGuideSync(
                    widget.showConfirmationGuide
                        ? confirmationGuideAnchorJobId
                        : null,
                  );
                  return KeyedSubtree(
                    key: const ValueKey<String>(
                      'generation-submission-photo-list',
                    ),
                    child: AnimatedList(
                      key: _listKey,
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: _horizontalPadding,
                      ),
                      initialItemCount: _displayJobs.length + 1,
                      itemBuilder:
                          (
                            BuildContext context,
                            int index,
                            Animation<double> animation,
                          ) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(right: _itemGap),
                                child: _GalleryMomentItem(
                                  key: const ValueKey<String>(
                                    'generation-submission-gallery-picker-item',
                                  ),
                                  width: tileWidth,
                                  height: itemHeight,
                                  imageHeight: tileHeight,
                                  caption: context
                                      .l10n
                                      .generationSubmissionImportNew,
                                  child: _GalleryPickerTile(
                                    width: tileWidth,
                                    height: tileHeight,
                                    picking: widget.pickingGalleryImage,
                                    onTap: widget.onPickGalleryImage,
                                  ),
                                ),
                              );
                            }
                            final int jobIndex = index - 1;
                            if (jobIndex < 0 ||
                                jobIndex >= _displayJobs.length) {
                              return const SizedBox.shrink();
                            }
                            final GenerationSubmissionJob job =
                                _displayJobs[jobIndex];
                            final bool hasConfirmationGuideAnchor =
                                confirmationGuideAnchorJobId == job.id;
                            return _AnimatedGalleryJobListItem(
                              key: ValueKey<String>(
                                'generation-submission-photo-list-item-${job.id}',
                              ),
                              job: job,
                              selected: widget.selectedJob?.id == job.id,
                              animationActive: _animationActiveJobIds.contains(
                                job.id,
                              ),
                              animation: _animationForJob(job, animation),
                              onTap: () => widget.onSelectJob(job),
                              onConfirm:
                                  job.status ==
                                      GenerationSubmissionStatus
                                          .awaitingConfirmation
                                  ? () => widget.onConfirmJob(job)
                                  : null,
                              onCancel:
                                  job.status ==
                                      GenerationSubmissionStatus
                                          .awaitingConfirmation
                                  ? () => widget.onCancelJob(job)
                                  : null,
                              onRetry: _canRetryJob(job)
                                  ? () => widget.onRetryJob(job)
                                  : null,
                              onRemove: _canRemoveFailedJob(job)
                                  ? () => widget.onRemoveJob(job)
                                  : null,
                              hasConfirmationGuideAnchor:
                                  hasConfirmationGuideAnchor,
                              confirmationGuideTooltipController:
                                  _confirmationGuideTooltipController,
                              onDismissConfirmationGuide:
                                  widget.onDismissConfirmationGuide,
                            );
                          },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _syncConfirmationGuideAnchor() {
    final String? anchorJobId = _confirmationGuideAnchorJobId;
    if (anchorJobId != null &&
        _displayJobs.any(
          (GenerationSubmissionJob job) => job.id == anchorJobId,
        )) {
      return;
    }
    _confirmationGuideAnchorJobId = null;
    if (!widget.showConfirmationGuide) {
      return;
    }
    for (final GenerationSubmissionJob job in _displayJobs) {
      if (job.status == GenerationSubmissionStatus.awaitingConfirmation) {
        _confirmationGuideAnchorJobId = job.id;
        return;
      }
    }
  }

  void _scheduleConfirmationGuideSync(String? jobId) {
    _pendingConfirmationGuideJobId = jobId;
    if (_confirmationGuideSyncScheduled) {
      return;
    }
    _confirmationGuideSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confirmationGuideSyncScheduled = false;
      if (!mounted) {
        return;
      }
      final String? pendingJobId = _pendingConfirmationGuideJobId;
      if (pendingJobId == null) {
        unawaited(_hideConfirmationGuideTooltip());
        return;
      }
      Future<void>.delayed(Duration.zero, () {
        if (!mounted || _pendingConfirmationGuideJobId != pendingJobId) {
          return;
        }
        unawaited(_showConfirmationGuideTooltip());
      });
    });
  }

  Future<void> _showConfirmationGuideTooltip() async {
    try {
      await _confirmationGuideTooltipController.showTooltip(autoClose: false);
    } on StateError {
      // The target item may not be attached yet while AnimatedList scrolls it in.
    }
  }

  Future<void> _hideConfirmationGuideTooltip() async {
    try {
      await _confirmationGuideTooltipController.hideTooltip();
    } on StateError {
      // The tooltip controller is unattached until the target item is built.
    }
  }

  bool _canRetryJob(GenerationSubmissionJob job) {
    return job.isRetryableFailure;
  }

  bool _canRemoveFailedJob(GenerationSubmissionJob job) {
    return job.status == GenerationSubmissionStatus.failed ||
        job.status == GenerationSubmissionStatus.resultProcessingFailed;
  }

  Animation<double> _animationForJob(
    GenerationSubmissionJob job,
    Animation<double> animation,
  ) {
    if (!_insertingJobIds.contains(job.id) || animation.value == 1) {
      return kAlwaysCompleteAnimation;
    }
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _insertingJobIds.remove(job.id);
      return kAlwaysCompleteAnimation;
    }
    return animation;
  }
}

class _GalleryMomentItem extends StatelessWidget {
  const _GalleryMomentItem({
    required this.width,
    required this.height,
    required this.imageHeight,
    required this.caption,
    required this.child,
    super.key,
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
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
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
          ),
        ],
      ),
    );
  }
}

class _AnimatedGalleryJobListItem extends StatelessWidget {
  const _AnimatedGalleryJobListItem({
    required this.job,
    required this.selected,
    required this.animationActive,
    required this.animation,
    required this.onTap,
    required this.onConfirm,
    required this.onCancel,
    required this.onRetry,
    required this.onRemove,
    required this.hasConfirmationGuideAnchor,
    required this.confirmationGuideTooltipController,
    required this.onDismissConfirmationGuide,
    super.key,
    this.removing = false,
  });

  final GenerationSubmissionJob job;
  final bool selected;
  final bool animationActive;
  final Animation<double> animation;
  final VoidCallback onTap;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;
  final bool hasConfirmationGuideAnchor;
  final JustTheController confirmationGuideTooltipController;
  final VoidCallback onDismissConfirmationGuide;
  final bool removing;

  @override
  Widget build(BuildContext context) {
    final Animation<double> curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SizeTransition(
      axis: Axis.horizontal,
      axisAlignment: -1,
      sizeFactor: curvedAnimation,
      child: FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: removing ? const Offset(0, 0.08) : const Offset(0.18, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: Padding(
            padding: const EdgeInsets.only(
              right: _RelatedMomentsStripState._itemGap,
            ),
            child: IgnorePointer(
              ignoring: removing,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double itemHeight = constraints.maxHeight;
                  const double captionGap = 6;
                  const double captionHeight = 12;
                  final double tileHeight =
                      (itemHeight - captionGap - captionHeight).clamp(
                        0.0,
                        280.0,
                      );
                  final double tileWidth =
                      tileHeight *
                      _RelatedMomentsStripState._thumbnailAspectRatio;
                  Widget thumbnail = _JobThumbnail(
                    thumbnailKey: removing
                        ? 'generation-submission-removing-photo-${job.id}'
                        : null,
                    width: tileWidth,
                    height: tileHeight,
                    job: job,
                    selected: selected,
                    animationActive: animationActive,
                    onTap: onTap,
                    onConfirm: onConfirm,
                    onCancel: onCancel,
                    onRetry: onRetry,
                    onRemove: onRemove,
                  );
                  if (hasConfirmationGuideAnchor) {
                    thumbnail = _ConfirmationGuideTooltip(
                      controller: confirmationGuideTooltipController,
                      onDismiss: onDismissConfirmationGuide,
                      child: thumbnail,
                    );
                  }
                  return _GalleryMomentItem(
                    width: tileWidth,
                    height: itemHeight,
                    imageHeight: tileHeight,
                    caption: _captionForJob(job),
                    child: thumbnail,
                  );
                },
              ),
            ),
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
    return '$hour:$minute $period';
  }
}

class _ConfirmationGuideTooltip extends StatelessWidget {
  const _ConfirmationGuideTooltip({
    required this.controller,
    required this.onDismiss,
    required this.child,
  });

  final JustTheController controller;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return JustTheTooltip(
      key: const ValueKey<String>(
        'generation-submission-confirmation-guide-tooltip',
      ),
      controller: controller,
      triggerMode: TooltipTriggerMode.manual,
      preferredDirection: AxisDirection.up,
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      offset: 8,
      tailLength: 9,
      tailBaseWidth: 18,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      backgroundColor: AppColors.blackOverlay(0.82),
      fadeInDuration: const Duration(milliseconds: 180),
      fadeOutDuration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
      content: _ConfirmationGuideTooltipContent(onDismiss: onDismiss),
      child: child,
    );
  }
}

class _ConfirmationGuideTooltipContent extends StatelessWidget {
  const _ConfirmationGuideTooltipContent({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.l10n.generationSubmissionConfirmationGuideMessage,
              key: const ValueKey<String>(
                'generation-submission-confirmation-guide-message',
              ),
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
                height: 1.32,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                key: const ValueKey<String>(
                  'generation-submission-confirmation-guide-dismiss',
                ),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                onPressed: onDismiss,
                child: Text(
                  context.l10n.generationSubmissionConfirmationGuideDismiss,
                  style: TextStyle(
                    color: colors.accentYellow,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
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

class _JobThumbnail extends StatefulWidget {
  const _JobThumbnail({
    required this.width,
    required this.height,
    required this.job,
    required this.selected,
    required this.animationActive,
    required this.onTap,
    required this.onConfirm,
    required this.onCancel,
    required this.onRetry,
    required this.onRemove,
    this.thumbnailKey,
  });

  final double width;
  final double height;
  final GenerationSubmissionJob job;
  final bool selected;
  final bool animationActive;
  final VoidCallback onTap;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;
  final String? thumbnailKey;

  @override
  State<_JobThumbnail> createState() => _JobThumbnailState();
}

class _JobThumbnailState extends State<_JobThumbnail> {
  static const Duration _flipDuration = Duration(milliseconds: 800);
  static const Duration _gridSquareRevealDelay = Duration(seconds: 1);
  static const Duration _gridSquareFadeDuration = Duration(milliseconds: 240);

  late final FlipCardController _flipController;
  late GenerationSubmissionStatus _backStatus;
  late GenerationSubmissionStatus _frontStatus;
  late VoidCallback? _frontOnConfirm;
  late VoidCallback? _frontOnCancel;
  late VoidCallback? _frontOnRetry;
  late VoidCallback? _frontOnRemove;
  Timer? _gridSquareRevealTimer;
  late bool _showGridSquare;

  @override
  void initState() {
    super.initState();
    _flipController = FlipCardController();
    _backStatus = _isLoading(widget.job.status)
        ? widget.job.status
        : GenerationSubmissionStatus.queued;
    _showGridSquare = _isLoading(widget.job.status);
    _captureFrontState();
  }

  @override
  void didUpdateWidget(covariant _JobThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool wasLoading = _isLoading(oldWidget.job.status);
    final bool loading = _isLoading(widget.job.status);
    if (loading) {
      _backStatus = widget.job.status;
      if (!wasLoading) {
        _cancelGridSquareReveal();
        _showGridSquare = false;
      }
    } else {
      _cancelGridSquareReveal();
      _showGridSquare = false;
      _captureFrontState();
    }
  }

  @override
  void dispose() {
    _cancelGridSquareReveal();
    super.dispose();
  }

  void _captureFrontState() {
    _frontStatus = widget.job.status;
    _frontOnConfirm = widget.onConfirm;
    _frontOnCancel = widget.onCancel;
    _frontOnRetry = widget.onRetry;
    _frontOnRemove = widget.onRemove;
  }

  void _handleFlipCompleted(FlipCardSide side) {
    if (side != FlipCardSide.back || !_isLoading(widget.job.status)) {
      _cancelGridSquareReveal();
      return;
    }
    if (_showGridSquare) {
      return;
    }
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      setState(() => _showGridSquare = true);
      return;
    }
    _cancelGridSquareReveal();
    _gridSquareRevealTimer = Timer(_gridSquareRevealDelay, () {
      if (!mounted || !_isLoading(widget.job.status)) {
        return;
      }
      setState(() => _showGridSquare = true);
    });
  }

  void _cancelGridSquareReveal() {
    _gridSquareRevealTimer?.cancel();
    _gridSquareRevealTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    final String thumbnailImagePath =
        widget.job.status == GenerationSubmissionStatus.resultSaved
        ? widget.job.processedResultPath ?? ''
        : widget.job.imagePath;
    final bool thumbnailUsesOriginal =
        thumbnailImagePath == widget.job.imagePath;
    final bool awaitingConfirmation =
        _frontStatus == GenerationSubmissionStatus.awaitingConfirmation;
    final bool loading = _isLoading(widget.job.status);
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Widget front = _ThumbnailCardFace(
      width: widget.width,
      height: widget.height,
      selected: widget.selected,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _ThumbnailImage(
            key: ValueKey<String>(
              'generation-thumbnail-image-${widget.job.id}',
            ),
            path: thumbnailImagePath,
            width: widget.width,
            height: widget.height,
            sourceWidth: thumbnailUsesOriginal
                ? widget.job.originalWidth
                : null,
            sourceHeight: thumbnailUsesOriginal
                ? widget.job.originalHeight
                : null,
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !awaitingConfirmation,
              child: AnimatedSwitcher(
                duration: MediaQuery.maybeDisableAnimationsOf(context) ?? false
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder:
                    (Widget? currentChild, List<Widget> previousChildren) {
                      return Stack(
                        fit: StackFit.expand,
                        children: <Widget>[...previousChildren, ?currentChild],
                      );
                    },
                child: awaitingConfirmation
                    ? _AwaitingConfirmationOverlay(
                        key: ValueKey<String>(
                          'generation-submission-awaiting-overlay-'
                          '${widget.job.id}',
                        ),
                        jobId: widget.job.id,
                        deleteLabel:
                            context.l10n.generationSubmissionActionDelete,
                        onDelete: _frontOnCancel,
                      )
                    : SizedBox.expand(
                        key: ValueKey<String>(
                          'generation-submission-awaiting-overlay-empty-'
                          '${widget.job.id}',
                        ),
                      ),
              ),
            ),
          ),
          if (_frontOnRemove != null)
            Positioned(
              key: ValueKey<String>(
                'generation-submission-remove-slot-${widget.job.id}',
              ),
              left: 0,
              top: 0,
              child: _ThumbnailDeleteAction(
                actionKey: ValueKey<String>(
                  'generation-submission-remove-${widget.job.id}',
                ),
                visualKey: ValueKey<String>(
                  'generation-submission-remove-visual-${widget.job.id}',
                ),
                semanticsLabel: context.l10n.generationSubmissionActionDelete,
                onPressed: _frontOnRemove,
              ),
            ),
          Positioned(
            key: ValueKey<String>(
              'generation-submission-state-pill-slot-${widget.job.id}',
            ),
            left: 6,
            right: 6,
            bottom: 6,
            height: 44,
            child: GenerationStatusPill(
              key: ValueKey<String>(
                'generation-submission-state-pill-${widget.job.id}',
              ),
              jobId: widget.job.id,
              status: _frontStatus,
              onConfirm: _frontOnConfirm,
              onRetry: _frontOnRetry,
              height: 22,
            ),
          ),
          if (!awaitingConfirmation)
            Positioned(
              key: ValueKey<String>(
                'generation-submission-prompt-slot-${widget.job.id}',
              ),
              left: 6,
              right: 6,
              top: 6,
              child: _PromptSnapshotBadge(job: widget.job),
            ),
        ],
      ),
    );
    final Widget back = _ThumbnailCardFace(
      width: widget.width,
      height: widget.height,
      selected: widget.selected,
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : _gridSquareFadeDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[...previousChildren, ?currentChild],
          );
        },
        child: loading
            ? Stack(
                key: ValueKey<String>(
                  'generation-submission-grid-square-loading-${widget.job.id}',
                ),
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(color: colors.surface),
                  ExcludeSemantics(
                    excluding: !_showGridSquare,
                    child: AnimatedOpacity(
                      key: ValueKey<String>(
                        'generation-submission-grid-square-reveal-${widget.job.id}',
                      ),
                      opacity: _showGridSquare ? 1 : 0,
                      duration: reduceMotion
                          ? Duration.zero
                          : _gridSquareFadeDuration,
                      curve: Curves.easeOutCubic,
                      child: TickerMode(
                        key: ValueKey<String>(
                          'generation-submission-grid-square-ticker-${widget.job.id}',
                        ),
                        enabled: _showGridSquare && widget.animationActive,
                        child: _GenerationLoadingCardBack(
                          key: ValueKey<String>(
                            'generation-submission-grid-square-back-${widget.job.id}',
                          ),
                          jobId: widget.job.id,
                          animationIndex:
                              widget.job.animationIndex ??
                              generationDefaultAnimationIndex,
                          imagePath: widget.job.imagePath,
                          startedAt: widget.job.generationStartedAt,
                          status: _backStatus,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : ColoredBox(
                key: ValueKey<String>(
                  'generation-submission-grid-square-inactive-${widget.job.id}',
                ),
                color: colors.surface,
              ),
      ),
    );

    return GestureDetector(
      key: ValueKey<String>(
        widget.thumbnailKey ?? 'generation-submission-photo-${widget.job.id}',
      ),
      onTap: widget.onTap,
      child: FlipCard(
        key: ValueKey<String>('generation-submission-flip-${widget.job.id}'),
        controller: _flipController,
        side: loading ? FlipCardSide.back : FlipCardSide.front,
        initialSide: loading ? FlipCardSide.back : FlipCardSide.front,
        rotateSide: RotateSide.bottom,
        axis: FlipAxis.horizontal,
        animationDuration: _flipDuration,
        curve: Curves.easeInOutCubic,
        frontWidget: IgnorePointer(ignoring: loading, child: front),
        backWidget: back,
        onFlipCompleted: _handleFlipCompleted,
      ),
    );
  }

  bool _isLoading(GenerationSubmissionStatus status) {
    return GenerationRecordStateMachine.showsGenerationProgress(status);
  }
}

class _ThumbnailCardFace extends StatelessWidget {
  const _ThumbnailCardFace({
    required this.width,
    required this.height,
    required this.selected,
    required this.child,
  });

  final double width;
  final double height;
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    final double selectedValue = selected ? 1 : 0;
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: selectedValue, end: selectedValue),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        final double borderWidth = lerpDouble(1, 3, value)!;
        final Color borderColor =
            Color.lerp(colors.border, colors.accentYellow, value) ??
            colors.border;
        return SmoothContainer(
          width: width,
          height: height,
          borderRadius: AppCorners.controlBorderRadius,
          smoothness: AppCorners.smoothness,
          side: BorderSide(color: borderColor, width: borderWidth),
          padding: EdgeInsets.all(borderWidth),
          child: SmoothClipRRect(
            borderRadius: BorderRadius.circular(
              (AppCorners.controlRadius - borderWidth).clamp(0.0, 999.0),
            ),
            smoothness: AppCorners.smoothness,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      child: child,
    );
  }
}

class _GenerationLoadingCardBack extends StatefulWidget {
  const _GenerationLoadingCardBack({
    super.key,
    required this.jobId,
    required this.animationIndex,
    required this.imagePath,
    required this.startedAt,
    required this.status,
  });

  final String jobId;
  final int animationIndex;
  final String imagePath;
  final DateTime? startedAt;
  final GenerationSubmissionStatus status;

  @override
  State<_GenerationLoadingCardBack> createState() =>
      _GenerationLoadingCardBackState();
}

class _GenerationLoadingCardBackState
    extends State<_GenerationLoadingCardBack> {
  late final GenerationProgressTicker _progressTicker;

  @override
  void initState() {
    super.initState();
    _progressTicker = GenerationProgressTicker(
      startedAt: widget.startedAt,
      status: widget.status,
      active: true,
    );
  }

  @override
  void didUpdateWidget(covariant _GenerationLoadingCardBack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _progressTicker.update(
      startedAt: widget.startedAt,
      status: widget.status,
      active: true,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progressTicker.setTickerModeEnabled(TickerMode.valuesOf(context).enabled);
  }

  @override
  void dispose() {
    _progressTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(
          key: ValueKey<String>(
            'generation-submission-grid-square-background-${widget.jobId}',
          ),
          color: colors.surface,
        ),
        ExcludeSemantics(
          child: _GenerationGridSquare(
            key: ValueKey<String>(
              'generation-submission-grid-square-loop-${widget.jobId}',
            ),
            animationKey: ValueKey<String>(
              'generation-submission-grid-square-${widget.jobId}',
            ),
            animationIndex: widget.animationIndex,
            imagePath: widget.imagePath,
          ),
        ),
        ListenableBuilder(
          listenable: _progressTicker,
          builder: (BuildContext context, Widget? child) {
            final int? percentage = _progressTicker.estimate.percentage;
            final String label = percentage == null
                ? context.l10n.generationSubmissionEstimatedFinishing
                : context.l10n.generationSubmissionEstimatedProgressPercent(
                    percentage,
                  );
            return Semantics(
              label: label,
              child: Center(
                child: Text(
                  label,
                  key: ValueKey<String>(
                    'generation-submission-grid-square-progress-${widget.jobId}',
                  ),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

enum _GenerationGridSquareAnimationVariant { diagonal, diamond, rowsEnhanced }

class _GenerationGridSquare extends ConsumerStatefulWidget {
  const _GenerationGridSquare({
    required this.animationKey,
    required this.animationIndex,
    required this.imagePath,
    super.key,
  }) : assert(animationIndex >= 0);

  static const int _rows = 7;
  static const int _columns = 5;
  static const double _cardPadding = 8;
  static final Map<
    _GenerationGridSquareAnimationVariant,
    _GenerationGridSquareAnimationSpec
  >
  _animationSpecs =
      <
        _GenerationGridSquareAnimationVariant,
        _GenerationGridSquareAnimationSpec
      >{
        _GenerationGridSquareAnimationVariant.diagonal:
            const _GenerationGridSquareAnimationSpec(
              groupedSequence: <List<int>>[
                <int>[0],
                <int>[1],
                <int>[5],
                <int>[2],
                <int>[6],
                <int>[10],
                <int>[3],
                <int>[7],
                <int>[11],
                <int>[15],
                <int>[4],
                <int>[8],
                <int>[12],
                <int>[16],
                <int>[20],
                <int>[9],
                <int>[13],
                <int>[17],
                <int>[21],
                <int>[25],
                <int>[14],
                <int>[18],
                <int>[22],
                <int>[26],
                <int>[30],
                <int>[19],
                <int>[23],
                <int>[27],
                <int>[31],
                <int>[24],
                <int>[28],
                <int>[32],
                <int>[29],
                <int>[33],
                <int>[34],
              ],
              lightUpDuration: Duration(milliseconds: 300),
              dimDuration: Duration(milliseconds: 1000),
              staggerInterval: Duration(milliseconds: 72),
              groupLoopPauseDuration: Duration(milliseconds: 150),
            ),
        _GenerationGridSquareAnimationVariant.diamond:
            const _GenerationGridSquareAnimationSpec(
              groupedSequence: <List<int>>[
                <int>[17],
                <int>[12, 16, 18, 22],
                <int>[7, 11, 13, 15, 19, 21, 23, 27],
                <int>[2, 6, 8, 10, 14, 20, 24, 26, 28, 32],
                <int>[1, 3, 5, 9, 25, 29, 31, 33],
                <int>[0, 4, 30, 34],
              ],
              lightUpDuration: Duration(milliseconds: 300),
              dimDuration: Duration(milliseconds: 518),
              staggerInterval: Duration(milliseconds: 118),
              groupLoopPauseDuration: Duration(milliseconds: 243),
            ),
        _GenerationGridSquareAnimationVariant.rowsEnhanced:
            _GenerationGridSquareAnimationSpec(
              groupedSequence: List<List<int>>.generate(
                _rows * _columns,
                (int index) => <int>[index],
                growable: false,
              ),
              lightUpDuration: const Duration(milliseconds: 300),
              dimDuration: const Duration(milliseconds: 1000),
              staggerInterval: const Duration(milliseconds: 72),
              groupLoopPauseDuration: const Duration(milliseconds: 570),
            ),
      };

  final Key animationKey;
  final int animationIndex;
  final String imagePath;

  static _GenerationGridSquareAnimationSpec _animationSpecForIndex(
    int animationIndex,
  ) {
    final _GenerationGridSquareAnimationVariant variant =
        _GenerationGridSquareAnimationVariant.values[animationIndex %
            _GenerationGridSquareAnimationVariant.values.length];
    return _animationSpecs[variant]!;
  }

  @override
  ConsumerState<_GenerationGridSquare> createState() =>
      _GenerationGridSquareState();
}

class _GenerationGridSquareState extends ConsumerState<_GenerationGridSquare> {
  static final _GenerationGridSquarePalette _fallbackPalette =
      _GenerationGridSquarePalette.fromMosaic(
        GenerationImageMosaic.fallback(
          rows: _GenerationGridSquare._rows,
          columns: _GenerationGridSquare._columns,
        ),
        rows: _GenerationGridSquare._rows,
        columns: _GenerationGridSquare._columns,
      );

  late Future<_GenerationGridSquarePalette> _paletteFuture;

  @override
  void initState() {
    super.initState();
    _paletteFuture = _extractPalette();
  }

  @override
  void didUpdateWidget(covariant _GenerationGridSquare oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imagePath != oldWidget.imagePath) {
      _paletteFuture = _extractPalette();
    }
  }

  Future<_GenerationGridSquarePalette> _extractPalette() async {
    final GenerationImageMosaic mosaic = await ref
        .read(generationImageMosaicRepositoryProvider)
        .extract(
          widget.imagePath,
          rows: _GenerationGridSquare._rows,
          columns: _GenerationGridSquare._columns,
        );
    return _GenerationGridSquarePalette.fromMosaic(
      mosaic,
      rows: _GenerationGridSquare._rows,
      columns: _GenerationGridSquare._columns,
    );
  }

  @override
  Widget build(BuildContext context) {
    final _GenerationGridSquareAnimationSpec animationSpec =
        _GenerationGridSquare._animationSpecForIndex(widget.animationIndex);
    final bool tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    final bool reduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return FutureBuilder<_GenerationGridSquarePalette>(
      future: _paletteFuture,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<_GenerationGridSquarePalette> snapshot,
          ) {
            final _GenerationGridSquarePalette palette =
                snapshot.data ?? _fallbackPalette;
            return TickerMode(
              enabled: tickerModeEnabled && !reduceMotion,
              child: Padding(
                padding: const EdgeInsets.all(
                  _GenerationGridSquare._cardPadding,
                ),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return GridSquareAnimation(
                      key: widget.animationKey,
                      rows: _GenerationGridSquare._rows,
                      columns: _GenerationGridSquare._columns,
                      groupedSequence: animationSpec.groupedSequence,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      spacing: animationSpec.spacing,
                      borderRadius: animationSpec.borderRadius,
                      lightUpDuration: animationSpec.lightUpDuration,
                      dimDuration: animationSpec.dimDuration,
                      staggerInterval: animationSpec.staggerInterval,
                      groupLoopPauseDuration:
                          animationSpec.groupLoopPauseDuration,
                      baseColor: AppColors.accentYellow.withValues(
                        alpha: generationImageMosaicBaseAlpha,
                      ),
                      lightUpColor: AppColors.accentYellow,
                      baseCellColors: palette.baseCellColors,
                      lightUpCellColors: palette.lightUpCellColors,
                      lightUpCurve: animationSpec.lightUpCurve,
                      dimCurve: animationSpec.dimCurve,
                      enableGlow: animationSpec.enableGlow,
                      glowIntensity: animationSpec.glowIntensity,
                    );
                  },
                ),
              ),
            );
          },
    );
  }
}

@immutable
class _GenerationGridSquarePalette {
  const _GenerationGridSquarePalette({
    required this.baseCellColors,
    required this.lightUpCellColors,
  });

  factory _GenerationGridSquarePalette.fromMosaic(
    GenerationImageMosaic mosaic, {
    required int rows,
    required int columns,
  }) {
    final GenerationImageMosaic fallback = GenerationImageMosaic.fallback(
      rows: rows,
      columns: columns,
    );
    final List<Color> sampledCellColors =
        mosaic.rows == rows &&
            mosaic.columns == columns &&
            mosaic.cellColors.length == rows * columns
        ? mosaic.cellColors
        : fallback.cellColors;
    return _GenerationGridSquarePalette(
      baseCellColors: generationImageMosaicBaseColors(sampledCellColors),
      lightUpCellColors: generationImageMosaicLightUpColors(sampledCellColors),
    );
  }

  final List<Color> baseCellColors;
  final List<Color> lightUpCellColors;
}

class _GenerationGridSquareAnimationSpec {
  const _GenerationGridSquareAnimationSpec({
    required this.groupedSequence,
    required this.lightUpDuration,
    required this.dimDuration,
    required this.staggerInterval,
    required this.groupLoopPauseDuration,
  });

  final List<List<int>> groupedSequence;
  final Duration lightUpDuration;
  final Duration dimDuration;
  final Duration staggerInterval;
  final Duration groupLoopPauseDuration;
  Curve get lightUpCurve => Curves.easeOutCubic;
  Curve get dimCurve => Curves.easeInCubic;
  double get spacing => 2.173295454545453;
  double get borderRadius => 4;
  bool get enableGlow => true;
  double get glowIntensity => 0.63;
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({
    super.key,
    required this.path,
    required this.width,
    required this.height,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  final String path;
  final double width;
  final double height;
  final int? sourceWidth;
  final int? sourceHeight;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) {
      return const _MissingOriginalImagePlaceholder();
    }
    final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return Image(
      image: _thumbnailImageProvider(
        file: File(path),
        logicalSize: Size(width, height),
        devicePixelRatio: devicePixelRatio,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
      ),
      fit: BoxFit.cover,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        appDebugLog(
          'GenerationSubmissionModal',
          'thumbnail image load failure path=$path error=$error',
        );
        return const _MissingOriginalImagePlaceholder();
      },
    );
  }
}

ImageProvider<Object> _thumbnailImageProvider({
  required File file,
  required Size logicalSize,
  required double devicePixelRatio,
  required int? sourceWidth,
  required int? sourceHeight,
}) {
  final Size physicalSize = Size(
    math.max(1, logicalSize.width * devicePixelRatio),
    math.max(1, logicalSize.height * devicePixelRatio),
  );
  final bool hasSourceSize =
      sourceWidth != null &&
      sourceWidth > 0 &&
      sourceHeight != null &&
      sourceHeight > 0;
  if (hasSourceSize) {
    final double coverScale = math.max(
      physicalSize.width / sourceWidth,
      physicalSize.height / sourceHeight,
    );
    return ResizeImage(
      FileImage(file),
      width: math.max(1, (sourceWidth * coverScale).ceil()),
      height: math.max(1, (sourceHeight * coverScale).ceil()),
      policy: ResizeImagePolicy.fit,
    );
  }

  final int conservativeBound = math.max(
    1,
    (math.max(physicalSize.width, physicalSize.height) * 3).ceil(),
  );
  return ResizeImage(
    FileImage(file),
    width: conservativeBound,
    height: conservativeBound,
    policy: ResizeImagePolicy.fit,
  );
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
    final AppThemeColors colors = AppThemeColors.of(context);
    final PromptSelectionSnapshot selection =
        job.promptSelection ?? PromptSelectionSnapshot.fallback;
    final String? label = generationThumbnailPromptBadgeLabel(
      selection: selection,
      manualLabel: context.l10n.promptCaptureModeManualTitle,
    );
    if (label == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.topLeft,
      child: DecoratedBox(
        decoration: AppCorners.controlDecoration(color: colors.accentYellow),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Text(
            label,
            key: ValueKey<String>('generation-submission-prompt-${job.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
String? generationThumbnailPromptBadgeLabel({
  required PromptSelectionSnapshot selection,
  required String manualLabel,
}) {
  final int activeCount = selection.switches.values
      .where((bool selected) => selected)
      .length;
  if (activeCount > 0) {
    return '+$activeCount';
  }
  if (selection.captureMode == manualCaptureMode) {
    return manualLabel;
  }
  return null;
}

class _AwaitingConfirmationOverlay extends StatelessWidget {
  const _AwaitingConfirmationOverlay({
    super.key,
    required this.jobId,
    required this.deleteLabel,
    required this.onDelete,
  });

  final String jobId;
  final String deleteLabel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            widthFactor: 1,
            heightFactor: 0.45,
            child: IgnorePointer(
              child: DecoratedBox(
                key: ValueKey<String>(
                  'generation-submission-bottom-gradient-$jobId',
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x00000000), Color(0xD9000000)],
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: _ThumbnailDeleteAction(
            actionKey: ValueKey<String>('generation-submission-cancel-$jobId'),
            visualKey: ValueKey<String>(
              'generation-submission-cancel-visual-$jobId',
            ),
            semanticsLabel: deleteLabel,
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }
}

class _ThumbnailDeleteAction extends StatelessWidget {
  const _ThumbnailDeleteAction({
    required this.actionKey,
    required this.visualKey,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final Key actionKey;
  final Key visualKey;
  final String semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: semanticsLabel,
        child: GestureDetector(
          key: actionKey,
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: ExcludeSemantics(
            child: Center(
              child: DecoratedBox(
                key: visualKey,
                decoration: AppCorners.controlDecoration(
                  color: AppColors.blackOverlay(0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const SizedBox.square(
                  dimension: 24,
                  child: Icon(
                    LucideIcons.trash2,
                    color: AppColors.danger,
                    size: 14,
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
    required this.onUpdatePromptSelection,
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
  final ValueChanged<PromptSelectionSnapshot>? onUpdatePromptSelection;
  final ValueChanged<_HeroMoreAction>? onMoreActions;

  @override
  State<_GalleryHeroPager> createState() => _GalleryHeroPagerState();
}

class _GalleryHeroPagerState extends State<_GalleryHeroPager> {
  final Map<String, PhotoViewController> _photoControllers =
      <String, PhotoViewController>{};
  final Map<String, Size> _imageSizes = <String, Size>{};
  final Set<String> _resolvingImageSizes = <String>{};
  bool _toolbarExpanded = false;
  int _toolbarCollapseRequest = 0;

  @override
  void didUpdateWidget(covariant _GalleryHeroPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedJob?.id != widget.selectedJob?.id ||
        widget.selectedJob == null ||
        widget.jobs.isEmpty) {
      _toolbarExpanded = false;
      _toolbarCollapseRequest += 1;
    }
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

  void _handleToolbarExpansionChanged(bool expanded) {
    if (_toolbarExpanded == expanded) {
      return;
    }
    setState(() {
      _toolbarExpanded = expanded;
    });
  }

  void _collapseExpandedToolbar() {
    if (!_toolbarExpanded) {
      return;
    }
    setState(() {
      _toolbarExpanded = false;
      _toolbarCollapseRequest += 1;
    });
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
          Positioned.fill(
            key: const ValueKey<String>(
              'generation-submission-more-dismiss-position',
            ),
            child: IgnorePointer(
              ignoring: !_toolbarExpanded,
              child: Opacity(
                opacity: _toolbarExpanded ? 1 : 0,
                child: GestureDetector(
                  key: const ValueKey<String>(
                    'generation-submission-more-dismiss-layer',
                  ),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _collapseExpandedToolbar(),
                ),
              ),
            ),
          ),
          Positioned(
            key: const ValueKey<String>(
              'generation-submission-hero-toolbar-position',
            ),
            left: 0,
            right: 0,
            bottom: 18,
            child: _HeroToolbar(
              key: const ValueKey<String>('generation-submission-hero-toolbar'),
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
              onUpdatePromptSelection:
                  selectedJob.status ==
                      GenerationSubmissionStatus.awaitingConfirmation
                  ? widget.onUpdatePromptSelection
                  : null,
              onMoreActions: widget.onMoreActions,
              collapseRequest: _toolbarCollapseRequest,
              onExpansionChanged: _handleToolbarExpansionChanged,
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
    if (imageSource is _HeroUnavailableImageSource) {
      return PhotoViewGalleryPageOptions.customChild(
        child: Padding(
          padding: EdgeInsets.only(top: widget.topPadding),
          child: _HeroImageFailure(message: imageSource.failureMessage),
        ),
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
      appDebugLog(
        'GenerationSubmissionModal',
        '${imageSource.failureLogLabel} load failure path=${imageSource.debugPath} error=$error',
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
              appDebugLog(
                'GenerationSubmissionModal',
                '${originalImageSource.failureLogLabel} load failure path=${originalImageSource.debugPath} error=$error',
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
      if (imageSource is _HeroUnavailableImageSource) {
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

    if (job.status != GenerationSubmissionStatus.resultSaved) {
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

    if (job.hasMissingSavedResult) {
      return _HeroUnavailableImageSource(
        key: const ValueKey<String>(
          'generation-submission-processed-result-image-missing',
        ),
        failureLogLabel: 'processed result image',
        failureMessage:
            context.l10n.generationSubmissionProcessedResultImageLoadFailed,
      );
    }

    return _originalImageSourceForJob(job);
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
    if (job.hasResultDisplayTarget) {
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
    if (job.status == GenerationSubmissionStatus.resultSaved) {
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
    return job.status != GenerationSubmissionStatus.resultSaved;
  }

  bool _canToggleHeroImage(GenerationSubmissionJob job) {
    if (job.imagePath.isEmpty) {
      return false;
    }

    return switch (job.status) {
      GenerationSubmissionStatus.resultSaved => job.hasResultDisplayTarget,
      _ => false,
    };
  }

  bool _canToggleFavorite(GenerationSubmissionJob job) {
    return job.status == GenerationSubmissionStatus.resultSaved &&
        job.resultAvailability ==
            GenerationRecordResultAvailability.savedToPhotoLibrary &&
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

class _HeroUnavailableImageSource extends _HeroImageSource {
  const _HeroUnavailableImageSource({
    required super.key,
    required super.failureLogLabel,
    required super.failureMessage,
  }) : super(path: '');

  @override
  ImageProvider get imageProvider =>
      throw StateError('Unavailable image source does not resolve images.');
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

enum _HeroToolbarExpansion { moreActions, promptSettings }

enum _HeroToolbarContentKind {
  moreActions,
  promptAutoSettings,
  promptManualSettings,
}

class _HeroToolbarLayoutSpec {
  const _HeroToolbarLayoutSpec({
    required this.expandedSize,
    required this.contentPadding,
    required this.modeRowHeight,
    required this.switchesRowHeight,
    required this.contentGap,
  });

  static const _HeroToolbarLayoutSpec moreActions = _HeroToolbarLayoutSpec(
    expandedSize: Size(220, 232),
    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    modeRowHeight: 0,
    switchesRowHeight: 0,
    contentGap: 0,
  );
  static const _HeroToolbarLayoutSpec promptAuto = _HeroToolbarLayoutSpec(
    expandedSize: Size(164, 50),
    contentPadding: EdgeInsets.all(8),
    modeRowHeight: 34,
    switchesRowHeight: 0,
    contentGap: 0,
  );
  static const _HeroToolbarLayoutSpec promptManual = _HeroToolbarLayoutSpec(
    expandedSize: Size(320, 106),
    contentPadding: EdgeInsets.all(8),
    modeRowHeight: 34,
    switchesRowHeight: 48,
    contentGap: 8,
  );

  final Size expandedSize;
  final EdgeInsets contentPadding;
  final double modeRowHeight;
  final double switchesRowHeight;
  final double contentGap;
}

class _HeroToolbarContentModel {
  const _HeroToolbarContentModel({
    required this.kind,
    required this.layout,
    required this.showsPromptSwitches,
  });

  final _HeroToolbarContentKind kind;
  final _HeroToolbarLayoutSpec layout;
  final bool showsPromptSwitches;

  static _HeroToolbarContentModel resolve({
    required _HeroToolbarExpansion expansion,
    required GenerationSubmissionJob selectedJob,
  }) {
    if (expansion == _HeroToolbarExpansion.moreActions) {
      return const _HeroToolbarContentModel(
        kind: _HeroToolbarContentKind.moreActions,
        layout: _HeroToolbarLayoutSpec.moreActions,
        showsPromptSwitches: false,
      );
    }

    final PromptSelectionSnapshot selection =
        selectedJob.promptSelection ?? PromptSelectionSnapshot.fallback;
    final bool showsPromptSwitches =
        selection.captureMode == manualCaptureMode &&
        promptSwitchesForDefinitions(
          fallbackPromptStyles,
          promptStyle: selection.promptStyle,
          captureMode: manualCaptureMode,
        ).isNotEmpty;

    return _HeroToolbarContentModel(
      kind: showsPromptSwitches
          ? _HeroToolbarContentKind.promptManualSettings
          : _HeroToolbarContentKind.promptAutoSettings,
      layout: showsPromptSwitches
          ? _HeroToolbarLayoutSpec.promptManual
          : _HeroToolbarLayoutSpec.promptAuto,
      showsPromptSwitches: showsPromptSwitches,
    );
  }
}

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
    super.key,
    required this.selectedJob,
    required this.showingOriginal,
    required this.onToggleImage,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onUpdatePromptSelection,
    required this.onMoreActions,
    required this.collapseRequest,
    required this.onExpansionChanged,
  });

  final GenerationSubmissionJob selectedJob;
  final bool showingOriginal;
  final VoidCallback? onToggleImage;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final ValueChanged<PromptSelectionSnapshot>? onUpdatePromptSelection;
  final ValueChanged<_HeroMoreAction>? onMoreActions;
  final int collapseRequest;
  final ValueChanged<bool> onExpansionChanged;

  @override
  State<_HeroToolbar> createState() => _HeroToolbarState();
}

class _HeroToolbarState extends State<_HeroToolbar>
    with SingleTickerProviderStateMixin {
  static const Duration _expandDuration = Duration(milliseconds: 500);
  static const Duration _collapseDuration = Duration(milliseconds: 220);
  static const double _collapsedWidth = 116;
  static const double _promptCollapsedWidth = 152;
  static const double _collapsedHeight = 44;

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
  _HeroToolbarExpansion _expansion = _HeroToolbarExpansion.moreActions;

  @override
  void didUpdateWidget(covariant _HeroToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool selectedJobChanged =
        oldWidget.selectedJob.id != widget.selectedJob.id;
    final bool menuBecameUnavailable =
        _expansion == _HeroToolbarExpansion.moreActions &&
        oldWidget.onMoreActions != null &&
        widget.onMoreActions == null;
    final bool promptSettingsBecameUnavailable =
        _expansion == _HeroToolbarExpansion.promptSettings &&
        oldWidget.onUpdatePromptSelection != null &&
        widget.onUpdatePromptSelection == null;
    final bool shouldCollapse =
        oldWidget.collapseRequest != widget.collapseRequest ||
        selectedJobChanged ||
        menuBecameUnavailable ||
        promptSettingsBecameUnavailable;
    if (shouldCollapse && _expanded) {
      _setExpanded(false, notifyParent: false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setExpanded(
    bool expanded, {
    _HeroToolbarExpansion? expansion,
    bool notifyParent = true,
  }) {
    if (_expanded == expanded &&
        (expansion == null || _expansion == expansion)) {
      return;
    }
    setState(() {
      _expanded = expanded;
      _expansion = expansion ?? _expansion;
    });
    if (notifyParent) {
      widget.onExpansionChanged(expanded);
    }
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
    appDebugLog(
      'GenerationSubmissionModal',
      'hero toolbar action selected action=${item.action.name} enabled=${item.enabled}',
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
        title: widget.selectedJob.hasSubmittedNegativeFeedback
            ? l10n.generationSubmissionActionFeedbackSubmitted
            : l10n.generationSubmissionActionDislikeImage,
        icon: widget.selectedJob.hasSubmittedNegativeFeedback
            ? LucideIcons.check
            : LucideIcons.thumbsDown,
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
        widget.selectedJob.taskId!.isNotEmpty &&
        !widget.selectedJob.hasSubmittedNegativeFeedback;
  }

  @override
  Widget build(BuildContext context) {
    final _HeroToolbarContentModel contentModel =
        _HeroToolbarContentModel.resolve(
          expansion: _expansion,
          selectedJob: widget.selectedJob,
        );
    final Size targetExpandedSize = contentModel.layout.expandedSize;

    return AnimatedBuilder(
      animation: _expandCurve,
      builder: (BuildContext context, Widget? child) {
        final double collapsedWidth = widget.onUpdatePromptSelection == null
            ? _collapsedWidth
            : _promptCollapsedWidth;
        final double height = lerpDouble(
          _collapsedHeight,
          targetExpandedSize.height,
          _expandCurve.value,
        )!;
        final bool showExpandedContent =
            _expanded || _controller.status != AnimationStatus.dismissed;
        return SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedBuilder(
                  animation: _expandCurve,
                  builder: (BuildContext context, Widget? child) {
                    final double value = _expandCurve.value;
                    final double width = lerpDouble(
                      collapsedWidth,
                      targetExpandedSize.width,
                      value,
                    )!;
                    final double innerHeight = lerpDouble(
                      _collapsedHeight,
                      targetExpandedSize.height,
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
                    return SizedBox(
                      key: const ValueKey<String>(
                        'generation-submission-more-hit-region',
                      ),
                      width: width,
                      height: innerHeight,
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
                                        showingOriginal: widget.showingOriginal,
                                        onToggleImage: widget.onToggleImage,
                                        isFavorite: widget.isFavorite,
                                        onToggleFavorite:
                                            widget.onToggleFavorite,
                                        onPromptSettingsPressed:
                                            widget.onUpdatePromptSelection ==
                                                null
                                            ? null
                                            : () => _setExpanded(
                                                true,
                                                expansion: _HeroToolbarExpansion
                                                    .promptSettings,
                                              ),
                                        onMorePressed:
                                            widget.onMoreActions == null
                                            ? null
                                            : () => _setExpanded(
                                                true,
                                                expansion: _HeroToolbarExpansion
                                                    .moreActions,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (showExpandedContent)
                                  IgnorePointer(
                                    ignoring: !_expanded,
                                    child: FadeTransition(
                                      opacity: _menuOpacity,
                                      child:
                                          contentModel.kind ==
                                              _HeroToolbarContentKind
                                                  .moreActions
                                          ? _ExpandedHeroMenu(
                                              animation: _controller,
                                              items: _items,
                                              onSelected:
                                                  (_HeroMoreActionItem item) {
                                                    unawaited(
                                                      _selectAction(item),
                                                    );
                                                  },
                                            )
                                          : _ExpandedPromptSettings(
                                              job: widget.selectedJob,
                                              animation: _controller,
                                              contentModel: contentModel,
                                              onChanged: widget
                                                  .onUpdatePromptSelection!,
                                            ),
                                    ),
                                  ),
                              ],
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
    required this.onPromptSettingsPressed,
    required this.onMorePressed,
  });

  final bool showingOriginal;
  final VoidCallback? onToggleImage;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onPromptSettingsPressed;
  final VoidCallback? onMorePressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (onPromptSettingsPressed != null)
            _HeroToolbarButton(
              key: const ValueKey<String>(
                'generation-submission-prompt-settings',
              ),
              icon: LucideIcons.slidersHorizontal,
              onPressed: onPromptSettingsPressed,
            ),
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

class _ExpandedPromptSettings extends StatefulWidget {
  const _ExpandedPromptSettings({
    required this.job,
    required this.animation,
    required this.contentModel,
    required this.onChanged,
  });

  final GenerationSubmissionJob job;
  final Animation<double> animation;
  final _HeroToolbarContentModel contentModel;
  final ValueChanged<PromptSelectionSnapshot> onChanged;

  @override
  State<_ExpandedPromptSettings> createState() =>
      _ExpandedPromptSettingsState();
}

class _ExpandedPromptSettingsState extends State<_ExpandedPromptSettings> {
  late PromptSelectionSnapshot _selection = _initialSelection();

  @override
  void didUpdateWidget(covariant _ExpandedPromptSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.job.id != widget.job.id ||
        oldWidget.job.promptSelection != widget.job.promptSelection) {
      _selection = _initialSelection();
    }
  }

  PromptSelectionSnapshot _initialSelection() {
    return widget.job.promptSelection ?? PromptSelectionSnapshot.fallback;
  }

  void _selectCaptureMode(String captureModeId) {
    if (_selection.captureMode == captureModeId) {
      return;
    }
    final List<PromptSwitchDefinition> switches = promptSwitchesForDefinitions(
      fallbackPromptStyles,
      promptStyle: _selection.promptStyle,
      captureMode: captureModeId,
    );
    final PromptSelectionSnapshot nextSelection = _selection.copyWith(
      captureMode: captureModeId,
      switches: defaultSwitchValuesFor(switches),
    );
    _updateSelection(nextSelection);
  }

  void _toggleSwitch(String switchId) {
    final Map<String, bool> nextSwitches = <String, bool>{
      ..._selection.switches,
    };
    nextSwitches[switchId] = !(nextSwitches[switchId] ?? false);
    _updateSelection(_selection.copyWith(switches: nextSwitches));
  }

  void _updateSelection(PromptSelectionSnapshot nextSelection) {
    setState(() {
      _selection = nextSelection;
    });
    widget.onChanged(nextSelection);
  }

  @override
  Widget build(BuildContext context) {
    final CameraUiTokens tokens = CameraUiTokens.forTheme(context);
    final List<CameraUiMode> modes = _localizedCaptureModes(context);
    final List<PromptSwitchDefinition> switches = _localizedSwitches(context);
    final _HeroToolbarLayoutSpec layout = widget.contentModel.layout;

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minWidth: layout.expandedSize.width,
        maxWidth: layout.expandedSize.width,
        minHeight: layout.expandedSize.height,
        maxHeight: layout.expandedSize.height,
        child: SizedBox(
          width: layout.expandedSize.width,
          height: layout.expandedSize.height,
          child: Padding(
            padding: layout.contentPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: layout.modeRowHeight,
                  child: _PromptModeSelectorRow(
                    tokens: tokens,
                    modes: modes,
                    selectedModeId: _selection.captureMode,
                    animation: _itemAnimation(0),
                    onModeSelected: _selectCaptureMode,
                  ),
                ),
                if (widget.contentModel.showsPromptSwitches) ...<Widget>[
                  SizedBox(height: layout.contentGap),
                  SizedBox(
                    height: layout.switchesRowHeight,
                    child: _PromptSwitchesRow(
                      tokens: tokens,
                      switches: switches,
                      values: _selection.switches,
                      animation: _itemAnimation(1),
                      onToggle: _toggleSwitch,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Animation<double> _itemAnimation(int index) {
    final double start = (0.42 + index * 0.09).clamp(0.0, 0.86);
    final double end = (start + 0.34).clamp(start, 1.0);
    return CurvedAnimation(
      parent: widget.animation,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.74, 1, curve: Curves.easeOutCubic),
    );
  }

  List<CameraUiMode> _localizedCaptureModes(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return const <String>[defaultCaptureMode, manualCaptureMode]
        .map((String id) {
          return CameraUiMode(
            id: id,
            label: switch (id) {
              manualCaptureMode => l10n.promptCaptureModeManualTitle,
              _ => l10n.promptCaptureModeAutoTitle,
            }.toUpperCase(),
          );
        })
        .toList(growable: false);
  }

  List<PromptSwitchDefinition> _localizedSwitches(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return <PromptSwitchDefinition>[
      for (final PromptSwitchDefinition promptSwitch
          in promptSwitchesForDefinitions(
            fallbackPromptStyles,
            promptStyle: _selection.promptStyle,
            captureMode: manualCaptureMode,
          ))
        PromptSwitchDefinition(
          id: promptSwitch.id,
          title: _localizedSwitchTitle(l10n, promptSwitch),
          defaultValue: promptSwitch.defaultValue,
        ),
    ];
  }

  String _localizedSwitchTitle(
    AppLocalizations l10n,
    PromptSwitchDefinition promptSwitch,
  ) {
    return switch (promptSwitch.id) {
      'recompose' => l10n.promptSwitchRecomposeTitle,
      'beautifyFace' => l10n.promptSwitchBeautifyFaceTitle,
      'cleanFrame' => l10n.promptSwitchCleanFrameTitle,
      'backgroundBlur' => l10n.promptSwitchBackgroundBlurTitle,
      _ => promptSwitch.title,
    };
  }
}

class _PromptModeSelectorRow extends StatelessWidget {
  const _PromptModeSelectorRow({
    required this.tokens,
    required this.modes,
    required this.selectedModeId,
    required this.animation,
    required this.onModeSelected,
  });

  final CameraUiTokens tokens;
  final List<CameraUiMode> modes;
  final String selectedModeId;
  final Animation<double> animation;
  final ValueChanged<String> onModeSelected;

  @override
  Widget build(BuildContext context) {
    const double localModeItemWidth = 60.0;
    final int selectedIndex = modes.indexWhere(
      (CameraUiMode mode) => mode.id == selectedModeId,
    );
    final double indicatorLeft =
        selectedIndex.clamp(0, modes.length - 1) * localModeItemWidth +
        (localModeItemWidth - tokens.modeIndicatorWidth) / 2;

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(animation),
        child: Center(
          child: SizedBox(
            width: modes.length * localModeItemWidth,
            height: 34,
            child: Stack(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (final CameraUiMode mode in modes)
                      GestureDetector(
                        key: ValueKey<String>(
                          'generation-prompt-mode-${mode.id}',
                        ),
                        onTap: () {
                          Feedback.forTap(context);
                          onModeSelected(mode.id);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: localModeItemWidth,
                          height: double.infinity,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: tokens.modeSwitchMotionDuration,
                              curve: tokens.modeSwitchMotionCurve,
                              style: TextStyle(
                                color: mode.id == selectedModeId
                                    ? AppColors.white
                                    : AppColors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: mode.id == selectedModeId
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                letterSpacing: 0,
                              ),
                              child: Text(mode.label),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                AnimatedPositioned(
                  duration: tokens.modeSwitchMotionDuration,
                  curve: tokens.modeSwitchMotionCurve,
                  left: indicatorLeft,
                  bottom: 0,
                  width: tokens.modeIndicatorWidth,
                  height: tokens.modeIndicatorHeight,
                  child: const ColoredBox(color: AppColors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PromptSwitchesRow extends StatelessWidget {
  const _PromptSwitchesRow({
    required this.tokens,
    required this.switches,
    required this.values,
    required this.animation,
    required this.onToggle,
  });

  final CameraUiTokens tokens;
  final List<PromptSwitchDefinition> switches;
  final Map<String, bool> values;
  final Animation<double> animation;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.16),
          end: Offset.zero,
        ).animate(animation),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: <Widget>[
              for (int index = 0; index < switches.length; index += 1)
                Padding(
                  padding: EdgeInsets.only(
                    right: index < switches.length - 1 ? 6.0 : 0.0,
                  ),
                  child: CameraPhotoOptionButton(
                    key: ValueKey<String>(
                      'generation-prompt-option-${switches[index].id}',
                    ),
                    tokens: tokens,
                    label: switches[index].title,
                    icon: _promptOptionIcon(switches[index].id),
                    selected: values[switches[index].id] ?? false,
                    animationIndex: index,
                    onPressed: () => onToggle(switches[index].id),
                  ),
                ),
            ],
          ),
        ),
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

IconData _promptOptionIcon(String id) {
  return switch (id) {
    'recompose' => LucideIcons.wandSparkles,
    'beautifyFace' => LucideIcons.userRoundCheck,
    'cleanFrame' => LucideIcons.sparkles,
    'backgroundBlur' => LucideIcons.aperture,
    _ => LucideIcons.slidersHorizontal,
  };
}
