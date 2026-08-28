import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:native_exif/native_exif.dart';

import '../../../config/app_config.dart';
import '../../../shared/core/app_logger.dart';
import 'generation_image_artifact_store.dart';

class PreparedUploadImage {
  const PreparedUploadImage({
    required this.path,
    required this.sizeBytes,
    required this.checksumSha256,
    required this.sourceExif,
  });

  final String path;
  final int sizeBytes;
  final String checksumSha256;
  final Map<String, Object> sourceExif;
}

class ProcessedResultImage {
  const ProcessedResultImage({required this.path, required this.sizeBytes});

  final String path;
  final int sizeBytes;
}

abstract interface class GenerationImageProcessor {
  Future<PreparedUploadImage> prepareUploadImage({
    required String jobId,
    required String sourcePath,
  });

  Future<ProcessedResultImage> processResultImage({
    required String jobId,
    required String resultUrl,
    required Map<String, Object> sourceExif,
  });
}

class FlutterGenerationImageProcessor implements GenerationImageProcessor {
  const FlutterGenerationImageProcessor({
    required Dio dio,
    GenerationImageArtifactStore artifactStore =
        const ApplicationCacheGenerationImageArtifactStore(),
  }) : _dio = dio,
       _artifactStore = artifactStore;

  final Dio _dio;
  final GenerationImageArtifactStore _artifactStore;

  @override
  Future<PreparedUploadImage> prepareUploadImage({
    required String jobId,
    required String sourcePath,
  }) async {
    final File sourceFile = File(sourcePath);
    final int sourceBytes = await sourceFile.length();
    _debugLog(
      'prepare upload start job=$jobId path=$sourcePath bytes=$sourceBytes',
    );

    final Map<String, Object> sourceExif = await _measure(
      label: 'read exif',
      jobId: jobId,
      action: () => _readExif(sourcePath),
    );
    final _TargetImageSize targetSize = _targetUploadSizeFromExif(sourceExif);
    _debugLog(
      'upload target size job=$jobId width=${targetSize.width} height=${targetSize.height} sourceWidth=${targetSize.sourceWidth ?? 'unknown'} sourceHeight=${targetSize.sourceHeight ?? 'unknown'}',
    );

    final GenerationUploadArtifactTarget target = await _artifactStore
        .resolveUploadTarget(
          recordId: jobId,
          sourcePath: sourcePath,
          maxSide: AppConfig.generationUploadImageMaxSide,
          quality: AppConfig.generationUploadJpegQuality,
          keepExif: AppConfig.generationUploadKeepExif,
        );
    final String targetPath = target.path;
    if (target.isReusable) {
      _debugLog('reuse upload artifact job=$jobId path=$targetPath');
    } else {
      final String partialPath = await _artifactStore.createPartialPath(
        targetPath,
      );
      try {
        final XFile compressedFile = await _measure(
          label: 'clean jpeg',
          jobId: jobId,
          action: () async {
            final XFile? file = await FlutterImageCompress.compressAndGetFile(
              sourcePath,
              partialPath,
              minWidth: targetSize.width,
              minHeight: targetSize.height,
              quality: AppConfig.generationUploadJpegQuality,
              format: CompressFormat.jpeg,
              keepExif: AppConfig.generationUploadKeepExif,
            );
            if (file == null) {
              throw StateError('Image compression returned null.');
            }
            return file;
          },
        );
        if (await _artifactStore.validJpegSize(compressedFile.path) == null) {
          throw StateError('Image compression did not create a valid JPEG.');
        }
        await _artifactStore.commitPartial(
          partialPath: compressedFile.path,
          finalPath: targetPath,
        );
      } finally {
        await _artifactStore.deleteArtifact(partialPath);
      }
    }

    final int sizeBytes =
        await _artifactStore.validJpegSize(targetPath) ??
        (throw StateError('Upload artifact is missing or invalid.'));
    final String checksumSha256 = await _measure(
      label: 'hash upload jpeg',
      jobId: jobId,
      action: () => Isolate.run(() => _sha256FileBase64(targetPath)),
    );
    _debugLog(
      'prepare upload success job=$jobId output=$targetPath bytes=$sizeBytes exifKeys=${sourceExif.length}',
    );

    return PreparedUploadImage(
      path: targetPath,
      sizeBytes: sizeBytes,
      checksumSha256: checksumSha256,
      sourceExif: sourceExif,
    );
  }

