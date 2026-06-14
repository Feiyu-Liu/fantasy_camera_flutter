import 'dart:io';

import 'package:drift/native.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/application/generation_original_cache_cleaner.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_original_file_store.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_record_database.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_record_repository.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late GenerationRecordDatabase database;
  late GenerationRecordRepository repository;
  late _FakeOriginalFileStore originalFileStore;

  setUp(() {
    database = GenerationRecordDatabase.forExecutor(NativeDatabase.memory());
    repository = GenerationRecordRepository(database);
    originalFileStore = _FakeOriginalFileStore();
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'clears non-active camera originals and leaves gallery originals',
    () async {
      final DateTime createdAt = DateTime.utc(2026, 6, 14, 10);
      final DateTime clearedAt = DateTime.utc(2026, 6, 14, 11);

      await repository.createCameraRecord(
        recordId: 'camera-saved',
        originalLocalPath: 'originals/camera-saved.heic',
        createdAt: createdAt,
      );
      await repository.updatePipelineStatus(
        recordId: 'camera-saved',
        status: GenerationRecordPipelineStatus.resultSaved,
        updatedAt: createdAt,
      );
      await repository.createCameraRecord(
        recordId: 'camera-active',
        originalLocalPath: 'originals/camera-active.heic',
        createdAt: createdAt,
      );
      await repository.updatePipelineStatus(
        recordId: 'camera-active',
        status: GenerationRecordPipelineStatus.pollingTask,
        updatedAt: createdAt,
      );
      await repository.createCameraRecord(
        recordId: 'camera-awaiting-confirmation',
        originalLocalPath: 'originals/camera-awaiting-confirmation.heic',
        createdAt: createdAt,
      );
      await repository.createCameraRecord(
        recordId: 'camera-generation-failed',
        originalLocalPath: 'originals/camera-generation-failed.heic',
        createdAt: createdAt,
      );
      await repository.updatePipelineStatus(
        recordId: 'camera-generation-failed',
        status: GenerationRecordPipelineStatus.generationFailed,
        updatedAt: createdAt,
      );
      await repository.createCameraRecord(
        recordId: 'camera-awaiting-retry',
        originalLocalPath: 'originals/camera-awaiting-retry.heic',
        createdAt: createdAt,
      );
      await repository.updatePipelineStatus(
        recordId: 'camera-awaiting-retry',
        status: GenerationRecordPipelineStatus.awaitingRetry,
        updatedAt: createdAt,
      );
      await repository.createCameraRecord(
        recordId: 'camera-result-save-failed',
        originalLocalPath: 'originals/camera-result-save-failed.heic',
        createdAt: createdAt,
      );
      await repository.updatePipelineStatus(
        recordId: 'camera-result-save-failed',
        status: GenerationRecordPipelineStatus.resultSaveFailed,
        updatedAt: createdAt,
      );
      await repository.createGalleryRecord(
        recordId: 'gallery',
        createdAt: createdAt,
        originalAssetId: 'asset-1',
      );

      final GenerationOriginalCacheCleaner cleaner =
          GenerationOriginalCacheCleaner(
            generationRecordRepository: repository,
            originalFileStore: originalFileStore,
            now: () => clearedAt,
          );

      final GenerationOriginalCacheClearResult result = await cleaner
          .clearCameraOriginalCache();

      expect(result.clearedCount, 1);
      expect(result.failedCount, 0);
      expect(originalFileStore.deletedPaths, <String>[
        'originals/camera-saved.heic',
      ]);

      final GenerationRecord? cleared = await repository.findById(
        'camera-saved',
      );
      expect(cleared!.originalLocalPath, isNull);
      expect(
        cleared.originalAvailability,
        GenerationRecordOriginalAvailability.cleared.name,
      );
      expect(
        cleared.originalClearedAt?.millisecondsSinceEpoch,
        clearedAt.millisecondsSinceEpoch,
      );

      final GenerationRecord? active = await repository.findById(
        'camera-active',
      );
      expect(active!.originalLocalPath, 'originals/camera-active.heic');
      expect(
        active.originalAvailability,
        GenerationRecordOriginalAvailability.available.name,
      );

      final GenerationRecord? awaitingConfirmation = await repository.findById(
        'camera-awaiting-confirmation',
      );
      expect(
        awaitingConfirmation!.originalLocalPath,
        'originals/camera-awaiting-confirmation.heic',
      );
      expect(
        awaitingConfirmation.originalAvailability,
        GenerationRecordOriginalAvailability.available.name,
      );

      final GenerationRecord? generationFailed = await repository.findById(
        'camera-generation-failed',
      );
      expect(
        generationFailed!.originalLocalPath,
        'originals/camera-generation-failed.heic',
      );

      final GenerationRecord? awaitingRetry = await repository.findById(
        'camera-awaiting-retry',
      );
      expect(
        awaitingRetry!.originalLocalPath,
        'originals/camera-awaiting-retry.heic',
      );

      final GenerationRecord? resultSaveFailed = await repository.findById(
        'camera-result-save-failed',
      );
      expect(
        resultSaveFailed!.originalLocalPath,
        'originals/camera-result-save-failed.heic',
      );

      final GenerationRecord? gallery = await repository.findById('gallery');
      expect(gallery!.originalAssetId, 'asset-1');
      expect(
        gallery.originalAvailability,
        GenerationRecordOriginalAvailability.external.name,
      );
    },
  );

  test('keeps database record unchanged when file deletion fails', () async {
    final DateTime createdAt = DateTime.utc(2026, 6, 14, 12);
    await repository.createCameraRecord(
      recordId: 'camera-failure',
      originalLocalPath: 'originals/camera-failure.heic',
      createdAt: createdAt,
    );
    await repository.updatePipelineStatus(
      recordId: 'camera-failure',
      status: GenerationRecordPipelineStatus.resultSaved,
      updatedAt: createdAt,
    );
    originalFileStore.failingPaths.add('originals/camera-failure.heic');

    final GenerationOriginalCacheCleaner cleaner =
        GenerationOriginalCacheCleaner(
          generationRecordRepository: repository,
          originalFileStore: originalFileStore,
        );

    final GenerationOriginalCacheClearResult result = await cleaner
        .clearCameraOriginalCache();

    expect(result.clearedCount, 0);
    expect(result.failedCount, 1);

    final GenerationRecord? record = await repository.findById(
      'camera-failure',
    );
    expect(record!.originalLocalPath, 'originals/camera-failure.heic');
    expect(
      record.originalAvailability,
      GenerationRecordOriginalAvailability.available.name,
    );
  });
}

class _FakeOriginalFileStore implements GenerationOriginalFileStore {
  final List<String> deletedPaths = <String>[];
  final Set<String> failingPaths = <String>{};

  @override
  Future<void> deleteOriginal(String path) async {
    if (failingPaths.contains(path)) {
      throw FileSystemException('delete failed', path);
    }
    deletedPaths.add(path);
  }

  @override
  Future<bool> originalExists(String path) async => true;

  @override
  Future<String> resolveOriginalPath(String path) async => path;

  @override
  Future<StoredOriginalFile> storeCameraOriginal({
    required String recordId,
    required String sourcePath,
    required DateTime capturedAt,
  }) async {
    return StoredOriginalFile(path: sourcePath, format: 'heic');
  }
}
