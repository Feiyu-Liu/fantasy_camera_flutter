import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/camera_capture_aspect_ratio.dart';

typedef TemporaryDirectoryProvider = Future<Directory> Function();

class PreparedCapturedPhoto {
  const PreparedCapturedPhoto({required this.file, this.temporaryPathToDelete});

  final XFile file;
  final String? temporaryPathToDelete;

  Future<void> deleteTemporaryFile() async {
    final String? path = temporaryPathToDelete;
    if (path == null || path.isEmpty) {
      return;
    }
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

abstract interface class CapturedPhotoProcessor {
  Future<PreparedCapturedPhoto> prepareCanonicalOriginal({
    required XFile source,
    required CameraCaptureAspectRatio aspectRatio,
  });
}

class MethodChannelCapturedPhotoProcessor implements CapturedPhotoProcessor {
  const MethodChannelCapturedPhotoProcessor({
    this.temporaryDirectoryProvider = getTemporaryDirectory,
  });

  final TemporaryDirectoryProvider temporaryDirectoryProvider;

  static const MethodChannel _channel = MethodChannel(
    'fantasy_camera/captured_photo_processing',
  );

  @override
  Future<PreparedCapturedPhoto> prepareCanonicalOriginal({
    required XFile source,
    required CameraCaptureAspectRatio aspectRatio,
  }) async {
    if (aspectRatio == CameraCaptureAspectRatio.fourThree) {
      return PreparedCapturedPhoto(file: source);
    }

    final Directory temporaryDirectory = await temporaryDirectoryProvider();
    final String sourceExtension = p.extension(source.path);
    final String resolvedExtension = sourceExtension.isEmpty
        ? '.heic'
        : sourceExtension;
    final String outputPath = p.join(
      temporaryDirectory.path,
      'camera-square-${DateTime.now().microsecondsSinceEpoch}'
      '$resolvedExtension',
    );

    final Map<Object?, Object?>? result = await _channel
        .invokeMethod<Map<Object?, Object?>>('cropSquare', <String, Object>{
          'sourcePath': source.path,
          'outputPath': outputPath,
        });
    final String? processedPath = result?['path'] as String?;
    final int? width = result?['width'] as int?;
    final int? height = result?['height'] as int?;
    if (processedPath == null ||
        processedPath.isEmpty ||
        width == null ||
        height == null ||
        width <= 0 ||
        width != height) {
      throw const CapturedPhotoProcessingException(
        'Square crop returned an invalid result.',
      );
    }

    final File processedFile = File(processedPath);
    if (!await processedFile.exists() || await processedFile.length() == 0) {
      throw const CapturedPhotoProcessingException(
        'Square crop did not create a readable file.',
      );
    }
    return PreparedCapturedPhoto(
      file: XFile(processedPath),
      temporaryPathToDelete: processedPath,
    );
  }
}

class CapturedPhotoProcessingException implements Exception {
  const CapturedPhotoProcessingException(this.message);

  final String message;

  @override
  String toString() => 'CapturedPhotoProcessingException: $message';
}