  @override
  Future<ProcessedResultImage> processResultImage({
    required String jobId,
    required String resultUrl,
    required Map<String, Object> sourceExif,
  }) async {
    _debugLog('process result start job=$jobId url=$resultUrl');
    final String downloadPath = await _artifactStore.resultDownloadPath(jobId);
    final String downloadPartialPath = await _artifactStore.createPartialPath(
      downloadPath,
    );
    final String heicPath = await _artifactStore.resultArtifactPath(
      jobId,
      suffix: 'heic',
    );
    final String heicPartialPath = await _artifactStore.createPartialPath(
      heicPath,
    );
    XFile resultFile;
    try {
      await _measure(
        label: 'download result',
        jobId: jobId,
        action: () => _dio.download(resultUrl, downloadPartialPath),
      );

      final XFile? heicFile = await _measure(
        label: 'convert result heif',
        jobId: jobId,
        action: () => FlutterImageCompress.compressAndGetFile(
          downloadPartialPath,
          heicPartialPath,
          quality: AppConfig.generationResultHeifQuality,
          format: CompressFormat.heic,
          keepExif: false,
        ),
      );
      if (heicFile != null &&
          await _artifactStore.validFileSize(heicFile.path) != null) {
        await _artifactStore.commitPartial(
          partialPath: heicFile.path,
          finalPath: heicPath,
        );
        resultFile = XFile(heicPath);
      } else {
        resultFile = await _createFallbackJpegResult(
          jobId: jobId,
          downloadedPath: downloadPartialPath,
          missingHeicPath: heicPartialPath,
        );
      }
    } finally {
      await _artifactStore.deleteArtifact(downloadPartialPath);
      await _artifactStore.deleteArtifact(heicPartialPath);
    }
    final int convertedBytes =
        await _artifactStore.validFileSize(resultFile.path) ??
        (throw StateError('Processed result artifact is missing or empty.'));
    _debugLog(
      'result image file ready job=$jobId path=${resultFile.path} bytes=$convertedBytes',
    );

    final Map<String, Object> resultExif = sanitizeResultExifForWrite(
      sourceExif,
    );
    final Object? removedOrientation = _firstExifValue(
      sourceExif,
      _resultExifOrientationKeys,
    );
    _debugLog(
      'result exif sanitized job=$jobId sourceKeys=${sourceExif.length} resultKeys=${resultExif.length} removedOrientation=$removedOrientation',
    );

    final bool exifWritten = await _measure(
      label: 'write result exif',
      jobId: jobId,
      action: () => _tryWriteExif(resultFile.path, resultExif),
    );
    final int resultBytes =
        await _artifactStore.validFileSize(resultFile.path) ??
        (throw StateError('Processed result artifact became unavailable.'));

    _debugLog(
      'process result success job=$jobId output=${resultFile.path} bytes=$resultBytes sourceExifKeys=${sourceExif.length} resultExifKeys=${resultExif.length} exifWritten=$exifWritten',
    );
    return ProcessedResultImage(path: resultFile.path, sizeBytes: resultBytes);
  }

