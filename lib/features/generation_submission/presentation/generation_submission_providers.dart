import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' hide XFile;

import '../../backend_api/domain/prompt_config.dart';
import '../../backend_api/presentation/backend_api_providers.dart';
import '../application/generation_submission_service.dart';
import '../data/generation_record_database.dart';
import '../data/generation_record_repository.dart';
import '../data/generation_image_processor.dart';
import '../data/generation_original_file_store.dart';
import '../data/generation_submission_adapters.dart';
import '../domain/generation_submission_job.dart';
import 'generation_record_providers.dart';

final galleryImagePickerProvider = Provider<GalleryImagePicker>((Ref ref) {
  return PlatformGalleryImagePicker(fallbackImagePicker: ImagePicker());
}, dependencies: const <ProviderOrFamily>[]);

typedef HeroImagePrecache = Future<bool> Function(ImageProvider imageProvider);

final heroImagePrecacheProvider = Provider<HeroImagePrecache>((Ref ref) {
  return defaultHeroImagePrecache;
}, dependencies: const <ProviderOrFamily>[]);

Future<bool> defaultHeroImagePrecache(ImageProvider imageProvider) {
  final Completer<bool> completer = Completer<bool>();
  final ImageStream stream = imageProvider.resolve(const ImageConfiguration());
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo image, bool synchronousCall) {
      stream.removeListener(listener);
      if (!completer.isCompleted) {
        completer.complete(true);
      }
    },
    onError: (Object error, StackTrace? stackTrace) {
      stream.removeListener(listener);
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    },
  );
  stream.addListener(listener);
  return completer.future;
}

final photoLibraryAssetStoreProvider = Provider<PhotoLibraryAssetStore>((
  Ref ref,
) {
  return const MethodChannelPhotoLibraryAssetStore();
}, dependencies: const <ProviderOrFamily>[]);

final resultDownloadDioProvider = Provider<Dio>((Ref ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
    ),
  );
});

final generationImageProcessorProvider = Provider<GenerationImageProcessor>((
  Ref ref,
) {
  return FlutterGenerationImageProcessor(
    dio: ref.watch(resultDownloadDioProvider),
  );
}, dependencies: <ProviderOrFamily>[resultDownloadDioProvider]);

final generationOriginalFileStoreProvider =
    Provider<GenerationOriginalFileStore>(
      (Ref ref) => const ApplicationSupportGenerationOriginalFileStore(),
      dependencies: const <ProviderOrFamily>[],
    );

final generationSubmissionServiceProvider =
    Provider<GenerationSubmissionService>(
      (Ref ref) {
        final GenerationSubmissionService service = GenerationSubmissionService(
          uploadRepository: ref.watch(uploadRepositoryProvider),
          generationTaskRepository: ref.watch(generationTaskRepositoryProvider),
          feedbackRepository: ref.watch(feedbackRepositoryProvider),
          generationRecordRepository: ref.watch(
            generationRecordRepositoryProvider,
          ),
          originalFileStore: ref.watch(generationOriginalFileStoreProvider),
          photoLibraryAssetStore: ref.watch(photoLibraryAssetStoreProvider),
          imageProcessor: ref.watch(generationImageProcessorProvider),
        );
        ref.onDispose(service.dispose);
        return service;
      },
      dependencies: <ProviderOrFamily>[
        uploadRepositoryProvider,
        generationTaskRepositoryProvider,
        feedbackRepositoryProvider,
        generationRecordRepositoryProvider,
        generationOriginalFileStoreProvider,
        photoLibraryAssetStoreProvider,
        generationImageProcessorProvider,
      ],
    );

final generationSubmissionControllerProvider =
    NotifierProvider<GenerationSubmissionController, GenerationSubmissionState>(
      GenerationSubmissionController.new,
      dependencies: <ProviderOrFamily>[
        generationSubmissionServiceProvider,
        generationRecordRepositoryProvider,
        generationRecordsProvider,
        creditBalanceProvider,
      ],
    );

final promptSelectionControllerProvider =
    NotifierProvider<PromptSelectionController, PromptSelectionState>(
      PromptSelectionController.new,
      dependencies: const <ProviderOrFamily>[],
    );

class PromptSelectionState {
  const PromptSelectionState({
    required this.styles,
    required this.selectedPromptStyleId,
    required this.selectedCaptureModeId,
    required this.switches,
    required this.values,
    this.routeSwitchValues = const <String, Map<String, bool>>{},
    this.appInputContractId,
    this.isFallback = false,
  });

  factory PromptSelectionState.fallback() {
    return PromptSelectionState(
      styles: fallbackPromptStyles,
      selectedPromptStyleId: defaultPromptStyle,
      selectedCaptureModeId: defaultCaptureMode,
      switches: fallbackPromptSwitches,
      values: defaultSwitchValuesFor(fallbackPromptSwitches),
      isFallback: true,
    );
  }

