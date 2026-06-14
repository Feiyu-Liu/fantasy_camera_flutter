import 'package:flutter/foundation.dart';

import '../data/generation_record_repository.dart';
import '../data/generation_original_file_store.dart';
import '../data/generation_record_database.dart';

class GenerationOriginalCacheClearResult {
  const GenerationOriginalCacheClearResult({
    required this.clearedCount,
    required this.failedCount,
  });

  final int clearedCount;
  final int failedCount;

  bool get hasFailures => failedCount > 0;
}

class GenerationOriginalCacheCleaner {
  const GenerationOriginalCacheCleaner({
    required GenerationRecordRepository generationRecordRepository,
    required GenerationOriginalFileStore originalFileStore,
    DateTime Function()? now,
  }) : _generationRecordRepository = generationRecordRepository,
       _originalFileStore = originalFileStore,
       _now = now;

  final GenerationRecordRepository _generationRecordRepository;
  final GenerationOriginalFileStore _originalFileStore;
  final DateTime Function()? _now;

  Future<GenerationOriginalCacheClearResult> clearCameraOriginalCache() async {
    final List<GenerationRecord> records = await _generationRecordRepository
        .listClearableCameraOriginals();
    int clearedCount = 0;
    int failedCount = 0;

    for (final GenerationRecord record in records) {
      final String? originalLocalPath = record.originalLocalPath;
      if (originalLocalPath == null || originalLocalPath.isEmpty) {
        continue;
      }

      try {
        await _originalFileStore.deleteOriginal(originalLocalPath);
        await _generationRecordRepository.markOriginalCleared(
          recordId: record.recordId,
          clearedAt: _now?.call() ?? DateTime.now(),
        );
        clearedCount += 1;
      } on Object catch (error) {
        failedCount += 1;
        debugPrint(
          '[GenerationOriginalCacheCleaner] clear failure '
          'record=${record.recordId} path=$originalLocalPath error=$error',
        );
      }
    }

    debugPrint(
      '[GenerationOriginalCacheCleaner] clear complete '
      'cleared=$clearedCount failed=$failedCount',
    );
    return GenerationOriginalCacheClearResult(
      clearedCount: clearedCount,
      failedCount: failedCount,
    );
  }
}
