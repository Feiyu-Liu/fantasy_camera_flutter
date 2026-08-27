import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/generation_record.dart';

part 'generation_record_database.g.dart';

class GenerationRecords extends Table {
  TextColumn get recordId => text()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get generationStartedAt => dateTime().nullable()();
  IntColumn get animationIndex => integer().nullable()();

  TextColumn get pipelineStatus => text()();
  TextColumn get originalSourceType => text()();
  TextColumn get originalAvailability => text()();
  TextColumn get resultAvailability => text()();

  TextColumn get originalLocalPath => text().nullable()();
  TextColumn get originalAssetId => text().nullable()();
  DateTimeColumn get originalCapturedAt => dateTime().nullable()();
  TextColumn get originalFormat => text().nullable()();
  IntColumn get originalWidth => integer().nullable()();
  IntColumn get originalHeight => integer().nullable()();
  IntColumn get originalSizeBytes => integer().nullable()();
  TextColumn get originalSha256 => text().nullable()();
  TextColumn get originalHashStatus => text().nullable()();
  TextColumn get originalHashError => text().nullable()();
  DateTimeColumn get originalClearedAt => dateTime().nullable()();

  TextColumn get uploadSessionId => text().nullable()();
  TextColumn get sourceImageObjectId => text().nullable()();
  TextColumn get uploadContentType => text().nullable()();
  IntColumn get uploadSizeBytes => integer().nullable()();
  TextColumn get uploadSha256 => text().nullable()();

  TextColumn get taskId => text().nullable()();
  TextColumn get taskStatus => text().nullable()();

  TextColumn get resultImageObjectId => text().nullable()();
  TextColumn get resultLocalCachePath => text().nullable()();
  TextColumn get resultAssetId => text().nullable()();
  DateTimeColumn get resultSavedAt => dateTime().nullable()();
  IntColumn get resultSizeBytes => integer().nullable()();
  TextColumn get resultSha256 => text().nullable()();
  TextColumn get resultHashStatus => text().nullable()();
  TextColumn get resultHashError => text().nullable()();
  BoolColumn get resultIsFavorite =>
      boolean().withDefault(const Constant<bool>(false))();
  DateTimeColumn get resultFavoritedAt => dateTime().nullable()();
  DateTimeColumn get resultFavoriteFeedbackSubmittedAt =>
      dateTime().nullable()();
  DateTimeColumn get resultNegativeFeedbackSubmittedAt =>
      dateTime().nullable()();

  TextColumn get promptStyle => text().nullable()();
  TextColumn get captureMode => text().nullable()();
  TextColumn get captureAspectRatio => text().nullable()();
  TextColumn get appInputContractId => text().nullable()();
  TextColumn get userInputJson => text().nullable()();
  TextColumn get displaySnapshotJson => text().nullable()();

  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get failureStage => text().nullable()();
  BoolColumn get failureRetryable => boolean().nullable()();
  DateTimeColumn get resultNotificationSeenAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{recordId};
}

class GenerationAnimationSequenceStates extends Table {
  IntColumn get singletonId => integer()();
  IntColumn get nextAnimationIndex => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{singletonId};
}

@DriftDatabase(
  tables: <Type>[GenerationRecords, GenerationAnimationSequenceStates],
)
class GenerationRecordDatabase extends _$GenerationRecordDatabase {
  static const int currentSchemaVersion = 5;

  GenerationRecordDatabase() : super(_openConnection());

  GenerationRecordDatabase.forExecutor(super.executor);

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator migrator) => migrator.createAll(),
      onUpgrade: (Migrator migrator, int from, int to) async {
        for (int version = from; version < to; version += 1) {
          switch (version) {
            case 1:
              await _migrateFrom1To2(migrator);
            case 2:
              await _migrateFrom2To3(migrator);
            case 3:
              await _migrateFrom3To4(migrator);
            case 4:
              await _migrateFrom4To5(migrator);
          }
        }
      },
      beforeOpen: (OpeningDetails details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _migrateFrom1To2(Migrator migrator) async {
    // Schema v2 introduces the explicit migration path before the next
    // generation_records shape change. The table is unchanged from v1.
  }

  Future<void> _migrateFrom2To3(Migrator migrator) async {
    await migrator.addColumn(
      generationRecords,
      generationRecords.captureAspectRatio,
    );
  }

  Future<void> _migrateFrom3To4(Migrator migrator) async {
    await migrator.addColumn(
      generationRecords,
      generationRecords.generationStartedAt,
    );
    await customStatement(
      '''
UPDATE generation_records
SET generation_started_at = updated_at
WHERE generation_started_at IS NULL
  AND pipeline_status NOT IN (?, ?, ?)
''',
      <Object?>[
        GenerationRecordPipelineStatus.awaitingConfirmation.name,
        GenerationRecordPipelineStatus.resultSaved.name,
        GenerationRecordPipelineStatus.canceled.name,
      ],
    );
  }

  Future<void> _migrateFrom4To5(Migrator migrator) async {
    await migrator.addColumn(
      generationRecords,
      generationRecords.animationIndex,
    );
    await migrator.createTable(generationAnimationSequenceStates);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory directory = await getApplicationSupportDirectory();
    final Directory dbDirectory = Directory(
      p.join(directory.path, 'TesserCam'),
    );
    await dbDirectory.create(recursive: true);
    return NativeDatabase(
      File(p.join(dbDirectory.path, 'generation_records.sqlite')),
    );
  });
}
