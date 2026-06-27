import 'package:drift/drift.dart';

import '../domain/generation_record.dart';
import 'generation_record_database.dart';

class GenerationRecordRepository {
  const GenerationRecordRepository(this._database);

  final GenerationRecordDatabase _database;

  Stream<List<GenerationRecord>> watchRecords() {
    final SimpleSelectStatement<$GenerationRecordsTable, GenerationRecord>
    query = _database.select(_database.generationRecords)
      ..orderBy(<OrderingTerm Function($GenerationRecordsTable)>[
        ($GenerationRecordsTable table) =>
            OrderingTerm(expression: table.createdAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  Future<List<GenerationRecord>> listRecords() {
    final SimpleSelectStatement<$GenerationRecordsTable, GenerationRecord>
    query = _database.select(_database.generationRecords)
      ..orderBy(<OrderingTerm Function($GenerationRecordsTable)>[
        ($GenerationRecordsTable table) =>
            OrderingTerm(expression: table.createdAt, mode: OrderingMode.desc),
      ]);
    return query.get();
  }

  Future<List<GenerationRecord>> listActiveRecords() async {
    final List<GenerationRecord> records = await listRecords();
    return records
        .where((GenerationRecord record) {
          return activeGenerationRecordStatuses.contains(
            generationRecordPipelineStatusFromName(record.pipelineStatus),
          );
        })
        .toList(growable: false);
  }

  Stream<List<GenerationRecord>> watchActiveRecords() {
    return watchRecords().map((List<GenerationRecord> records) {
      return records
          .where((GenerationRecord record) {
            return activeGenerationRecordStatuses.contains(
              generationRecordPipelineStatusFromName(record.pipelineStatus),
            );
          })
          .toList(growable: false);
    });
  }

  Stream<List<GenerationRecord>> watchPairRecords() {
    return watchRecords().map((List<GenerationRecord> records) {
      return records
          .where((GenerationRecord record) {
            return record.originalAvailability !=
                    GenerationRecordOriginalAvailability.missing.name ||
                record.resultAvailability !=
                    GenerationRecordResultAvailability.none.name;
          })
          .toList(growable: false);
    });
  }

  Future<GenerationRecord?> findById(String recordId) {
    return (_database.select(_database.generationRecords)..where(
          ($GenerationRecordsTable table) => table.recordId.equals(recordId),
        ))
        .getSingleOrNull();
  }

  Future<void> createCameraRecord({
    required String recordId,
    required String originalLocalPath,
    required DateTime createdAt,
    DateTime? originalCapturedAt,
    String? originalFormat,
    int? originalWidth,
    int? originalHeight,
    String? promptStyle,
    String? captureMode,
    String? appInputContractId,
    String? userInputJson,
    String? displaySnapshotJson,
  }) {
    return _database
        .into(_database.generationRecords)
        .insert(
          GenerationRecordsCompanion.insert(
            recordId: recordId,
            createdAt: createdAt,
            updatedAt: createdAt,
            pipelineStatus:
                GenerationRecordPipelineStatus.awaitingConfirmation.name,
            originalSourceType: GenerationRecordOriginalSourceType.camera.name,
            originalAvailability:
                GenerationRecordOriginalAvailability.available.name,
            resultAvailability: GenerationRecordResultAvailability.none.name,
            originalLocalPath: Value<String?>(originalLocalPath),
            originalCapturedAt: Value<DateTime?>(originalCapturedAt),
            originalFormat: Value<String?>(originalFormat),
            originalWidth: Value<int?>(originalWidth),
            originalHeight: Value<int?>(originalHeight),
            originalHashStatus: Value<String?>(
              GenerationRecordHashStatus.pending.name,
            ),
            promptStyle: Value<String?>(promptStyle),
            captureMode: Value<String?>(captureMode),
            appInputContractId: Value<String?>(appInputContractId),
            userInputJson: Value<String?>(userInputJson),
            displaySnapshotJson: Value<String?>(displaySnapshotJson),
          ),
        );
  }

  Future<void> createGalleryRecord({
    required String recordId,
    required DateTime createdAt,
    String? originalAssetId,
    DateTime? originalCapturedAt,
    String? originalFormat,
    int? originalWidth,
    int? originalHeight,
    String? promptStyle,
    String? captureMode,
    String? appInputContractId,
    String? userInputJson,
    String? displaySnapshotJson,
  }) {
    return _database
        .into(_database.generationRecords)
        .insert(
          GenerationRecordsCompanion.insert(
            recordId: recordId,
            createdAt: createdAt,
            updatedAt: createdAt,
            pipelineStatus:
                GenerationRecordPipelineStatus.awaitingConfirmation.name,
            originalSourceType: GenerationRecordOriginalSourceType.gallery.name,
            originalAvailability:
                GenerationRecordOriginalAvailability.external.name,
            resultAvailability: GenerationRecordResultAvailability.none.name,
            originalAssetId: Value<String?>(originalAssetId),
            originalCapturedAt: Value<DateTime?>(originalCapturedAt),
            originalFormat: Value<String?>(originalFormat),
            originalWidth: Value<int?>(originalWidth),
            originalHeight: Value<int?>(originalHeight),
            promptStyle: Value<String?>(promptStyle),
            captureMode: Value<String?>(captureMode),
            appInputContractId: Value<String?>(appInputContractId),
            userInputJson: Value<String?>(userInputJson),
            displaySnapshotJson: Value<String?>(displaySnapshotJson),
          ),
        );
  }

  Future<void> createLocalOriginalSaveFailedRecord({
    required String recordId,
    required DateTime createdAt,
    required String errorCode,
    required String errorMessage,
    String? promptStyle,
    String? captureMode,
    String? appInputContractId,
    String? userInputJson,
    String? displaySnapshotJson,
  }) {
    return _database
        .into(_database.generationRecords)
        .insert(
          GenerationRecordsCompanion.insert(
            recordId: recordId,
            createdAt: createdAt,
            updatedAt: createdAt,
            pipelineStatus:
                GenerationRecordPipelineStatus.localOriginalSaveFailed.name,
            originalSourceType: GenerationRecordOriginalSourceType.camera.name,
            originalAvailability:
                GenerationRecordOriginalAvailability.missing.name,
            resultAvailability: GenerationRecordResultAvailability.none.name,
            promptStyle: Value<String?>(promptStyle),
            captureMode: Value<String?>(captureMode),
            appInputContractId: Value<String?>(appInputContractId),
            userInputJson: Value<String?>(userInputJson),
            displaySnapshotJson: Value<String?>(displaySnapshotJson),
            errorCode: Value<String?>(errorCode),
            errorMessage: Value<String?>(errorMessage),
            failureStage: Value<String?>(
              GenerationRecordFailureStage.local.name,
            ),
            failureRetryable: const Value<bool?>(false),
          ),
        );
  }

  Future<void> updatePipelineStatus({
    required String recordId,
    required GenerationRecordPipelineStatus status,
    required DateTime updatedAt,
    String? errorCode,
    String? errorMessage,
    bool clearError = false,
    bool clearFailure = false,
  }) {
    return _updateById(
      recordId,
      GenerationRecordsCompanion(
        updatedAt: Value<DateTime>(updatedAt),
        pipelineStatus: Value<String>(status.name),
        errorCode: clearError
            ? const Value<String?>(null)
            : Value<String?>.absentIfNull(errorCode),
        errorMessage: clearError
            ? const Value<String?>(null)
            : Value<String?>.absentIfNull(errorMessage),
        failureStage: clearFailure
            ? const Value<String?>(null)
            : const Value<String?>.absent(),
        failureRetryable: clearFailure
            ? const Value<bool?>(null)
            : const Value<bool?>.absent(),
      ),
    );
  }

  Future<void> markFailure({
    required String recordId,
    required GenerationRecordPipelineStatus status,
    required GenerationRecordFailureStage failureStage,
    required bool failureRetryable,
    required DateTime updatedAt,
    required String errorCode,
    required String errorMessage,
  }) {
    return _updateById(
      recordId,
      GenerationRecordsCompanion(
        updatedAt: Value<DateTime>(updatedAt),
        pipelineStatus: Value<String>(status.name),
        errorCode: Value<String?>(errorCode),
        errorMessage: Value<String?>(errorMessage),
        failureStage: Value<String?>(failureStage.name),
        failureRetryable: Value<bool?>(failureRetryable),
      ),
    );
  }

  Future<void> updateUploadFields({
    required String recordId,
    required DateTime updatedAt,
    String? uploadSessionId,
    String? sourceImageObjectId,
    String? uploadContentType,
    int? uploadSizeBytes,
    String? uploadSha256,
  }) {
    return _updateById(
      recordId,
      GenerationRecordsCompanion(
        updatedAt: Value<DateTime>(updatedAt),
        uploadSessionId: Value<String?>.absentIfNull(uploadSessionId),
        sourceImageObjectId: Value<String?>.absentIfNull(sourceImageObjectId),
        uploadContentType: Value<String?>.absentIfNull(uploadContentType),
        uploadSizeBytes: Value<int?>.absentIfNull(uploadSizeBytes),
        uploadSha256: Value<String?>.absentIfNull(uploadSha256),
      ),
    );
  }

  Future<void> updateTaskFields({
    required String recordId,
    required DateTime updatedAt,
    String? taskId,
    String? taskStatus,
    String? resultImageObjectId,
  }) {
    return _updateById(
      recordId,
      GenerationRecordsCompanion(
        updatedAt: Value<DateTime>(updatedAt),
        taskId: Value<String?>.absentIfNull(taskId),
        taskStatus: Value<String?>.absentIfNull(taskStatus),
        resultImageObjectId: Value<String?>.absentIfNull(resultImageObjectId),
      ),
    );
  }

  Future<void> updateResultFields({
    required String recordId,
    required DateTime updatedAt,
    GenerationRecordResultAvailability? resultAvailability,
    String? resultImageObjectId,
    String? resultLocalCachePath,
    String? resultAssetId,
    DateTime? resultSavedAt,
    int? resultSizeBytes,
    String? resultSha256,
    GenerationRecordHashStatus? resultHashStatus,
    String? resultHashError,
  }) {
    return _updateById(
      recordId,
      GenerationRecordsCompanion(
        updatedAt: Value<DateTime>(updatedAt),
        resultAvailability: resultAvailability == null
            ? const Value<String>.absent()
            : Value<String>(resultAvailability.name),
        resultImageObjectId: Value<String?>.absentIfNull(resultImageObjectId),
        resultLocalCachePath: Value<String?>.absentIfNull(resultLocalCachePath),
        resultAssetId: Value<String?>.absentIfNull(resultAssetId),
        resultSavedAt: Value<DateTime?>.absentIfNull(resultSavedAt),
        resultSizeBytes: Value<int?>.absentIfNull(resultSizeBytes),
        resultSha256: Value<String?>.absentIfNull(resultSha256),
        resultHashStatus: resultHashStatus == null
            ? const Value<String?>.absent()
            : Value<String?>(resultHashStatus.name),
        resultHashError: Value<String?>.absentIfNull(resultHashError),
      ),
    );
  }

  Future<void> markResultSaved({
    required String recordId,
    required DateTime updatedAt,
    required String resultAssetId,
    String? resultImageObjectId,
    DateTime? resultSavedAt,
    int? resultSizeBytes,
    String? resultSha256,
    GenerationRecordHashStatus? resultHashStatus,
    String? resultHashError,
  }) {
    return _database.transaction(() async {
      await _updateById(
        recordId,
        GenerationRecordsCompanion(
          updatedAt: Value<DateTime>(updatedAt),
          pipelineStatus: Value<String>(
            GenerationRecordPipelineStatus.resultSaved.name,
          ),
          resultAvailability: Value<String>(
            GenerationRecordResultAvailability.savedToPhotoLibrary.name,
          ),
          resultImageObjectId: Value<String?>.absentIfNull(resultImageObjectId),
          resultLocalCachePath: const Value<String?>(null),
          resultAssetId: Value<String?>(resultAssetId),
          resultSavedAt: Value<DateTime?>.absentIfNull(resultSavedAt),
          resultSizeBytes: Value<int?>.absentIfNull(resultSizeBytes),
          resultSha256: Value<String?>.absentIfNull(resultSha256),
          resultHashStatus: resultHashStatus == null
              ? const Value<String?>.absent()
              : Value<String?>(resultHashStatus.name),
          resultHashError: Value<String?>.absentIfNull(resultHashError),
          errorCode: const Value<String?>(null),
          errorMessage: const Value<String?>(null),
          failureStage: const Value<String?>(null),
          failureRetryable: const Value<bool?>(null),
        ),
      );
    });
  }

  Future<void> updateResultFavorite({
    required String recordId,
    required DateTime updatedAt,
    required bool isFavorite,
    DateTime? favoritedAt,
    DateTime? feedbackSubmittedAt,
  }) {
    return _updateById(
      recordId,
      GenerationRecordsCompanion(
        updatedAt: Value<DateTime>(updatedAt),
        resultIsFavorite: Value<bool>(isFavorite),
        resultFavoritedAt: Value<DateTime?>(
          isFavorite ? favoritedAt ?? updatedAt : null,
        ),
        resultFavoriteFeedbackSubmittedAt: feedbackSubmittedAt == null
            ? const Value<DateTime?>.absent()
            : Value<DateTime?>(feedbackSubmittedAt),
      ),
    );
  }

  Future<void> markNegativeFeedbackSubmitted({
    required String recordId,
    required DateTime submittedAt,
  }) {
    return _updateById(
      recordId,
      GenerationRecordsCompanion(
        updatedAt: Value<DateTime>(submittedAt),
        resultNegativeFeedbackSubmittedAt: Value<DateTime?>(submittedAt),
      ),
    );
  }

  Future<void> resetForRetry({
    required String recordId,
    required DateTime updatedAt,
  }) {
    return _updateById(
      recordId,
      GenerationRecordsCompanion(
        updatedAt: Value<DateTime>(updatedAt),
        pipelineStatus: Value<String>(
          GenerationRecordPipelineStatus.awaitingRetry.name,
        ),
        uploadSessionId: const Value<String?>(null),
        sourceImageObjectId: const Value<String?>(null),
        uploadContentType: const Value<String?>(null),
        uploadSizeBytes: const Value<int?>(null),
        uploadSha256: const Value<String?>(null),
        taskId: const Value<String?>(null),
        taskStatus: const Value<String?>(null),
        resultImageObjectId: const Value<String?>(null),
        resultLocalCachePath: const Value<String?>(null),
        resultAssetId: const Value<String?>(null),
        resultSavedAt: const Value<DateTime?>(null),
        resultSizeBytes: const Value<int?>(null),
        resultSha256: const Value<String?>(null),
        resultHashStatus: const Value<String?>(null),
        resultHashError: const Value<String?>(null),
        resultNotificationSeenAt: const Value<DateTime?>(null),
        errorCode: const Value<String?>(null),
        errorMessage: const Value<String?>(null),
        failureStage: const Value<String?>(null),
        failureRetryable: const Value<bool?>(null),
      ),
    );
  }

  Future<void> markOriginalCleared({
    required String recordId,
    required DateTime clearedAt,
  }) {
    return _updateById(
      recordId,
      GenerationRecordsCompanion(
        updatedAt: Value<DateTime>(clearedAt),
        originalLocalPath: const Value<String?>(null),
        originalAvailability: Value<String>(
          GenerationRecordOriginalAvailability.cleared.name,
        ),
        originalClearedAt: Value<DateTime?>(clearedAt),
      ),
    );
  }

  Future<List<GenerationRecord>> listClearableCameraOriginals() async {
    final List<GenerationRecord> candidates =
        await (_database.select(_database.generationRecords)..where(
              ($GenerationRecordsTable table) =>
                  table.originalSourceType.equals(
                    GenerationRecordOriginalSourceType.camera.name,
                  ) &
                  table.originalAvailability.equals(
                    GenerationRecordOriginalAvailability.available.name,
                  ) &
                  table.originalLocalPath.isNotNull(),
            ))
            .get();

    return candidates
        .where((GenerationRecord record) {
          final GenerationRecordPipelineStatus status =
              generationRecordPipelineStatusFromName(record.pipelineStatus);
          return clearableCameraOriginalPipelineStatuses.contains(status);
        })
        .toList(growable: false);
  }

  Future<void> markTerminalResultNotificationsSeen(DateTime seenAt) async {
    await (_database.update(_database.generationRecords)..where(
          ($GenerationRecordsTable table) =>
              table.resultNotificationSeenAt.isNull() &
              table.pipelineStatus.isIn(<String>[
                GenerationRecordPipelineStatus.resultSaved.name,
                GenerationRecordPipelineStatus.submissionFailed.name,
                GenerationRecordPipelineStatus.generationFailed.name,
                GenerationRecordPipelineStatus.resultSaveFailed.name,
              ]),
        ))
        .write(
          GenerationRecordsCompanion(
            resultNotificationSeenAt: Value<DateTime?>(seenAt),
          ),
        );
  }

  Future<void> deleteRecord(String recordId) {
    return (_database.delete(_database.generationRecords)..where(
          ($GenerationRecordsTable table) => table.recordId.equals(recordId),
        ))
        .go();
  }

  Future<void> _updateById(
    String recordId,
    GenerationRecordsCompanion companion,
  ) {
    return (_database.update(_database.generationRecords)..where(
          ($GenerationRecordsTable table) => table.recordId.equals(recordId),
        ))
        .write(companion);
  }
}
