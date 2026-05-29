import 'dart:async';
import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend_api/data/backend_repositories.dart';
import '../../backend_api/domain/api_failure.dart';
import '../../backend_api/domain/generation_task.dart';
import '../../backend_api/domain/upload_session.dart';
import '../../backend_api/presentation/backend_api_providers.dart';
import '../domain/generation_submission_job.dart';

final capturedFileReaderProvider = Provider<CapturedFileReader>((Ref ref) {
  return const XFileCapturedFileReader();
}, dependencies: const <ProviderOrFamily>[]);

abstract interface class CapturedFileReader {
  Future<Uint8List> readAsBytes(XFile file);
}

class XFileCapturedFileReader implements CapturedFileReader {
  const XFileCapturedFileReader();

  @override
  Future<Uint8List> readAsBytes(XFile file) {
    return file.readAsBytes();
  }
}

final generationSubmissionControllerProvider =
    NotifierProvider<GenerationSubmissionController, GenerationSubmissionState>(
      GenerationSubmissionController.new,
      dependencies: <ProviderOrFamily>[
        capturedFileReaderProvider,
        uploadRepositoryProvider,
        generationTaskRepositoryProvider,
      ],
    );

class GenerationSubmissionController
    extends Notifier<GenerationSubmissionState> {
  static const int _maxJobs = 20;
  int _nextJobId = 0;

  UploadRepository get _uploadRepository => ref.read(uploadRepositoryProvider);

  GenerationTaskRepository get _generationTaskRepository =>
      ref.read(generationTaskRepositoryProvider);

  CapturedFileReader get _capturedFileReader =>
      ref.read(capturedFileReaderProvider);

  @override
  GenerationSubmissionState build() {
    return const GenerationSubmissionState();
  }

  Future<void> submitCapturedFile(XFile file) async {
    final DateTime now = DateTime.now();
    final String jobId = 'local-${now.microsecondsSinceEpoch}-${_nextJobId++}';
    final GenerationSubmissionJob job = GenerationSubmissionJob(
      id: jobId,
      imagePath: file.path,
      status: GenerationSubmissionStatus.queued,
      createdAt: now,
      updatedAt: now,
    );
    _upsertJob(job);

    try {
      _markStatus(jobId, GenerationSubmissionStatus.readingFile);
      final Uint8List bytes = await _capturedFileReader.readAsBytes(file);

      _markStatus(jobId, GenerationSubmissionStatus.creatingUpload);
      final UploadSession uploadSession = await _uploadRepository.createUpload(
        contentType: 'image/jpeg',
        bytes: bytes,
      );
      _updateJob(
        jobId,
        (GenerationSubmissionJob current) => current.copyWith(
          uploadSessionId: uploadSession.uploadSessionId,
          updatedAt: DateTime.now(),
        ),
      );

      _markStatus(jobId, GenerationSubmissionStatus.uploading);
      await _uploadRepository.uploadBytes(
        uploadSession: uploadSession,
        bytes: bytes,
      );

      _markStatus(jobId, GenerationSubmissionStatus.completingUpload);
      await _uploadRepository.completeUpload(uploadSession.uploadSessionId);

      _markStatus(jobId, GenerationSubmissionStatus.creatingTask);
      final CreatedGenerationTask createdTask = await _generationTaskRepository
          .createTask(
            CreateGenerationTaskInput(
              uploadSessionId: uploadSession.uploadSessionId,
              promptStyle: 'realistic',
              captureMode: 'portrait',
              userInput: const <String, Object?>{
                'switches': <String, Object?>{
                  'recompose': false,
                  'beautifyFace': false,
                  'cleanFrame': false,
                },
              },
            ),
          );

      _updateJob(
        jobId,
        (GenerationSubmissionJob current) => current.copyWith(
          status: GenerationSubmissionStatus.submitted,
          taskId: createdTask.taskId,
          updatedAt: DateTime.now(),
          clearError: true,
        ),
      );
    } on BackendApiFailure catch (error) {
      _failJob(
        jobId: jobId,
        errorCode: error.code,
        errorMessage: error.message,
      );
    } on Object catch (error) {
      _failJob(
        jobId: jobId,
        errorCode: 'local_error',
        errorMessage: error.toString(),
      );
    }
  }

  void _markStatus(String jobId, GenerationSubmissionStatus status) {
    _updateJob(
      jobId,
      (GenerationSubmissionJob job) =>
          job.copyWith(status: status, updatedAt: DateTime.now()),
    );
  }

  void _failJob({
    required String jobId,
    required String errorCode,
    required String errorMessage,
  }) {
    _updateJob(
      jobId,
      (GenerationSubmissionJob job) => job.copyWith(
        status: GenerationSubmissionStatus.failed,
        errorCode: errorCode,
        errorMessage: errorMessage,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _upsertJob(GenerationSubmissionJob job) {
    final List<GenerationSubmissionJob> nextJobs = <GenerationSubmissionJob>[
      job,
      ...state.jobs.where((GenerationSubmissionJob current) {
        return current.id != job.id;
      }),
    ];
    state = GenerationSubmissionState(
      jobs: nextJobs.take(_maxJobs).toList(growable: false),
    );
  }

  void _updateJob(
    String jobId,
    GenerationSubmissionJob Function(GenerationSubmissionJob job) update,
  ) {
    state = GenerationSubmissionState(
      jobs: state.jobs
          .map((GenerationSubmissionJob job) {
            return job.id == jobId ? update(job) : job;
          })
          .toList(growable: false),
    );
  }
}
