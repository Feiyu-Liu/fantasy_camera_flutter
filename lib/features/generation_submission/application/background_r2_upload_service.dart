import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';

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
    : _downloader = downloader ?? FileDownloader() {
    _registerCallbacks();
  }

  static const String group = 'r2-generation-upload';

  final FileDownloader _downloader;
  final Map<String, Completer<TaskStatusUpdate>> _pending =
      <String, Completer<TaskStatusUpdate>>{};
  bool _callbacksRegistered = false;
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
    _registerCallbacks();
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
    final TaskStatusUpdate update = await _enqueueAndAwait(task);
    return BackgroundR2UploadResult(
      downloaderTaskId: task.taskId,
      status: update.status,
      responseStatusCode: update.responseStatusCode,
      responseBody: update.responseBody,
      exception: update.exception,
    );
  }

  Future<TaskStatusUpdate> _enqueueAndAwait(UploadTask task) async {
    final Completer<TaskStatusUpdate> completer = Completer<TaskStatusUpdate>();
    _pending[task.taskId] = completer;
    try {
      final bool enqueued = await _downloader.enqueue(task);
      _debugLog('enqueue task=${task.taskId} enqueued=$enqueued');
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
      _pending.remove(task.taskId);
    }
  }

  void _registerCallbacks() {
    if (_callbacksRegistered) {
      return;
    }
    _downloader.registerCallbacks(
      group: group,
      taskStatusCallback: _handleStatusUpdate,
      taskProgressCallback: _handleProgressUpdate,
    );
    _callbacksRegistered = true;
  }

  void _handleStatusUpdate(TaskStatusUpdate update) {
    _debugLog(
      'status task=${update.task.taskId} status=${update.status.name} http=${update.responseStatusCode ?? 'none'} exception=${update.exception ?? 'none'}',
    );
    final Completer<TaskStatusUpdate>? completer = _pending[update.task.taskId];
    if (update.status.isFinalState &&
        completer != null &&
        !completer.isCompleted) {
      completer.complete(update);
    }
  }

  void _handleProgressUpdate(TaskProgressUpdate update) {
    _debugLog(
      'progress task=${update.task.taskId} progress=${update.progress.toStringAsFixed(4)} expected=${update.expectedFileSize} speed=${update.networkSpeed.toStringAsFixed(4)}',
    );
  }

  @override
  void dispose() {
    _disposed = true;
    for (final Completer<TaskStatusUpdate> completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Background upload disposed.'));
      }
    }
    _pending.clear();
    if (_callbacksRegistered) {
      _downloader.unregisterCallbacks(group: group);
      _callbacksRegistered = false;
    }
  }
}

void _debugLog(String message) {
  debugPrint('[BackgroundR2Upload] $message');
}