  final List<PromptStyleDefinition> styles;
  final String selectedPromptStyleId;
  final String selectedCaptureModeId;
  final List<PromptSwitchDefinition> switches;
  final Map<String, bool> values;
  final Map<String, Map<String, bool>> routeSwitchValues;
  final String? appInputContractId;
  final bool isFallback;

  PromptStyleDefinition? get selectedPromptStyle {
    return promptStyleDefinitionById(styles, selectedPromptStyleId);
  }

  List<PromptCaptureModeDefinition> get captureModes {
    return selectedPromptStyle?.captureModes ??
        const <PromptCaptureModeDefinition>[];
  }

  PromptSelectionSnapshot get snapshot {
    return PromptSelectionSnapshot(
      promptStyle: selectedPromptStyleId,
      captureMode: selectedCaptureModeId,
      switches: values,
      appInputContractId: appInputContractId,
    );
  }

  PromptSelectionState copyWith({
    List<PromptStyleDefinition>? styles,
    String? selectedPromptStyleId,
    String? selectedCaptureModeId,
    List<PromptSwitchDefinition>? switches,
    Map<String, bool>? values,
    Map<String, Map<String, bool>>? routeSwitchValues,
    String? appInputContractId,
    bool? isFallback,
  }) {
    return PromptSelectionState(
      styles: styles ?? this.styles,
      selectedPromptStyleId:
          selectedPromptStyleId ?? this.selectedPromptStyleId,
      selectedCaptureModeId:
          selectedCaptureModeId ?? this.selectedCaptureModeId,
      switches: switches ?? this.switches,
      values: values ?? this.values,
      routeSwitchValues: routeSwitchValues ?? this.routeSwitchValues,
      appInputContractId: appInputContractId ?? this.appInputContractId,
      isFallback: isFallback ?? this.isFallback,
    );
  }
}

class PromptSelectionController extends Notifier<PromptSelectionState> {
  @override
  PromptSelectionState build() {
    final PromptStyleDefinition style = defaultPromptStyleDefinition(
      fallbackPromptStyles,
    );
    final PromptCaptureModeDefinition captureMode =
        defaultPromptCaptureModeDefinition(style);
    return _stateForRoute(
      styles: fallbackPromptStyles,
      promptStyleId: style.id,
      captureModeId: captureMode.id,
      routeSwitchValues: const <String, Map<String, bool>>{},
      appInputContractId: null,
      isFallback: true,
    );
  }

  void toggleSwitch(String switchId) {
    final Map<String, bool> nextValues = <String, bool>{...state.values};
    nextValues[switchId] = !(nextValues[switchId] ?? false);
    state = state.copyWith(
      values: nextValues,
      routeSwitchValues: _cacheValuesForRoute(
        state.routeSwitchValues,
        state.selectedPromptStyleId,
        state.selectedCaptureModeId,
        nextValues,
      ),
    );
  }

  void selectPromptStyle(String promptStyleId) {
    final PromptStyleDefinition? style = promptStyleDefinitionById(
      state.styles,
      promptStyleId,
    );
    if (style == null || style.id == state.selectedPromptStyleId) {
      return;
    }
    final PromptCaptureModeDefinition captureMode =
        defaultPromptCaptureModeDefinition(style);
    _selectRoute(style.id, captureMode.id);
  }

  void selectCaptureMode(String captureModeId) {
    final PromptStyleDefinition? style = state.selectedPromptStyle;
    if (style == null) {
      return;
    }
    final PromptCaptureModeDefinition? captureMode =
        promptCaptureModeDefinitionById(style, captureModeId);
    if (captureMode == null || captureMode.id == state.selectedCaptureModeId) {
      return;
    }
    _selectRoute(style.id, captureMode.id);
  }

  void _selectRoute(String promptStyleId, String captureModeId) {
    final Map<String, Map<String, bool>> cache = _cacheValuesForRoute(
      state.routeSwitchValues,
      state.selectedPromptStyleId,
      state.selectedCaptureModeId,
      state.values,
    );
    state = _stateForRoute(
      styles: state.styles,
      promptStyleId: promptStyleId,
      captureModeId: captureModeId,
      routeSwitchValues: cache,
      appInputContractId: state.appInputContractId,
      isFallback: state.isFallback,
    );
  }

