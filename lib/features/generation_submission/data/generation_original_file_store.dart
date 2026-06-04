import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoredOriginalFile {
  const StoredOriginalFile({required this.path, required this.format});

  final String path;
  final String format;
}

abstract interface class GenerationOriginalFileStore {
  Future<StoredOriginalFile> storeCameraOriginal({
    required String recordId,
    required String sourcePath,
    required DateTime capturedAt,
  });

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
    final Directory directory = await _originalsDirectory(capturedAt);
    await directory.create(recursive: true);
    await _excludeFromBackup(directory);

    final File destination = File(
      p.join(directory.path, '$recordId$extension'),
    );
    await sourceFile.copy(destination.path);
    await _excludeFromBackup(destination);
    return StoredOriginalFile(
      path: destination.path,
      format: extension.replaceFirst('.', '').toLowerCase(),
    );
  }

  @override
  Future<void> deleteOriginal(String path) async {
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _originalsDirectory(DateTime capturedAt) async {
    final Directory applicationSupport = await getApplicationSupportDirectory();
    final DateTime local = capturedAt.toLocal();
    return Directory(
      p.join(
        applicationSupport.path,
        'TesserCam',
        'originals',
        local.year.toString().padLeft(4, '0'),
        local.month.toString().padLeft(2, '0'),
        local.day.toString().padLeft(2, '0'),
      ),
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
