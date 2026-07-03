import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/core/app_logger.dart';
import '../data/generation_record_database.dart';
import '../data/generation_original_file_store.dart';
import '../data/generation_record_repository.dart';

const String generationOriginalCacheStatsTotalBytesKey =
    'generation.original_cache_stats.total_bytes';
const String generationOriginalCacheStatsFileCountKey =
    'generation.original_cache_stats.file_count';
const String generationOriginalCacheStatsMissingFileCountKey =
    'generation.original_cache_stats.missing_file_count';
const String generationOriginalCacheStatsCalculatedAtMsKey =
    'generation.original_cache_stats.calculated_at_ms';

class GenerationOriginalCacheClearResult {
  const GenerationOriginalCacheClearResult({
    required this.clearedCount,
    required this.failedCount,
  });

  final int clearedCount;
  final int failedCount;

  bool get hasFailures => failedCount > 0;
}

class GenerationOriginalCacheStats {
  const GenerationOriginalCacheStats({
    required this.fileCount,
    required this.totalBytes,
    required this.missingFileCount,
    required this.calculatedAt,
  });

  final int fileCount;
  final int totalBytes;
  final int missingFileCount;
  final DateTime calculatedAt;
}

abstract interface class GenerationOriginalCacheStatsRepository {
  Future<GenerationOriginalCacheStats?> loadStats();

  Future<void> saveStats(GenerationOriginalCacheStats stats);
}

class SharedPreferencesGenerationOriginalCacheStatsRepository
    implements GenerationOriginalCacheStatsRepository {
  const SharedPreferencesGenerationOriginalCacheStatsRepository();

  @override
  Future<GenerationOriginalCacheStats?> loadStats() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final int? totalBytes = preferences.getInt(
      generationOriginalCacheStatsTotalBytesKey,
    );
    final int? fileCount = preferences.getInt(
      generationOriginalCacheStatsFileCountKey,
    );
    final int? missingFileCount = preferences.getInt(
      generationOriginalCacheStatsMissingFileCountKey,
    );
    final int? calculatedAtMs = preferences.getInt(
      generationOriginalCacheStatsCalculatedAtMsKey,
    );
    if (totalBytes == null ||
        fileCount == null ||
        missingFileCount == null ||
        calculatedAtMs == null) {
      return null;
    }
    return GenerationOriginalCacheStats(
      fileCount: fileCount,
      totalBytes: totalBytes,
      missingFileCount: missingFileCount,
      calculatedAt: DateTime.fromMillisecondsSinceEpoch(calculatedAtMs),
    );
  }

  @override
  Future<void> saveStats(GenerationOriginalCacheStats stats) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      preferences.setInt(
        generationOriginalCacheStatsTotalBytesKey,
        stats.totalBytes,
      ),
      preferences.setInt(
        generationOriginalCacheStatsFileCountKey,
        stats.fileCount,
      ),
      preferences.setInt(
        generationOriginalCacheStatsMissingFileCountKey,
        stats.missingFileCount,
      ),
      preferences.setInt(
        generationOriginalCacheStatsCalculatedAtMsKey,
        stats.calculatedAt.millisecondsSinceEpoch,
      ),
    ]);
  }
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

  Future<GenerationOriginalCacheStats>
  calculateClearableCameraOriginalCacheStats({
    bool Function()? shouldCancel,
  }) async {
    final List<GenerationRecord> records = await _generationRecordRepository
        .listClearableLocalOriginals();
    int fileCount = 0;
    int totalBytes = 0;
    int missingFileCount = 0;

    for (final GenerationRecord record in records) {
      if (shouldCancel?.call() ?? false) {
        break;
      }

      final String? originalLocalPath = record.originalLocalPath;
      if (originalLocalPath == null || originalLocalPath.isEmpty) {
        continue;
      }

      try {
        final String resolvedPath = await _originalFileStore
            .resolveOriginalPath(originalLocalPath);
        if (shouldCancel?.call() ?? false) {
          break;
        }

        final File file = File(resolvedPath);
        if (!await file.exists()) {
          missingFileCount += 1;
          appDebugLog(
            'GenerationOriginalCacheCleaner',
            'stats missing file record=${record.recordId} path=$originalLocalPath',
          );
          continue;
        }
        if (shouldCancel?.call() ?? false) {
          break;
        }

        totalBytes += await file.length();
        fileCount += 1;
      } on Object catch (error) {
        missingFileCount += 1;
        appDebugLog(
          'GenerationOriginalCacheCleaner',
          'stats failure record=${record.recordId} path=$originalLocalPath error=$error',
        );
      }
    }

    final GenerationOriginalCacheStats stats = GenerationOriginalCacheStats(
      fileCount: fileCount,
      totalBytes: totalBytes,
      missingFileCount: missingFileCount,
      calculatedAt: _now?.call() ?? DateTime.now(),
    );
    appDebugLog(
      'GenerationOriginalCacheCleaner',
      'stats complete files=${stats.fileCount} bytes=${stats.totalBytes} missing=${stats.missingFileCount}',
    );
    return stats;
  }

  Future<GenerationOriginalCacheClearResult> clearCameraOriginalCache() async {
    final List<GenerationRecord> records = await _generationRecordRepository
        .listClearableLocalOriginals();
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
        appDebugLog(
          'GenerationOriginalCacheCleaner',
          'clear failure record=${record.recordId} path=$originalLocalPath error=$error',
        );
      }
    }

    appDebugLog(
      'GenerationOriginalCacheCleaner',
      'clear complete cleared=$clearedCount failed=$failedCount',
    );
    return GenerationOriginalCacheClearResult(
      clearedCount: clearedCount,
      failedCount: failedCount,
    );
  }
}
