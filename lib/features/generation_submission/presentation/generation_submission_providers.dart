import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' hide XFile;

import '../../../config/app_config.dart';
import '../../backend_api/presentation/backend_api_providers.dart';
import '../../backend_api/domain/app_input_contract.dart';
import '../../backend_api/domain/prompt_config.dart';
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
      dependencies: <ProviderOrFamily>[appConfigRepositoryProvider],
    );

class PromptSelectionState {
  const PromptSelectionState({
    required this.switches,
    required this.values,
    this.appInputContractId,
    this.isFallback = false,
  });

  factory PromptSelectionState.fallback() {
    return PromptSelectionState(
      switches: fallbackPromptSwitches,
      values: defaultSwitchValuesFor(fallbackPromptSwitches),
      isFallback: true,
    );
  }

  final List<PromptSwitchDefinition> switches;
  final Map<String, bool> values;
  final String? appInputContractId;
  final bool isFallback;

  PromptSelectionSnapshot get snapshot {
    return PromptSelectionSnapshot(
      promptStyle: defaultPromptStyle,
      captureMode: defaultCaptureMode,
      switches: values,
      appInputContractId: appInputContractId,
    );
  }

  PromptSelectionState copyWith({
    List<PromptSwitchDefinition>? switches,
    Map<String, bool>? values,
    String? appInputContractId,
    bool? isFallback,
  }) {
    return PromptSelectionState(
      switches: switches ?? this.switches,
      values: values ?? this.values,
      appInputContractId: appInputContractId ?? this.appInputContractId,
      isFallback: isFallback ?? this.isFallback,
    );
  }
}

class PromptSelectionController extends Notifier<PromptSelectionState> {
  @override
  PromptSelectionState build() {
    unawaited(_loadContract());
    return PromptSelectionState.fallback();
  }

  void toggleSwitch(String switchId) {
    final Map<String, bool> nextValues = <String, bool>{...state.values};
    nextValues[switchId] = !(nextValues[switchId] ?? false);
    state = state.copyWith(values: nextValues);
  }

  Future<void> _loadContract() async {
    try {
      if (!AppConfig.hasWorkerApiConfig) {
        return;
      }
      final AppInputContract contract = await ref
          .read(appConfigRepositoryProvider)
          .fetchAppInputContract();
      final List<PromptSwitchDefinition> switches = promptSwitchesForRoute(
        contract.config,
      );
      final Map<String, bool> defaults = defaultSwitchValuesFor(switches);
      final Map<String, bool> mergedValues = <String, bool>{
        ...defaults,
        for (final MapEntry<String, bool> entry in state.values.entries)
          if (defaults.containsKey(entry.key)) entry.key: entry.value,
      };
      state = PromptSelectionState(
        switches: switches,
        values: mergedValues,
        appInputContractId: contract.id,
      );
    } on Object catch (error) {
      debugPrint('[PromptSelection] app-config load failure error=$error');
      state = PromptSelectionState.fallback();
    }
  }
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
