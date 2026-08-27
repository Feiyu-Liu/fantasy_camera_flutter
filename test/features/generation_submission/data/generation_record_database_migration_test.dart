import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_record_database.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_record_repository.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_record.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/domain/generation_submission_job.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../drift/generated/schema.dart' as generated_schema;
import '../../../drift/generated/schema_v1.dart' as generated_v1;
import '../../../drift/generated/schema_v3.dart' as generated_v3;
import '../../../drift/generated/schema_v4.dart' as generated_v4;

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

  test('migrates v1 generation records to the current schema', () async {
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
    expect(record.captureAspectRatio, isNull);
    expect(record.generationStartedAt, isNull);
    expect(record.animationIndex, isNull);
    expect(record.userInputJson, '{"prompt":"v1"}');
  });

  test('migrates v4 records without backfilling animation indexes', () async {
    final Directory tempDirectory = await Directory.systemTemp.createTemp(
      'generation_record_v4_migration_test_',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final File databaseFile = File(
      '${tempDirectory.path}/generation_records.sqlite',
    );
    final generated_v4.DatabaseAtV4 v4Database = generated_v4.DatabaseAtV4(
      NativeDatabase(databaseFile),
    );
    await _insertV4Record(
      v4Database,
      recordId: 'record-v4-oldest',
      createdAt: DateTime.utc(2026, 8, 1, 8),
    );
    await _insertV4Record(
      v4Database,
      recordId: 'record-v4-newest',
      createdAt: DateTime.utc(2026, 8, 1, 9),
    );
    await v4Database.close();

    final GenerationRecordDatabase migratedDatabase =
        GenerationRecordDatabase.forExecutor(NativeDatabase(databaseFile));
    addTearDown(migratedDatabase.close);
    final GenerationRecordRepository repository = GenerationRecordRepository(
      migratedDatabase,
    );

    final List<GenerationRecord> legacyRecords = await repository.listRecords();
    expect(
      legacyRecords.map((GenerationRecord record) => record.animationIndex),
      <int?>[null, null],
    );
    expect(
      await migratedDatabase
          .select(migratedDatabase.generationAnimationSequenceStates)
          .get(),
      isEmpty,
    );

    await repository.createCameraRecord(
      recordId: 'record-v5-new',
      originalLocalPath: 'originals/record-v5-new.heic',
      createdAt: DateTime.utc(2026, 8, 1, 10),
    );

    final GenerationRecord newRecord = (await repository.findById(
      'record-v5-new',
    ))!;
    expect(newRecord.animationIndex, generationDefaultAnimationIndex);
  });

  test(
    'migrates v3 progress anchors without changing pending records',
    () async {
      final Directory tempDirectory = await Directory.systemTemp.createTemp(
        'generation_record_v3_migration_test_',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final File databaseFile = File(
        '${tempDirectory.path}/generation_records.sqlite',
      );
      final DateTime activeUpdatedAt = DateTime.utc(2026, 7, 28, 8, 30);
      final generated_v3.DatabaseAtV3 v3Database = generated_v3.DatabaseAtV3(
        NativeDatabase(databaseFile),
      );
      await _insertV3Record(
        v3Database,
        recordId: 'record-v3-active',
        status: GenerationRecordPipelineStatus.pollingTask,
        updatedAt: activeUpdatedAt,
      );
      await _insertV3Record(
        v3Database,
        recordId: 'record-v3-awaiting',
        status: GenerationRecordPipelineStatus.awaitingConfirmation,
        updatedAt: DateTime.utc(2026, 7, 28, 8),
      );
      await v3Database.close();

      final GenerationRecordDatabase migratedDatabase =
          GenerationRecordDatabase.forExecutor(NativeDatabase(databaseFile));
      addTearDown(migratedDatabase.close);
      final GenerationRecordRepository repository = GenerationRecordRepository(
        migratedDatabase,
      );

      final GenerationRecord active = (await repository.findById(
        'record-v3-active',
      ))!;
      final GenerationRecord awaiting = (await repository.findById(
        'record-v3-awaiting',
      ))!;

      expect(
        active.generationStartedAt?.millisecondsSinceEpoch,
        activeUpdatedAt.millisecondsSinceEpoch,
      );
      expect(awaiting.generationStartedAt, isNull);
    },
  );
}

Future<void> _insertV3Record(
  generated_v3.DatabaseAtV3 database, {
  required String recordId,
  required GenerationRecordPipelineStatus status,
  required DateTime updatedAt,
}) {
  return database
      .into(database.generationRecords)
      .insert(
        RawValuesInsertable<Object?>(<String, Expression<Object>>{
          'record_id': Variable<String>(recordId),
          'created_at': Variable<DateTime>(
            updatedAt.subtract(const Duration(minutes: 5)),
          ),
          'updated_at': Variable<DateTime>(updatedAt),
          'pipeline_status': Variable<String>(status.name),
          'original_source_type': Variable<String>(
            GenerationRecordOriginalSourceType.camera.name,
          ),
          'original_availability': Variable<String>(
            GenerationRecordOriginalAvailability.available.name,
          ),
          'result_availability': Variable<String>(
            GenerationRecordResultAvailability.none.name,
          ),
        }),
      );
}

Future<void> _insertV4Record(
  generated_v4.DatabaseAtV4 database, {
  required String recordId,
  required DateTime createdAt,
}) {
  return database
      .into(database.generationRecords)
      .insert(
        RawValuesInsertable<Object?>(<String, Expression<Object>>{
          'record_id': Variable<String>(recordId),
          'created_at': Variable<DateTime>(createdAt),
          'updated_at': Variable<DateTime>(createdAt),
          'pipeline_status': Variable<String>(
            GenerationRecordPipelineStatus.awaitingConfirmation.name,
          ),
          'original_source_type': Variable<String>(
            GenerationRecordOriginalSourceType.camera.name,
          ),
          'original_availability': Variable<String>(
            GenerationRecordOriginalAvailability.available.name,
          ),
          'result_availability': Variable<String>(
            GenerationRecordResultAvailability.none.name,
          ),
          'original_local_path': Variable<String>('originals/$recordId.heic'),
        }),
      );
}

Future<void> _seedV1Database(File databaseFile) async {
  final generated_v1.DatabaseAtV1 database = generated_v1.DatabaseAtV1(
    NativeDatabase(databaseFile),
  );
  final DateTime createdAt = DateTime.utc(2026, 6, 4, 1, 2, 3);
  final DateTime updatedAt = DateTime.utc(2026, 6, 4, 1, 5);

  await database
      .into(database.generationRecords)
      .insert(
        RawValuesInsertable<Object?>(<String, Expression<Object>>{
          'record_id': const Variable<String>('record-v1-saved'),
          'created_at': Variable<DateTime>(createdAt),
          'updated_at': Variable<DateTime>(updatedAt),
          'pipeline_status': Variable<String>(
            GenerationRecordPipelineStatus.resultSaved.name,
          ),
          'original_source_type': Variable<String>(
            GenerationRecordOriginalSourceType.camera.name,
          ),
          'original_availability': Variable<String>(
            GenerationRecordOriginalAvailability.available.name,
          ),
          'result_availability': Variable<String>(
            GenerationRecordResultAvailability.savedToPhotoLibrary.name,
          ),
          'original_local_path': const Variable<String>(
            'originals/record-v1-saved.heic',
          ),
          'original_asset_id': const Variable<String>('original-asset-v1'),
          'original_captured_at': Variable<DateTime>(createdAt),
          'original_format': const Variable<String>('heic'),
          'original_width': const Variable<int>(4032),
          'original_height': const Variable<int>(3024),
          'upload_session_id': const Variable<String>('upload-v1'),
          'source_image_object_id': const Variable<String>('source-object-v1'),
          'upload_content_type': const Variable<String>('image/jpeg'),
          'upload_size_bytes': const Variable<int>(123456),
          'upload_sha256': const Variable<String>('upload-sha-v1'),
          'task_id': const Variable<String>('task-v1'),
          'task_status': const Variable<String>('completed'),
          'result_image_object_id': const Variable<String>('result-object-v1'),
          'result_local_cache_path': const Variable<String>(
            'cache/result-v1.heic',
          ),
          'result_asset_id': const Variable<String>('result-asset-v1'),
          'result_saved_at': Variable<DateTime>(updatedAt),
          'result_size_bytes': const Variable<int>(654321),
          'result_sha256': const Variable<String>('result-sha-v1'),
          'result_hash_status': Variable<String>(
            GenerationRecordHashStatus.completed.name,
          ),
          'result_is_favorite': const Variable<bool>(true),
          'result_favorited_at': Variable<DateTime>(updatedAt),
          'prompt_style': const Variable<String>('realistic'),
          'capture_mode': const Variable<String>('portrait'),
          'app_input_contract_id': const Variable<String>(
            'app_bundled_2026_06_01',
          ),
          'user_input_json': const Variable<String>('{"prompt":"v1"}'),
          'display_snapshot_json': const Variable<String>(
            '{"mode":"portrait"}',
          ),
        }),
      );
  await database.close();
}

Future<int> _readUserVersion(GenerationRecordDatabase database) async {
  final List<QueryRow> rows = await database
      .customSelect('PRAGMA user_version')
      .get();
  return rows.single.read<int>('user_version');
}
