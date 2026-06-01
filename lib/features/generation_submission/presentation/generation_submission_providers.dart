import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' hide XFile;

import '../../backend_api/domain/prompt_config.dart';
import '../../backend_api/presentation/backend_api_providers.dart';
import '../application/generation_submission_service.dart';
import '../data/generation_image_processor.dart';
import '../data/generation_submission_adapters.dart';
import '../domain/generation_submission_job.dart';

final galleryImagePickerProvider = Provider<GalleryImagePicker>((Ref ref) {
  return ImagePickerGalleryImagePicker(ImagePicker());
}, dependencies: const <ProviderOrFamily>[]);

final photoLibrarySaverProvider = Provider<PhotoLibrarySaver>((Ref ref) {
  return const GalPhotoLibrarySaver();
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

final generationSubmissionServiceProvider =
    Provider<GenerationSubmissionService>(
      (Ref ref) {
        final GenerationSubmissionService service = GenerationSubmissionService(
          uploadRepository: ref.watch(uploadRepositoryProvider),
          generationTaskRepository: ref.watch(generationTaskRepositoryProvider),
          photoLibrarySaver: ref.watch(photoLibrarySaverProvider),
          imageProcessor: ref.watch(generationImageProcessorProvider),
        );
        ref.onDispose(service.dispose);
        return service;
      },
      dependencies: <ProviderOrFamily>[
        uploadRepositoryProvider,
        generationTaskRepositoryProvider,
        photoLibrarySaverProvider,
        generationImageProcessorProvider,
      ],
    );

final generationSubmissionControllerProvider =
    NotifierProvider<GenerationSubmissionController, GenerationSubmissionState>(
      GenerationSubmissionController.new,
      dependencies: <ProviderOrFamily>[generationSubmissionServiceProvider],
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
  GenerationSubmissionService get _service =>
      ref.read(generationSubmissionServiceProvider);

  @override
  GenerationSubmissionState build() {
    final GenerationSubmissionService service = ref.watch(
      generationSubmissionServiceProvider,
    );

    void syncState() {
      state = service.state;
    }

    service.addListener(syncState);
    ref.onDispose(() => service.removeListener(syncState));
    return service.state;
  }

  String queueCapturedFile(
    XFile file, {
    PromptSelectionSnapshot? promptSelection,
  }) {
    return _service.queueCapturedFile(file, promptSelection: promptSelection);
  }

  String queueGalleryFile(
    XFile file, {
    PromptSelectionSnapshot? promptSelection,
  }) {
    return _service.queueGalleryFile(file, promptSelection: promptSelection);
  }

  Future<void> submitCapturedFile(XFile file) {
    return _service.submitCapturedFile(file);
  }

  Future<void> confirmJob(String jobId) {
    return _service.confirmJob(jobId);
  }

  void cancelJob(String jobId) {
    _service.cancelJob(jobId);
  }

  Future<String?> loadResultUrl(String jobId) {
    return _service.loadResultUrl(jobId);
  }

  Future<void> pollTaskNowForDebug(String jobId) {
    return _service.pollTaskNowForDebug(jobId);
  }
}