  PromptSelectionState _stateForRoute({
    required List<PromptStyleDefinition> styles,
    required String promptStyleId,
    required String captureModeId,
    required Map<String, Map<String, bool>> routeSwitchValues,
    required String? appInputContractId,
    required bool isFallback,
  }) {
    final List<PromptSwitchDefinition> switches = promptSwitchesForDefinitions(
      styles,
      promptStyle: promptStyleId,
      captureMode: captureModeId,
    );
    final Map<String, bool> defaults = defaultSwitchValuesFor(switches);
    final Map<String, bool> cached =
        routeSwitchValues[_promptRouteKey(promptStyleId, captureModeId)] ??
        const <String, bool>{};
    final Map<String, bool> values = <String, bool>{
      ...defaults,
      for (final MapEntry<String, bool> entry in cached.entries)
        if (defaults.containsKey(entry.key)) entry.key: entry.value,
    };
    return PromptSelectionState(
      styles: styles,
      selectedPromptStyleId: promptStyleId,
      selectedCaptureModeId: captureModeId,
      switches: switches,
      values: values,
      routeSwitchValues: _cacheValuesForRoute(
        routeSwitchValues,
        promptStyleId,
        captureModeId,
        values,
      ),
      appInputContractId: appInputContractId,
      isFallback: isFallback,
    );
  }
}

String _promptRouteKey(String promptStyleId, String captureModeId) {
  return '$promptStyleId/$captureModeId';
}

Map<String, Map<String, bool>> _cacheValuesForRoute(
  Map<String, Map<String, bool>> routeSwitchValues,
  String promptStyleId,
  String captureModeId,
  Map<String, bool> values,
) {
  return <String, Map<String, bool>>{
    ...routeSwitchValues,
    _promptRouteKey(promptStyleId, captureModeId): <String, bool>{...values},
  };
}

