import 'dart:async';

import 'package:background_downloader/background_downloader.dart';

import '../../../shared/core/app_logger.dart';
import '../../backend_api/domain/upload_session.dart';

class BackgroundR2UploadResult {
  const BackgroundR2UploadResult({
    required this.downloaderTaskId,
    required this.status,
    this.responseStatusCode,
    this.responseBody,
    this.exception,
  });

  final String downloaderTaskId;
  final TaskStatus status;
  final int? responseStatusCode;
  final String? responseBody;
  final Object? exception;
}

abstract interface class BackgroundR2UploadService {
  Future<BackgroundR2UploadResult> uploadFile({
    required UploadSession uploadSession,
    required String filePath,
    required String contentType,
    required String displayName,
  });

  void dispose();
}

class ForegroundFallbackR2UploadService implements BackgroundR2UploadService {
  const ForegroundFallbackR2UploadService();

  @override
  Future<BackgroundR2UploadResult> uploadFile({
    required UploadSession uploadSession,
    required String filePath,
    required String contentType,
    required String displayName,
  }) async {
    return const BackgroundR2UploadResult(
      downloaderTaskId: 'foreground-fallback',
      status: TaskStatus.complete,
      responseStatusCode: 200,
    );
  }

  @override
  void dispose() {}
}

class BackgroundDownloaderR2UploadService implements BackgroundR2UploadService {
  BackgroundDownloaderR2UploadService({FileDownloader? downloader})
    : _downloader = downloader ?? FileDownloader();

  static const String group = 'r2-generation-upload';

  final FileDownloader _downloader;
  bool _disposed = false;

  static Future<void> initializeDownloader({FileDownloader? downloader}) async {
    final FileDownloader instance = downloader ?? FileDownloader();
    instance.registerCallbacks(
      group: group,
      taskStatusCallback: (TaskStatusUpdate update) {
        _debugLog(
          'startup status task=${update.task.taskId} status=${update.status.name} http=${update.responseStatusCode ?? 'none'}',
        );
      },
      taskProgressCallback: (TaskProgressUpdate update) {
        _debugLog(
          'startup progress task=${update.task.taskId} progress=${update.progress.toStringAsFixed(4)}',
        );
      },
    );
    await instance.start(autoCleanDatabase: false);
  }

  @override
  Future<BackgroundR2UploadResult> uploadFile({
    required UploadSession uploadSession,
    required String filePath,
    required String contentType,
    required String displayName,
  }) async {
    if (_disposed) {
      throw StateError('BackgroundR2UploadService has been disposed.');
    }
    final (BaseDirectory baseDirectory, String directory, String filename) =
        await Task.split(filePath: filePath);
    final UploadTask task = UploadTask(
      url: uploadSession.url,
      filename: filename,
      directory: directory,
      baseDirectory: baseDirectory,
      headers: uploadSession.requiredHeaders,
      httpRequestMethod: 'PUT',
      post: 'binary',
      mimeType: contentType,
      group: group,
      updates: Updates.statusAndProgress,
      retries: 2,
      displayName: displayName,
      metaData: uploadSession.uploadSessionId,
    );
    final TaskStatusUpdate update = await _uploadAndAwait(task);
    _handleStatusUpdate(update);
    return BackgroundR2UploadResult(
      downloaderTaskId: task.taskId,
      status: update.status,
      responseStatusCode: update.responseStatusCode,
      responseBody: update.responseBody,
      exception: update.exception,
    );
  }

  Future<TaskStatusUpdate> _uploadAndAwait(UploadTask task) {
    _debugLog('enqueue task=${task.taskId}');
    return _downloader
        .upload(
          task,
          onStatus: (TaskStatus status) {
            _debugLog('task status task=${task.taskId} status=${status.name}');
          },
          onProgress: (double progress) {
            _debugLog(
              'progress task=${task.taskId} progress=${progress.toStringAsFixed(4)}',
            );
          },
        )
        .timeout(
          const Duration(minutes: 15),
          onTimeout: () {
            throw TimeoutException(
              'background_downloader upload did not reach a terminal state.',
              const Duration(minutes: 15),
            );
          },
        );
  }

  void _handleStatusUpdate(TaskStatusUpdate update) {
    _debugLog(
      'status task=${update.task.taskId} status=${update.status.name} http=${update.responseStatusCode ?? 'none'} exception=${update.exception ?? 'none'}',
    );
  }

  @override
  void dispose() {
    _disposed = true;
  }
}

void _debugLog(String message) {
  appDebugLog('BackgroundR2Upload', message);
}
