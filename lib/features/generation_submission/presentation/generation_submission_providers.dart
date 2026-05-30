import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' hide XFile;

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

  String queueCapturedFile(XFile file) {
    return _service.queueCapturedFile(file);
  }

  String queueGalleryFile(XFile file) {
    return _service.queueGalleryFile(file);
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