class GenerationSubmissionController
    extends Notifier<GenerationSubmissionState> {
  GenerationSubmissionService? _submissionService;
  GenerationRecordRepository? _recordRepository;
  final Set<String> _observedCreatedTaskJobIds = <String>{};
  final Set<String> _deletedJobIds = <String>{};
  GenerationSubmissionState? _lastPublishedState;

  GenerationSubmissionService get _service {
    final GenerationSubmissionService? service = _submissionService;
    if (service != null) {
      return service;
    }
    final GenerationSubmissionService initialized = ref.read(
      generationSubmissionServiceProvider,
    );
    _submissionService = initialized;
    return initialized;
  }

  GenerationRecordRepository get _repository {
    final GenerationRecordRepository? repository = _recordRepository;
    if (repository != null) {
      return repository;
    }
    final GenerationRecordRepository initialized = ref.read(
      generationRecordRepositoryProvider,
    );
    _recordRepository = initialized;
    return initialized;
  }

  @override
  GenerationSubmissionState build() {
    _recordRepository = ref.watch(generationRecordRepositoryProvider);
    final AsyncValue<List<GenerationRecord>> records = ref.watch(
      generationRecordsProvider,
    );
    return records.when(
      data: (List<GenerationRecord> value) {
        unawaited(_publishRecords(value));
        return _lastPublishedState ?? const GenerationSubmissionState();
      },
      loading: () {
        const GenerationSubmissionState nextState = GenerationSubmissionState();
        _lastPublishedState = nextState;
        return nextState;
      },
      error: (_, _) {
        const GenerationSubmissionState nextState = GenerationSubmissionState();
        _lastPublishedState = nextState;
        return nextState;
      },
    );
  }

  Future<String?> queueCapturedFile(
    XFile file, {
    PromptSelectionSnapshot? promptSelection,
  }) async {
    final String? recordId = await _service.queueCapturedFile(
      file,
      promptSelection: promptSelection,
    );
    if (recordId != null) {
      _deletedJobIds.remove(recordId);
    }
    await _refreshFromRepository();
    return recordId;
  }

  Future<String> queueGalleryFile(
    XFile file, {
    String? originalAssetId,
    PromptSelectionSnapshot? promptSelection,
  }) async {
    final String recordId = await _service.queueGalleryFile(
      file,
      originalAssetId: originalAssetId,
      promptSelection: promptSelection,
    );
    _deletedJobIds.remove(recordId);
    await _refreshFromRepository();
    return recordId;
  }

  Future<void> submitCapturedFile(XFile file) async {
    await _service.submitCapturedFile(file);
    await _refreshFromRepository();
  }

  Future<void> confirmJob(String jobId) async {
    await _service.confirmJob(jobId);
    await _refreshFromRepository();
  }

  Future<void> cancelJob(String jobId) async {
    await _service.cancelJob(jobId);
    _deletedJobIds.add(jobId);
    await _refreshFromRepository();
  }

  Future<String?> loadResultUrl(String jobId) async {
    final String? result = await _service.loadResultUrl(jobId);
    await _refreshFromRepository();
    return result;
  }

  Future<void> pollTaskNowForDebug(String jobId) async {
    await _service.pollTaskNowForDebug(jobId);
    await _refreshFromRepository();
  }

  Future<void> resumeActiveRecords() async {
    await _service.resumeActiveRecords();
    await _refreshFromRepository();
  }

  Future<void> retryJob(String jobId) async {
    _deletedJobIds.remove(jobId);
    await _service.retryJob(jobId);
    await _refreshFromRepository();
  }

  Future<void> toggleResultFavorite(String jobId) async {
    await _service.toggleResultFavorite(jobId);
    await _refreshFromRepository();
  }

  Future<void> openPhotoLibrary(String jobId) async {
    await _service.openPhotoLibrary(jobId);
    await _refreshFromRepository();
  }

  Future<void> saveOriginalToPhotoLibrary(String jobId) async {
    await _service.saveOriginalToPhotoLibrary(jobId);
    await _refreshFromRepository();
  }

  Future<void> submitNegativeFeedback(String jobId) async {
    await _service.submitNegativeFeedback(jobId);
    await _refreshFromRepository();
  }

  Future<void> removeJob(String jobId) async {
    await _service.removeRecord(jobId);
    _deletedJobIds.add(jobId);
    await _refreshFromRepository();
  }

  void _refreshCreditBalanceAfterTaskCreation(
    GenerationSubmissionState nextState,
  ) {
    for (final GenerationSubmissionJob job in nextState.jobs) {
      if (job.taskId == null || _observedCreatedTaskJobIds.contains(job.id)) {
        continue;
      }
      _observedCreatedTaskJobIds.add(job.id);
      ref.invalidate(creditBalanceProvider);
    }
  }

  Future<void> _refreshFromRepository() async {
    final List<GenerationRecord> records = await _repository.listRecords();
    final GenerationSubmissionState nextState = await _service.stateForRecords(
      records,
    );
    final GenerationSubmissionState filteredNextState = _withoutDeletedJobs(
      nextState,
    );
    _refreshCreditBalanceAfterTaskCreation(filteredNextState);
    _lastPublishedState = filteredNextState;
    state = filteredNextState;
  }

  Future<void> _publishRecords(List<GenerationRecord> records) async {
    final GenerationSubmissionState nextState = _mergedWithCurrentState(
      await _service.stateForRecords(records),
    );
    _refreshCreditBalanceAfterTaskCreation(nextState);
    _lastPublishedState = nextState;
    state = nextState;
  }

  GenerationSubmissionState _mergedWithCurrentState(
    GenerationSubmissionState incomingState,
  ) {
    final GenerationSubmissionState filteredIncomingState = _withoutDeletedJobs(
      incomingState,
    );
    final GenerationSubmissionState? currentState = _lastPublishedState;
    if (currentState == null ||
        currentState.jobs.isEmpty ||
        filteredIncomingState.jobs.isEmpty) {
      return filteredIncomingState;
    }
    final Map<String, GenerationSubmissionJob> currentJobs =
        <String, GenerationSubmissionJob>{
          for (final GenerationSubmissionJob job in currentState.jobs)
            job.id: job,
        };
    return GenerationSubmissionState(
      jobs: filteredIncomingState.jobs
          .map((GenerationSubmissionJob incomingJob) {
            final GenerationSubmissionJob? currentJob =
                currentJobs[incomingJob.id];
            if (currentJob == null) {
              return incomingJob;
            }
            return _statusRank(currentJob.status) >
                        _statusRank(incomingJob.status) &&
                    currentJob.updatedAt.isAfter(incomingJob.updatedAt)
                ? currentJob
                : incomingJob;
          })
          .toList(growable: false),
    );
  }

  GenerationSubmissionState _withoutDeletedJobs(
    GenerationSubmissionState incomingState,
  ) {
    if (_deletedJobIds.isEmpty) {
      return incomingState;
    }
    return GenerationSubmissionState(
      jobs: incomingState.jobs
          .where(
            (GenerationSubmissionJob job) => !_deletedJobIds.contains(job.id),
          )
          .toList(growable: false),
    );
  }
}

int _statusRank(GenerationSubmissionStatus status) {
  return switch (status) {
    GenerationSubmissionStatus.awaitingConfirmation => 0,
    GenerationSubmissionStatus.queued => 1,
    GenerationSubmissionStatus.preparingUploadImage => 2,
    GenerationSubmissionStatus.readingFile => 3,
    GenerationSubmissionStatus.creatingUpload => 4,
    GenerationSubmissionStatus.uploading => 5,
    GenerationSubmissionStatus.completingUpload => 6,
    GenerationSubmissionStatus.creatingTask => 7,
    GenerationSubmissionStatus.submitted => 8,
    GenerationSubmissionStatus.pollingTask => 9,
    GenerationSubmissionStatus.completed => 10,
    GenerationSubmissionStatus.processingResultImage => 11,
    GenerationSubmissionStatus.resultSaved => 12,
    GenerationSubmissionStatus.resultProcessingFailed => 12,
    GenerationSubmissionStatus.failed => 12,
  };
}
