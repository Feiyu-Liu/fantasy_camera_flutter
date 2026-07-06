import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_record_database.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_record_repository.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_record.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../drift/generated/schema.dart' as generated_schema;

void main() {
  test('creates the current generation records schema', () async {
    final GenerationRecordDatabase database =
        GenerationRecordDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(database.close);

    expect(
      await _readUserVersion(database),
      GenerationRecordDatabase.currentSchemaVersion,
    );
    await database.validateDatabaseSchema();
  });

  test('migrates every stored schema version to the current schema', () async {
    final SchemaVerifier verifier = SchemaVerifier(
      generated_schema.GeneratedHelper(),
    );

    for (final int version in generated_schema.GeneratedHelper.versions) {
      final DatabaseConnection connection = await verifier.startAt(version);
      final GenerationRecordDatabase database =
          GenerationRecordDatabase.forExecutor(connection);

      await verifier.migrateAndValidate(
        database,
        GenerationRecordDatabase.currentSchemaVersion,
      );
      expect(
        await _readUserVersion(database),
        GenerationRecordDatabase.currentSchemaVersion,
      );
      await database.close();
    }
  });

  test('migrates v1 generation records to v2 without data loss', () async {
    final Directory tempDirectory = await Directory.systemTemp.createTemp(
      'generation_record_migration_test_',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final File databaseFile = File(
      '${tempDirectory.path}/generation_records.sqlite',
    );
    await _seedV1Database(databaseFile);

    final GenerationRecordDatabase migratedDatabase =
        GenerationRecordDatabase.forExecutor(NativeDatabase(databaseFile));
    addTearDown(migratedDatabase.close);

    final int schemaVersion = await _readUserVersion(migratedDatabase);
    final GenerationRecordRepository repository = GenerationRecordRepository(
      migratedDatabase,
    );
    final GenerationRecord? record = await repository.findById(
      'record-v1-saved',
    );

    expect(schemaVersion, GenerationRecordDatabase.currentSchemaVersion);
    expect(record, isNotNull);
    expect(record!.recordId, 'record-v1-saved');
    expect(
      record.pipelineStatus,
      GenerationRecordPipelineStatus.resultSaved.name,
    );
    expect(
      record.originalAvailability,
      GenerationRecordOriginalAvailability.available.name,
    );
    expect(record.originalLocalPath, 'originals/record-v1-saved.heic');
    expect(record.originalAssetId, 'original-asset-v1');
    expect(record.taskId, 'task-v1');
    expect(record.resultImageObjectId, 'result-object-v1');
    expect(record.resultAssetId, 'result-asset-v1');
    expect(
      record.resultAvailability,
      GenerationRecordResultAvailability.savedToPhotoLibrary.name,
    );
    expect(record.resultIsFavorite, isTrue);
    expect(record.promptStyle, 'realistic');
    expect(record.captureMode, 'portrait');
    expect(record.userInputJson, '{"prompt":"v1"}');
  });
}

Future<void> _seedV1Database(File databaseFile) async {
  final GenerationRecordDatabase database =
      GenerationRecordDatabase.forExecutor(NativeDatabase(databaseFile));
  final GenerationRecordRepository repository = GenerationRecordRepository(
    database,
  );
  final DateTime createdAt = DateTime.utc(2026, 6, 4, 1, 2, 3);
  final DateTime updatedAt = DateTime.utc(2026, 6, 4, 1, 5);

  await repository.createCameraRecord(
    recordId: 'record-v1-saved',
    originalLocalPath: 'originals/record-v1-saved.heic',
    originalCapturedAt: createdAt,
    createdAt: createdAt,
    originalFormat: 'heic',
    originalWidth: 4032,
    originalHeight: 3024,
    promptStyle: 'realistic',
    captureMode: 'portrait',
    appInputContractId: 'app_bundled_2026_06_01',
    userInputJson: '{"prompt":"v1"}',
    displaySnapshotJson: '{"mode":"portrait"}',
  );
  await repository.updateUploadFields(
    recordId: 'record-v1-saved',
    updatedAt: updatedAt,
    uploadSessionId: 'upload-v1',
    sourceImageObjectId: 'source-object-v1',
    uploadContentType: 'image/jpeg',
    uploadSizeBytes: 123456,
    uploadSha256: 'upload-sha-v1',
  );
  await repository.updateTaskFields(
    recordId: 'record-v1-saved',
    updatedAt: updatedAt,
    taskId: 'task-v1',
    taskStatus: 'completed',
    resultImageObjectId: 'result-object-v1',
  );
  await repository.updateResultFields(
    recordId: 'record-v1-saved',
    updatedAt: updatedAt,
    resultAvailability: GenerationRecordResultAvailability.localCache,
    resultImageObjectId: 'result-object-v1',
    resultLocalCachePath: 'cache/result-v1.heic',
    resultSizeBytes: 654321,
    resultSha256: 'result-sha-v1',
    resultHashStatus: GenerationRecordHashStatus.completed,
  );
  await repository.markResultSaved(
    recordId: 'record-v1-saved',
    updatedAt: updatedAt,
    resultAssetId: 'result-asset-v1',
    resultImageObjectId: 'result-object-v1',
    resultSavedAt: updatedAt,
    resultSizeBytes: 654321,
    resultSha256: 'result-sha-v1',
    resultHashStatus: GenerationRecordHashStatus.completed,
  );
  await repository.updateResultFavorite(
    recordId: 'record-v1-saved',
    updatedAt: updatedAt,
    isFavorite: true,
    favoritedAt: updatedAt,
  );
  await database
      .update(database.generationRecords)
      .write(
        const GenerationRecordsCompanion(
          originalAssetId: Value<String?>('original-asset-v1'),
        ),
      );
  await database.customStatement('PRAGMA user_version = 1');
  await database.close();
}

Future<int> _readUserVersion(GenerationRecordDatabase database) async {
  final List<QueryRow> rows = await database
      .customSelect('PRAGMA user_version')
      .get();
  return rows.single.read<int>('user_version');
}
