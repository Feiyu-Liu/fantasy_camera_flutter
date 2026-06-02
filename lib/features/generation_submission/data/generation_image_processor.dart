import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:native_exif/native_exif.dart';
import 'package:path_provider/path_provider.dart';

import '../../../config/app_config.dart';

class PreparedUploadImage {
  const PreparedUploadImage({
    required this.path,
    required this.bytes,
    required this.sourceExif,
  });

  final String path;
  final Uint8List bytes;
  final Map<String, Object> sourceExif;
}

class ProcessedResultImage {
  const ProcessedResultImage({required this.path, required this.bytes});

  final String path;
  final Uint8List bytes;
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
  const FlutterGenerationImageProcessor({required Dio dio}) : _dio = dio;

  final Dio _dio;

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

    final String targetPath = await _temporaryPath(
      jobId: jobId,
      suffix: 'upload.jpg',
    );
    final XFile compressedFile = await _measure(
      label: 'clean jpeg',
      jobId: jobId,
      action: () async {
        final XFile? file = await FlutterImageCompress.compressAndGetFile(
          sourcePath,
          targetPath,
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

    final Uint8List bytes = await compressedFile.readAsBytes();
    _debugLog(
      'prepare upload success job=$jobId output=${compressedFile.path} bytes=${bytes.length} exifKeys=${sourceExif.length}',
    );

    return PreparedUploadImage(
      path: compressedFile.path,
      bytes: bytes,
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
    final String downloadedPath = await _temporaryPath(
      jobId: jobId,
      suffix: 'result-download',
    );
    await _measure(
      label: 'download result',
      jobId: jobId,
      action: () => _dio.download(resultUrl, downloadedPath),
    );

    final String heicPath = await _temporaryPath(
      jobId: jobId,
      suffix: 'result.heic',
    );
    final XFile heicFile = await _measure(
      label: 'convert result heif',
      jobId: jobId,
      action: () async {
        final XFile? file = await FlutterImageCompress.compressAndGetFile(
          downloadedPath,
          heicPath,
          quality: AppConfig.generationResultHeifQuality,
          format: CompressFormat.heic,
          keepExif: false,
        );
        if (file == null) {
          throw StateError('HEIF conversion returned null.');
        }
        return file;
      },
    );
    XFile resultFile =
        await _existingNonEmptyXFile(heicFile.path) ??
        await _createFallbackJpegResult(
          jobId: jobId,
          downloadedPath: downloadedPath,
          missingHeicPath: heicFile.path,
        );
    final int resultBytes = await File(resultFile.path).length();
    _debugLog(
      'result image file ready job=$jobId path=${resultFile.path} bytes=$resultBytes',
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

    final Uint8List bytes = await resultFile.readAsBytes();
    _debugLog(
      'process result success job=$jobId output=${resultFile.path} bytes=${bytes.length} sourceExifKeys=${sourceExif.length} resultExifKeys=${resultExif.length} exifWritten=$exifWritten',
    );
    return ProcessedResultImage(path: resultFile.path, bytes: bytes);
  }

  Future<XFile?> _existingNonEmptyXFile(String path) async {
    final File file = File(path);
    if (!await file.exists()) {
      return null;
    }
    final int length = await file.length();
    if (length <= 0) {
      return null;
    }
    return XFile(path);
  }

  Future<XFile> _createFallbackJpegResult({
    required String jobId,
    required String downloadedPath,
    required String missingHeicPath,
  }) async {
    _debugLog(
      'convert result heif output missing job=$jobId path=$missingHeicPath fallback=jpeg',
    );
    final String fallbackPath = await _temporaryPath(
      jobId: jobId,
      suffix: 'result-fallback.jpg',
    );
    final XFile? fallbackFile = await FlutterImageCompress.compressAndGetFile(
      downloadedPath,
      fallbackPath,
      quality: AppConfig.generationUploadJpegQuality,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    final XFile? existingFallback = fallbackFile == null
        ? null
        : await _existingNonEmptyXFile(fallbackFile.path);
    if (existingFallback != null) {
      _debugLog(
        'fallback jpeg result success job=$jobId path=${existingFallback.path}',
      );
      return existingFallback;
    }

    final File downloadedFile = File(downloadedPath);
    final File copiedFile = await downloadedFile.copy(fallbackPath);
    final XFile? copiedFallback = await _existingNonEmptyXFile(copiedFile.path);
    if (copiedFallback != null) {
      _debugLog(
        'fallback jpeg copy success job=$jobId path=${copiedFallback.path}',
      );
      return copiedFallback;
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

  Future<String> _temporaryPath({
    required String jobId,
    required String suffix,
  }) async {
    final Directory directory = await getTemporaryDirectory();
    final String safeJobId = jobId.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '${directory.path}/generation-$safeJobId-$suffix';
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

void _debugLog(String message) {
  debugPrint('[GenerationImageProcessor] $message');
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
