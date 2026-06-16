import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';

import '../../backend_api/data/checksum.dart';
import '../../backend_api/data/backend_repositories.dart';
import '../../backend_api/domain/json_value.dart';
import '../../backend_api/domain/upload_session.dart';
import '../data/generation_image_processor.dart';

class BackgroundUploadSpikeResult {
  const BackgroundUploadSpikeResult({
    required this.uploadSessionId,
    required this.sourceImageObjectId,
    required this.downloaderTaskId,
    required this.status,
    required this.responseStatusCode,
    required this.completeResult,
  });

  final String uploadSessionId;
  final String sourceImageObjectId;
  final String downloaderTaskId;
  final TaskStatus status;
  final int? responseStatusCode;
  final JsonObject completeResult;
}

class BackgroundUploadSpikeService {
  const BackgroundUploadSpikeService({
    required UploadRepository uploadRepository,
    required GenerationImageProcessor imageProcessor,
  }) : _uploadRepository = uploadRepository,
       _imageProcessor = imageProcessor;

  static const String _group = 'r2-upload-spike';

  final UploadRepository _uploadRepository;
  final GenerationImageProcessor _imageProcessor;

  Future<BackgroundUploadSpikeResult> run({required String filePath}) async {
    final int sourceBytes = await File(filePath).length();
    final String spikeId =
        'r2-upload-spike-${DateTime.now().microsecondsSinceEpoch}';
    _log('start path=$filePath bytes=$sourceBytes');

    final PreparedUploadImage preparedUploadImage = await _imageProcessor
        .prepareUploadImage(jobId: spikeId, sourcePath: filePath);
    final String uploadPath = preparedUploadImage.path;
    final Uint8List bytes = preparedUploadImage.bytes;
    _log(
      'prepared jpeg path=$uploadPath bytes=${bytes.length} exifKeys=${preparedUploadImage.sourceExif.length}',
    );

    final UploadSession uploadSession = await _uploadRepository.createUpload(
      contentType: 'image/jpeg',
      bytes: bytes,
    );
    _log(
      'created uploadSession=${uploadSession.uploadSessionId} source=${uploadSession.sourceImageObjectId} headers=${uploadSession.requiredHeaders.keys.join(',')} checksum=${sha256Base64(bytes)}',
    );

    final (BaseDirectory baseDirectory, String directory, String filename) =
        await Task.split(filePath: uploadPath);
    final UploadTask task = UploadTask(
      url: uploadSession.url,
      filename: filename,
      directory: directory,
      baseDirectory: baseDirectory,
      headers: uploadSession.requiredHeaders,
      httpRequestMethod: 'PUT',
      post: 'binary',
      mimeType: 'image/jpeg',
      group: _group,
      updates: Updates.statusAndProgress,
      retries: 0,
      displayName: 'R2 Upload Spike',
      metaData: uploadSession.uploadSessionId,
    );
    _log(
      'enqueue task=${task.taskId} method=${task.httpRequestMethod} post=${task.post} base=${task.baseDirectory.name} directory=${task.directory} filename=${task.filename}',
    );

    final TaskStatusUpdate result = await _enqueueAndAwait(task);
    _log(
      'terminal task=${task.taskId} status=${result.status.name} http=${result.responseStatusCode ?? 'none'} exception=${result.exception ?? 'none'} body=${result.responseBody ?? 'none'}',
    );

    if (result.status != TaskStatus.complete) {
      throw StateError(
        'background_downloader upload failed: status=${result.status.name} http=${result.responseStatusCode ?? 'none'} exception=${result.exception ?? 'none'} body=${result.responseBody ?? 'none'}',
      );
    }

    final JsonObject completeResult = await _uploadRepository.completeUpload(
      uploadSession.uploadSessionId,
    );
    _log(
      'complete uploadSession=${uploadSession.uploadSessionId} result=$completeResult',
    );

    return BackgroundUploadSpikeResult(
      uploadSessionId: uploadSession.uploadSessionId,
      sourceImageObjectId: uploadSession.sourceImageObjectId,
      downloaderTaskId: task.taskId,
      status: result.status,
      responseStatusCode: result.responseStatusCode,
      completeResult: completeResult,
    );
  }

  Future<TaskStatusUpdate> _enqueueAndAwait(UploadTask task) async {
    final Completer<TaskStatusUpdate> completer = Completer<TaskStatusUpdate>();
    final FileDownloader downloader = FileDownloader();

    downloader.registerCallbacks(
      group: _group,
      taskStatusCallback: (TaskStatusUpdate update) {
        if (update.task.taskId != task.taskId) {
          return;
        }
        _log(
          'status task=${task.taskId} status=${update.status.name} http=${update.responseStatusCode ?? 'none'} exception=${update.exception ?? 'none'}',
        );
        if (update.status.isFinalState && !completer.isCompleted) {
          completer.complete(update);
        }
      },
      taskProgressCallback: (TaskProgressUpdate update) {
        if (update.task.taskId != task.taskId) {
          return;
        }
        _log(
          'progress task=${task.taskId} progress=${update.progress.toStringAsFixed(4)} expected=${update.expectedFileSize} speed=${update.networkSpeed.toStringAsFixed(4)}',
        );
      },
    );

    try {
      await downloader.start(
        doRescheduleKilledTasks: false,
        autoCleanDatabase: false,
      );
      final bool enqueued = await downloader.enqueue(task);
      _log('enqueue result task=${task.taskId} enqueued=$enqueued');
      if (!enqueued) {
        throw StateError('background_downloader enqueue returned false.');
      }
      return await completer.future.timeout(
        const Duration(minutes: 15),
        onTimeout: () {
          throw TimeoutException(
            'background_downloader upload did not reach a terminal state.',
            const Duration(minutes: 15),
          );
        },
      );
    } finally {
      downloader.unregisterCallbacks(group: _group);
    }
  }
}

void _log(String message) {
  debugPrint('[BackgroundUploadSpike] $message');
}
