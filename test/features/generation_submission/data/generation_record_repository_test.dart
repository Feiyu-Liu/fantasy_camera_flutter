import 'package:drift/native.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_record_database.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_record_repository.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late GenerationRecordDatabase database;
  late GenerationRecordRepository repository;

  setUp(() {
    database = GenerationRecordDatabase.forExecutor(NativeDatabase.memory());
    repository = GenerationRecordRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates camera record with available original', () async {
    final DateTime createdAt = DateTime.utc(2026, 6, 4, 1, 2, 3);

    await repository.createCameraRecord(
      recordId: 'record-camera',
      originalLocalPath: '/tmp/original.heic',
      createdAt: createdAt,
      originalFormat: 'heic',
      originalWidth: 4032,
      originalHeight: 3024,
      promptStyle: 'realistic',
      captureMode: 'manual',
      appInputContractId: 'app_bundled_2026_06_01',
      userInputJson: '{"style":"realistic"}',
      displaySnapshotJson: '{"styleLabel":"Realistic"}',
    );

    final GenerationRecord? record = await repository.findById('record-camera');

    expect(record, isNotNull);
    expect(
      record!.pipelineStatus,
      GenerationRecordPipelineStatus.awaitingConfirmation.name,
    );
    expect(
      record.originalSourceType,
      GenerationRecordOriginalSourceType.camera.name,
    );
    expect(
      record.originalAvailability,
      GenerationRecordOriginalAvailability.available.name,
    );
    expect(record.originalLocalPath, '/tmp/original.heic');
    expect(record.originalHashStatus, GenerationRecordHashStatus.pending.name);
    expect(
      record.resultAvailability,
      GenerationRecordResultAvailability.none.name,
    );
    expect(record.promptStyle, 'realistic');
    expect(record.captureMode, 'manual');
  });

  test('creates gallery record with external original', () async {
    final DateTime createdAt = DateTime.utc(2026, 6, 4, 2);

    await repository.createGalleryRecord(
      recordId: 'record-gallery',
      createdAt: createdAt,
      originalAssetId: 'asset-1',
      originalFormat: 'jpeg',
    );

    final GenerationRecord? record = await repository.findById(
      'record-gallery',
    );

    expect(record, isNotNull);
    expect(
      record!.pipelineStatus,
      GenerationRecordPipelineStatus.awaitingConfirmation.name,
    );
    expect(
      record.originalSourceType,
      GenerationRecordOriginalSourceType.gallery.name,
    );
    expect(
      record.originalAvailability,
      GenerationRecordOriginalAvailability.external.name,
    );
    expect(record.originalAssetId, 'asset-1');
    expect(record.originalLocalPath, isNull);
    expect(
      record.resultAvailability,
      GenerationRecordResultAvailability.none.name,
    );
  });

  test('creates gallery record with app-private original copy', () async {
    final DateTime createdAt = DateTime.utc(2026, 6, 4, 2);

    await repository.createGalleryRecord(
      recordId: 'record-gallery-local',
      createdAt: createdAt,
      originalLocalPath: 'originals/2026/06/04/record-gallery-local.heic',
      originalAssetId: 'asset-1',
      originalFormat: 'heic',
    );

    final GenerationRecord? record = await repository.findById(
      'record-gallery-local',
    );

    expect(record, isNotNull);
    expect(
      record!.originalSourceType,
      GenerationRecordOriginalSourceType.gallery.name,
    );
    expect(
      record.originalAvailability,
      GenerationRecordOriginalAvailability.available.name,
    );
    expect(
      record.originalLocalPath,
      'originals/2026/06/04/record-gallery-local.heic',
    );
    expect(record.originalAssetId, 'asset-1');
  });

  test('marks original cleared without deleting record', () async {
    final DateTime createdAt = DateTime.utc(2026, 6, 4, 3);
    final DateTime clearedAt = DateTime.utc(2026, 6, 5, 3);

    await repository.createCameraRecord(
      recordId: 'record-clear',
      originalLocalPath: '/tmp/original.heic',
      createdAt: createdAt,
    );

    await repository.markOriginalCleared(
      recordId: 'record-clear',
      clearedAt: clearedAt,
    );

    final GenerationRecord? record = await repository.findById('record-clear');

    expect(record, isNotNull);
    expect(record!.originalLocalPath, isNull);
    expect(
      record.originalAvailability,
      GenerationRecordOriginalAvailability.cleared.name,
    );
    expect(
      record.originalClearedAt?.millisecondsSinceEpoch,
      clearedAt.millisecondsSinceEpoch,
    );
    expect(
      record.updatedAt.millisecondsSinceEpoch,
      clearedAt.millisecondsSinceEpoch,
    );
  });

  test('lists only clearable camera originals', () async {
    final DateTime createdAt = DateTime.utc(2026, 6, 4, 4);

    await repository.createCameraRecord(
      recordId: 'clearable',
      originalLocalPath: '/tmp/clearable.heic',
      createdAt: createdAt,
    );
    await repository.updatePipelineStatus(
      recordId: 'clearable',
      status: GenerationRecordPipelineStatus.resultSaved,
      updatedAt: createdAt,
    );

    await repository.createCameraRecord(
      recordId: 'active',
      originalLocalPath: '/tmp/active.heic',
      createdAt: createdAt,
    );
    await repository.updatePipelineStatus(
      recordId: 'active',
      status: GenerationRecordPipelineStatus.pollingTask,
      updatedAt: createdAt,
    );

    await repository.createCameraRecord(
      recordId: 'awaiting-confirmation',
      originalLocalPath: '/tmp/awaiting-confirmation.heic',
      createdAt: createdAt,
    );

    await repository.createCameraRecord(
      recordId: 'generation-failed',
      originalLocalPath: '/tmp/generation-failed.heic',
      createdAt: createdAt,
    );
    await repository.updatePipelineStatus(
      recordId: 'generation-failed',
      status: GenerationRecordPipelineStatus.generationFailed,
      updatedAt: createdAt,
    );

    await repository.createCameraRecord(
      recordId: 'awaiting-retry',
      originalLocalPath: '/tmp/awaiting-retry.heic',
      createdAt: createdAt,
    );
    await repository.updatePipelineStatus(
      recordId: 'awaiting-retry',
      status: GenerationRecordPipelineStatus.awaitingRetry,
      updatedAt: createdAt,
    );

    await repository.createCameraRecord(
      recordId: 'result-save-failed',
      originalLocalPath: '/tmp/result-save-failed.heic',
      createdAt: createdAt,
    );
    await repository.updatePipelineStatus(
      recordId: 'result-save-failed',
      status: GenerationRecordPipelineStatus.resultSaveFailed,
      updatedAt: createdAt,
    );

    await repository.createCameraRecord(
      recordId: 'canceled',
      originalLocalPath: '/tmp/canceled.heic',
      createdAt: createdAt,
    );
    await repository.updatePipelineStatus(
      recordId: 'canceled',
      status: GenerationRecordPipelineStatus.canceled,
      updatedAt: createdAt,
    );

    await repository.createGalleryRecord(
      recordId: 'gallery',
      createdAt: createdAt,
      originalAssetId: 'asset-gallery',
    );

    await repository.createCameraRecord(
      recordId: 'cleared',
      originalLocalPath: '/tmp/cleared.heic',
      createdAt: createdAt,
    );
    await repository.markOriginalCleared(
      recordId: 'cleared',
      clearedAt: createdAt,
    );

    final List<GenerationRecord> records = await repository
        .listClearableCameraOriginals();

    expect(records.map((GenerationRecord record) => record.recordId), <String>[
      'clearable',
      'canceled',
    ]);
  });

  test('updates result fields for saved photo library result', () async {
    final DateTime createdAt = DateTime.utc(2026, 6, 4, 5);
    final DateTime savedAt = DateTime.utc(2026, 6, 4, 6);

    await repository.createCameraRecord(
      recordId: 'record-result',
      originalLocalPath: '/tmp/original.heic',
      createdAt: createdAt,
    );

    await repository.updateResultFields(
      recordId: 'record-result',
      updatedAt: savedAt,
      resultAvailability:
          GenerationRecordResultAvailability.savedToPhotoLibrary,
      resultImageObjectId: 'object-result',
      resultAssetId: 'asset-result',
      resultSavedAt: savedAt,
      resultSizeBytes: 42,
      resultSha256: 'sha-result',
      resultHashStatus: GenerationRecordHashStatus.completed,
    );

    final GenerationRecord? record = await repository.findById('record-result');

    expect(record, isNotNull);
    expect(
      record!.resultAvailability,
      GenerationRecordResultAvailability.savedToPhotoLibrary.name,
    );
    expect(record.resultImageObjectId, 'object-result');
    expect(record.resultAssetId, 'asset-result');
    expect(
      record.resultSavedAt?.millisecondsSinceEpoch,
      savedAt.millisecondsSinceEpoch,
    );
    expect(record.resultSizeBytes, 42);
    expect(record.resultSha256, 'sha-result');
    expect(record.resultHashStatus, GenerationRecordHashStatus.completed.name);
  });

  test(
    'marks terminal result notifications seen only for result outcomes',
    () async {
      final DateTime createdAt = DateTime.utc(2026, 6, 4, 7);
      final DateTime seenAt = DateTime.utc(2026, 6, 4, 8);

      await repository.createCameraRecord(
        recordId: 'saved',
        originalLocalPath: '/tmp/saved.heic',
        createdAt: createdAt,
      );
      await repository.updatePipelineStatus(
        recordId: 'saved',
        status: GenerationRecordPipelineStatus.resultSaved,
        updatedAt: createdAt,
      );

      await repository.createCameraRecord(
        recordId: 'failed',
        originalLocalPath: '/tmp/failed.heic',
        createdAt: createdAt,
      );
      await repository.updatePipelineStatus(
        recordId: 'failed',
        status: GenerationRecordPipelineStatus.generationFailed,
        updatedAt: createdAt,
      );

      await repository.createCameraRecord(
        recordId: 'result-save-failed',
        originalLocalPath: '/tmp/result-save-failed.heic',
        createdAt: createdAt,
      );
      await repository.updatePipelineStatus(
        recordId: 'result-save-failed',
        status: GenerationRecordPipelineStatus.resultSaveFailed,
        updatedAt: createdAt,
      );

      await repository.createCameraRecord(
        recordId: 'processing',
        originalLocalPath: '/tmp/processing.heic',
        createdAt: createdAt,
      );
      await repository.updatePipelineStatus(
        recordId: 'processing',
        status: GenerationRecordPipelineStatus.pollingTask,
        updatedAt: createdAt,
      );

      await repository.createCameraRecord(
        recordId: 'canceled',
        originalLocalPath: '/tmp/canceled.heic',
        createdAt: createdAt,
      );
      await repository.updatePipelineStatus(
        recordId: 'canceled',
        status: GenerationRecordPipelineStatus.canceled,
        updatedAt: createdAt,
      );

      await repository.markTerminalResultNotificationsSeen(seenAt);

      final GenerationRecord saved = (await repository.findById('saved'))!;
      final GenerationRecord failed = (await repository.findById('failed'))!;
      final GenerationRecord resultSaveFailed = (await repository.findById(
        'result-save-failed',
      ))!;
      final GenerationRecord processing = (await repository.findById(
        'processing',
      ))!;
      final GenerationRecord canceled = (await repository.findById(
        'canceled',
      ))!;

      expect(
        saved.resultNotificationSeenAt?.millisecondsSinceEpoch,
        seenAt.millisecondsSinceEpoch,
      );
      expect(
        failed.resultNotificationSeenAt?.millisecondsSinceEpoch,
        seenAt.millisecondsSinceEpoch,
      );
      expect(
        resultSaveFailed.resultNotificationSeenAt?.millisecondsSinceEpoch,
        seenAt.millisecondsSinceEpoch,
      );
      expect(processing.resultNotificationSeenAt, isNull);
      expect(canceled.resultNotificationSeenAt, isNull);
    },
  );

  test('retry clears result notification seen timestamp', () async {
    final DateTime createdAt = DateTime.utc(2026, 6, 4, 9);
    final DateTime failedAt = DateTime.utc(2026, 6, 4, 10);
    final DateTime seenAt = DateTime.utc(2026, 6, 4, 11);
    final DateTime retryAt = DateTime.utc(2026, 6, 4, 12);

    await repository.createCameraRecord(
      recordId: 'retry',
      originalLocalPath: '/tmp/retry.heic',
      createdAt: createdAt,
    );
    await repository.updatePipelineStatus(
      recordId: 'retry',
      status: GenerationRecordPipelineStatus.generationFailed,
      updatedAt: failedAt,
    );
    await repository.markTerminalResultNotificationsSeen(seenAt);

    GenerationRecord record = (await repository.findById('retry'))!;
    expect(
      record.resultNotificationSeenAt?.millisecondsSinceEpoch,
      seenAt.millisecondsSinceEpoch,
    );

    await repository.resetForRetry(recordId: 'retry', updatedAt: retryAt);

    record = (await repository.findById('retry'))!;
    expect(
      record.pipelineStatus,
      GenerationRecordPipelineStatus.awaitingRetry.name,
    );
    expect(record.resultNotificationSeenAt, isNull);
  });
}
