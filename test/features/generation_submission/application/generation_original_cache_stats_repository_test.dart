import 'package:fantasy_camera_flutter/features/generation_submission/application/generation_original_cache_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('returns null when no cached stats exist', () async {
    const SharedPreferencesGenerationOriginalCacheStatsRepository repository =
        SharedPreferencesGenerationOriginalCacheStatsRepository();

    final GenerationOriginalCacheStats? stats = await repository.loadStats();

    expect(stats, isNull);
  });

  test('saves and loads original cache stats', () async {
    const SharedPreferencesGenerationOriginalCacheStatsRepository repository =
        SharedPreferencesGenerationOriginalCacheStatsRepository();
    final GenerationOriginalCacheStats stats = GenerationOriginalCacheStats(
      fileCount: 3,
      totalBytes: 4096,
      missingFileCount: 1,
      calculatedAt: DateTime.utc(2026, 6, 15, 8),
    );

    await repository.saveStats(stats);

    final GenerationOriginalCacheStats? loaded = await repository.loadStats();

    expect(loaded, isNotNull);
    expect(loaded!.fileCount, 3);
    expect(loaded.totalBytes, 4096);
    expect(loaded.missingFileCount, 1);
    expect(
      loaded.calculatedAt.millisecondsSinceEpoch,
      stats.calculatedAt.millisecondsSinceEpoch,
    );
  });

  test('save overwrites previous original cache stats', () async {
    const SharedPreferencesGenerationOriginalCacheStatsRepository repository =
        SharedPreferencesGenerationOriginalCacheStatsRepository();

    await repository.saveStats(
      GenerationOriginalCacheStats(
        fileCount: 1,
        totalBytes: 1024,
        missingFileCount: 0,
        calculatedAt: DateTime.utc(2026, 6, 15, 8),
      ),
    );
    await repository.saveStats(
      GenerationOriginalCacheStats(
        fileCount: 2,
        totalBytes: 2048,
        missingFileCount: 1,
        calculatedAt: DateTime.utc(2026, 6, 15, 9),
      ),
    );

    final GenerationOriginalCacheStats? loaded = await repository.loadStats();

    expect(loaded, isNotNull);
    expect(loaded!.fileCount, 2);
    expect(loaded.totalBytes, 2048);
    expect(loaded.missingFileCount, 1);
  });
}
