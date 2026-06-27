import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'generation_record_database.g.dart';

class GenerationRecords extends Table {
  TextColumn get recordId => text()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

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

@DriftDatabase(tables: <Type>[GenerationRecords])
class GenerationRecordDatabase extends _$GenerationRecordDatabase {
  GenerationRecordDatabase() : super(_openConnection());

  GenerationRecordDatabase.forExecutor(super.executor);

  @override
  int get schemaVersion => 1;
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