  Future<XFile> _createFallbackJpegResult({
    required String jobId,
    required String downloadedPath,
    required String missingHeicPath,
  }) async {
    _debugLog(
      'convert result heif output missing job=$jobId path=$missingHeicPath fallback=jpeg',
    );
    final String fallbackPath = await _artifactStore.resultArtifactPath(
      jobId,
      suffix: 'jpg',
    );
    final String fallbackPartialPath = await _artifactStore.createPartialPath(
      fallbackPath,
    );
    final XFile? fallbackFile = await FlutterImageCompress.compressAndGetFile(
      downloadedPath,
      fallbackPartialPath,
      quality: AppConfig.generationUploadJpegQuality,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    final XFile? existingFallback =
        fallbackFile != null &&
            await _artifactStore.validJpegSize(fallbackFile.path) != null
        ? fallbackFile
        : null;
    if (existingFallback != null) {
      await _artifactStore.commitPartial(
        partialPath: existingFallback.path,
        finalPath: fallbackPath,
      );
      _debugLog('fallback jpeg result success job=$jobId path=$fallbackPath');
      return XFile(fallbackPath);
    }

    await _artifactStore.deleteArtifact(fallbackPartialPath);
    final File copiedFile = await File(
      downloadedPath,
    ).copy(fallbackPartialPath);
    if (await _artifactStore.validFileSize(copiedFile.path) != null) {
      await _artifactStore.commitPartial(
        partialPath: copiedFile.path,
        finalPath: fallbackPath,
      );
      _debugLog('fallback jpeg copy success job=$jobId path=$fallbackPath');
      return XFile(fallbackPath);
    }

    throw StateError(
      'HEIC conversion did not create $missingHeicPath and JPEG fallback failed.',
    );
  }

  Future<Map<String, Object>> _readExif(String path) async {
    final Exif exif = await Exif.fromPath(path);
    try {
      return await exif.getAttributes() ?? const <String, Object>{};
    } finally {
      await exif.close();
    }
  }

  Future<bool> _tryWriteExif(
    String path,
    Map<String, Object> attributes,
  ) async {
    if (attributes.isEmpty) {
      _debugLog('write exif skipped path=$path reason=no-attributes');
      return false;
    }
    try {
      await _writeExif(path, attributes);
      _debugLog('write exif success path=$path exifKeys=${attributes.length}');
      return true;
    } on Object catch (error) {
      _debugLog(
        'write exif failure ignored path=$path exifKeys=${attributes.length} error=$error',
      );
      return false;
    }
  }

  Future<void> _writeExif(String path, Map<String, Object> attributes) async {
    if (attributes.isEmpty) {
      return;
    }
    final Exif exif = await Exif.fromPath(path);
    try {
      await exif.writeAttributes(attributes);
    } finally {
      await exif.close();
    }
  }

  _TargetImageSize _targetUploadSizeFromExif(Map<String, Object> sourceExif) {
    final int maxSide = AppConfig.generationUploadImageMaxSide;
    final int? rawWidth = _readIntExifValue(sourceExif, const <String>[
      'PixelXDimension',
      'ImageWidth',
    ]);
    final int? rawHeight = _readIntExifValue(sourceExif, const <String>[
      'PixelYDimension',
      'ImageLength',
    ]);
    if (rawWidth == null ||
        rawHeight == null ||
        rawWidth <= 0 ||
        rawHeight <= 0) {
      return _TargetImageSize(
        width: maxSide,
        height: maxSide,
        sourceWidth: rawWidth,
        sourceHeight: rawHeight,
      );
    }

    final int orientation =
        _readIntExifValue(sourceExif, const <String>['Orientation']) ?? 1;
    final bool swapsAxes =
        orientation == 5 ||
        orientation == 6 ||
        orientation == 7 ||
        orientation == 8;
    final int sourceWidth = swapsAxes ? rawHeight : rawWidth;
    final int sourceHeight = swapsAxes ? rawWidth : rawHeight;
    final int longestSide = math.max(sourceWidth, sourceHeight);
    if (longestSide <= maxSide) {
      return _TargetImageSize(
        width: sourceWidth,
        height: sourceHeight,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
      );
    }

    final double scale = maxSide / longestSide;
    return _TargetImageSize(
      width: math.max(1, (sourceWidth * scale).round()),
      height: math.max(1, (sourceHeight * scale).round()),
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
  }

  int? _readIntExifValue(Map<String, Object> sourceExif, List<String> keys) {
    for (final String key in keys) {
      final Object? value = sourceExif[key];
      if (value is int) {
        return value;
      }
      if (value is double) {
        return value.round();
      }
      if (value is String) {
        return int.tryParse(value);
      }
    }
    return null;
  }

  Future<T> _measure<T>({
    required String label,
    required String jobId,
    required Future<T> Function() action,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      _debugLog(
        '$label finish job=$jobId elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
    }
  }
}

Future<String> _sha256FileBase64(String path) async {
  final Digest digest = await sha256.bind(File(path).openRead()).first;
  return base64.encode(digest.bytes);
}

void _debugLog(String message) {
  appDebugLog('GenerationImageProcessor', message);
}

const List<String> _resultExifOrientationKeys = <String>['Orientation'];

@visibleForTesting
Map<String, Object> sanitizeResultExifForWrite(Map<String, Object> sourceExif) {
  if (sourceExif.isEmpty) {
    return const <String, Object>{};
  }
  final Map<String, Object> resultExif = Map<String, Object>.of(sourceExif);
  for (final String key in _resultExifOrientationKeys) {
    resultExif.remove(key);
  }
  return resultExif;
}

Object? _firstExifValue(Map<String, Object> exif, List<String> keys) {
  for (final String key in keys) {
    final Object? value = exif[key];
    if (value != null) {
      return value;
    }
  }
  return null;
}

class _TargetImageSize {
  const _TargetImageSize({
    required this.width,
    required this.height,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  final int width;
  final int height;
  final int? sourceWidth;
  final int? sourceHeight;
}
