import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef ApplicationCacheDirectoryProvider = Future<Directory> Function();

class GenerationUploadArtifactTarget {
  const GenerationUploadArtifactTarget({
    required this.path,
    required this.isReusable,
  });

  final String path;
  final bool isReusable;
}

abstract interface class GenerationImageArtifactStore {
  Future<GenerationUploadArtifactTarget> resolveUploadTarget({
    required String recordId,
    required String sourcePath,
    required int maxSide,
    required int quality,
    required bool keepExif,
  });

  Future<String> createPartialPath(String finalPath);

  Future<void> commitPartial({
    required String partialPath,
    required String finalPath,
  });

  Future<String> resultDownloadPath(String recordId);

  Future<String> resultArtifactPath(String recordId, {required String suffix});

  Future<int?> validFileSize(String path, {int? expectedSizeBytes});

  Future<int?> validJpegSize(String path);

  Future<void> deleteArtifact(String path);

  Future<void> deleteRecordArtifacts(String recordId);
}

class ApplicationCacheGenerationImageArtifactStore
    implements GenerationImageArtifactStore {
  const ApplicationCacheGenerationImageArtifactStore({
    this.cacheDirectoryProvider = getApplicationCacheDirectory,
  });

  static const int _uploadProcessingVersion = 1;

  final ApplicationCacheDirectoryProvider cacheDirectoryProvider;

  @override
  Future<GenerationUploadArtifactTarget> resolveUploadTarget({
    required String recordId,
    required String sourcePath,
    required int maxSide,
    required int quality,
    required bool keepExif,
  }) async {
    final FileStat sourceStat = await File(sourcePath).stat();
    final String cacheKey = sha256
        .convert(
          utf8.encode(
            'v=$_uploadProcessingVersion|size=${sourceStat.size}|'
            'mtime=${sourceStat.modified.millisecondsSinceEpoch}|'
            'maxSide=$maxSide|quality=$quality|keepExif=$keepExif',
          ),
        )
        .toString();
    final Directory directory = await _recordDirectory(recordId);
    final String path = p.join(directory.path, 'upload-$cacheKey.jpg');
    return GenerationUploadArtifactTarget(
      path: path,
      isReusable: await _isValidJpeg(path),
    );
  }

  @override
  Future<String> createPartialPath(String finalPath) async {
    await Directory(p.dirname(finalPath)).create(recursive: true);
    return p.join(
      p.dirname(finalPath),
      '.${p.basenameWithoutExtension(finalPath)}.partial-$pid-'
      '${DateTime.now().microsecondsSinceEpoch}${p.extension(finalPath)}',
    );
  }

  @override
  Future<void> commitPartial({
    required String partialPath,
    required String finalPath,
  }) async {
    final File partialFile = File(partialPath);
    if (!await partialFile.exists() || await partialFile.length() <= 0) {
      throw StateError('Image artifact partial file is missing or empty.');
    }
    await partialFile.rename(finalPath);
  }

  @override
  Future<String> resultDownloadPath(String recordId) async {
    final Directory directory = await _recordDirectory(recordId);
    return p.join(directory.path, 'result-download');
  }

  @override
  Future<String> resultArtifactPath(
    String recordId, {
    required String suffix,
  }) async {
    final Directory directory = await _recordDirectory(recordId);
    return p.join(directory.path, 'result.$suffix');
  }

  @override
  Future<int?> validFileSize(String path, {int? expectedSizeBytes}) async {
    if (path.isEmpty) {
      return null;
    }
    final File file = File(path);
    if (!await file.exists()) {
      return null;
    }
    final int size = await file.length();
    if (size <= 0 || (expectedSizeBytes != null && size != expectedSizeBytes)) {
      return null;
    }
    return size;
  }

  @override
  Future<int?> validJpegSize(String path) async {
    if (!await _isValidJpeg(path)) {
      return null;
    }
    return File(path).length();
  }

  @override
  Future<void> deleteArtifact(String path) async {
    if (path.isEmpty) {
      return;
    }
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> deleteRecordArtifacts(String recordId) async {
    final Directory directory = await _recordDirectory(recordId, create: false);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<Directory> _recordDirectory(
    String recordId, {
    bool create = true,
  }) async {
    final Directory cacheDirectory = await cacheDirectoryProvider();
    final String safeRecordId = recordId.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '_',
    );
    final Directory directory = Directory(
      p.join(cacheDirectory.path, 'TesserCam', 'generation', safeRecordId),
    );
    if (create) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<bool> _isValidJpeg(String path) async {
    final int? size = await validFileSize(path);
    if (size == null || size < 3) {
      return false;
    }
    final RandomAccessFile file = await File(path).open();
    try {
      final List<int> magic = await file.read(3);
      return magic.length == 3 &&
          magic[0] == 0xff &&
          magic[1] == 0xd8 &&
          magic[2] == 0xff;
    } finally {
      await file.close();
    }
  }
}
