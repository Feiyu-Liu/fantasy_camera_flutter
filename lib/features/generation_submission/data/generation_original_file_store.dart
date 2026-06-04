import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoredOriginalFile {
  const StoredOriginalFile({required this.path, required this.format});

  /// App-support-relative path for records created by the current storage
  /// implementation. Legacy records may still contain absolute paths.
  final String path;
  final String format;
}

abstract interface class GenerationOriginalFileStore {
  Future<StoredOriginalFile> storeCameraOriginal({
    required String recordId,
    required String sourcePath,
    required DateTime capturedAt,
  });

  Future<String> resolveOriginalPath(String path);

  Future<bool> originalExists(String path);

  Future<void> deleteOriginal(String path);
}

class ApplicationSupportGenerationOriginalFileStore
    implements GenerationOriginalFileStore {
  const ApplicationSupportGenerationOriginalFileStore();

  @override
  Future<StoredOriginalFile> storeCameraOriginal({
    required String recordId,
    required String sourcePath,
    required DateTime capturedAt,
  }) async {
    final File sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Camera original does not exist.', sourcePath);
    }

    final String extension = _extensionForPath(sourcePath);
    final String relativeDirectory = _relativeOriginalsDirectory(capturedAt);
    final Directory directory = await _directoryForRelativePath(
      relativeDirectory,
    );
    await directory.create(recursive: true);
    await _excludeFromBackup(directory);

    final String relativePath = p.join(relativeDirectory, '$recordId$extension');
    final File destination = File(await resolveOriginalPath(relativePath));
    await sourceFile.copy(destination.path);
    await _excludeFromBackup(destination);
    return StoredOriginalFile(
      path: relativePath,
      format: extension.replaceFirst('.', '').toLowerCase(),
    );
  }

  @override
  Future<String> resolveOriginalPath(String path) async {
    if (p.isAbsolute(path)) {
      return path;
    }
    final Directory storageRoot = await _storageRootDirectory();
    return p.join(storageRoot.path, path);
  }

  @override
  Future<bool> originalExists(String path) async {
    return File(await resolveOriginalPath(path)).exists();
  }

  @override
  Future<void> deleteOriginal(String path) async {
    final File file = File(await resolveOriginalPath(path));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _storageRootDirectory() async {
    final Directory applicationSupport = await getApplicationSupportDirectory();
    return Directory(p.join(applicationSupport.path, 'TesserCam'));
  }

  Future<Directory> _directoryForRelativePath(String relativePath) async {
    final Directory storageRoot = await _storageRootDirectory();
    return Directory(p.join(storageRoot.path, relativePath));
  }

  String _relativeOriginalsDirectory(DateTime capturedAt) {
    final DateTime local = capturedAt.toLocal();
    return p.join(
      'originals',
      local.year.toString().padLeft(4, '0'),
      local.month.toString().padLeft(2, '0'),
      local.day.toString().padLeft(2, '0'),
    );
  }

  String _extensionForPath(String path) {
    final String extension = p.extension(path);
    if (extension.isEmpty) {
      return '.heic';
    }
    return extension.toLowerCase();
  }

  Future<void> _excludeFromBackup(FileSystemEntity entity) async {
    // TODO: Wire this to a small platform channel if iCloud backup exclusion is
    // not provided by the selected filesystem plugin.
  }
}
