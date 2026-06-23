// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'generation_record_database.dart';

// ignore_for_file: type=lint
class $GenerationRecordsTable extends GenerationRecords
    with TableInfo<$GenerationRecordsTable, GenerationRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GenerationRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pipelineStatusMeta = const VerificationMeta(
    'pipelineStatus',
  );
  @override
  late final GeneratedColumn<String> pipelineStatus = GeneratedColumn<String>(
    'pipeline_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalSourceTypeMeta =
      const VerificationMeta('originalSourceType');
  @override
  late final GeneratedColumn<String> originalSourceType =
      GeneratedColumn<String>(
        'original_source_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _originalAvailabilityMeta =
      const VerificationMeta('originalAvailability');
  @override
  late final GeneratedColumn<String> originalAvailability =
      GeneratedColumn<String>(
        'original_availability',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _resultAvailabilityMeta =
      const VerificationMeta('resultAvailability');
  @override
  late final GeneratedColumn<String> resultAvailability =
      GeneratedColumn<String>(
        'result_availability',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _originalLocalPathMeta = const VerificationMeta(
    'originalLocalPath',
  );
  @override
  late final GeneratedColumn<String> originalLocalPath =
      GeneratedColumn<String>(
        'original_local_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _originalAssetIdMeta = const VerificationMeta(
    'originalAssetId',
  );
  @override
  late final GeneratedColumn<String> originalAssetId = GeneratedColumn<String>(
    'original_asset_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalCapturedAtMeta =
      const VerificationMeta('originalCapturedAt');
  @override
  late final GeneratedColumn<DateTime> originalCapturedAt =
      GeneratedColumn<DateTime>(
        'original_captured_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _originalFormatMeta = const VerificationMeta(
    'originalFormat',
  );
  @override
  late final GeneratedColumn<String> originalFormat = GeneratedColumn<String>(
    'original_format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalWidthMeta = const VerificationMeta(
    'originalWidth',
  );
  @override
  late final GeneratedColumn<int> originalWidth = GeneratedColumn<int>(
    'original_width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalHeightMeta = const VerificationMeta(
    'originalHeight',
  );
  @override
  late final GeneratedColumn<int> originalHeight = GeneratedColumn<int>(
    'original_height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalSizeBytesMeta = const VerificationMeta(
    'originalSizeBytes',
  );
  @override
  late final GeneratedColumn<int> originalSizeBytes = GeneratedColumn<int>(
    'original_size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalSha256Meta = const VerificationMeta(
    'originalSha256',
  );
  @override
  late final GeneratedColumn<String> originalSha256 = GeneratedColumn<String>(
    'original_sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalHashStatusMeta =
      const VerificationMeta('originalHashStatus');
  @override
  late final GeneratedColumn<String> originalHashStatus =
      GeneratedColumn<String>(
        'original_hash_status',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _originalHashErrorMeta = const VerificationMeta(
    'originalHashError',
  );
  @override
  late final GeneratedColumn<String> originalHashError =
      GeneratedColumn<String>(
        'original_hash_error',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _originalClearedAtMeta = const VerificationMeta(
    'originalClearedAt',
  );
  @override
  late final GeneratedColumn<DateTime> originalClearedAt =
      GeneratedColumn<DateTime>(
        'original_cleared_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _uploadSessionIdMeta = const VerificationMeta(
    'uploadSessionId',
  );
  @override
  late final GeneratedColumn<String> uploadSessionId = GeneratedColumn<String>(
    'upload_session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceImageObjectIdMeta =
      const VerificationMeta('sourceImageObjectId');
  @override
  late final GeneratedColumn<String> sourceImageObjectId =
      GeneratedColumn<String>(
        'source_image_object_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _uploadContentTypeMeta = const VerificationMeta(
    'uploadContentType',
  );
  @override
  late final GeneratedColumn<String> uploadContentType =
      GeneratedColumn<String>(
        'upload_content_type',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _uploadSizeBytesMeta = const VerificationMeta(
    'uploadSizeBytes',
  );
  @override
  late final GeneratedColumn<int> uploadSizeBytes = GeneratedColumn<int>(
    'upload_size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadSha256Meta = const VerificationMeta(
    'uploadSha256',
  );
  @override
  late final GeneratedColumn<String> uploadSha256 = GeneratedColumn<String>(
    'upload_sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskStatusMeta = const VerificationMeta(
    'taskStatus',
  );
  @override
  late final GeneratedColumn<String> taskStatus = GeneratedColumn<String>(
    'task_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultImageObjectIdMeta =
      const VerificationMeta('resultImageObjectId');
  @override
  late final GeneratedColumn<String> resultImageObjectId =
      GeneratedColumn<String>(
        'result_image_object_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _resultLocalCachePathMeta =
      const VerificationMeta('resultLocalCachePath');
  @override
  late final GeneratedColumn<String> resultLocalCachePath =
      GeneratedColumn<String>(
        'result_local_cache_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _resultAssetIdMeta = const VerificationMeta(
    'resultAssetId',
  );
  @override
  late final GeneratedColumn<String> resultAssetId = GeneratedColumn<String>(
    'result_asset_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultSavedAtMeta = const VerificationMeta(
    'resultSavedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resultSavedAt =
      GeneratedColumn<DateTime>(
        'result_saved_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _resultSizeBytesMeta = const VerificationMeta(
    'resultSizeBytes',
  );
  @override
  late final GeneratedColumn<int> resultSizeBytes = GeneratedColumn<int>(
    'result_size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultSha256Meta = const VerificationMeta(
    'resultSha256',
  );
  @override
  late final GeneratedColumn<String> resultSha256 = GeneratedColumn<String>(
    'result_sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultHashStatusMeta = const VerificationMeta(
    'resultHashStatus',
  );
  @override
  late final GeneratedColumn<String> resultHashStatus = GeneratedColumn<String>(
    'result_hash_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultHashErrorMeta = const VerificationMeta(
    'resultHashError',
  );
  @override
  late final GeneratedColumn<String> resultHashError = GeneratedColumn<String>(
    'result_hash_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultIsFavoriteMeta = const VerificationMeta(
    'resultIsFavorite',
  );
  @override
  late final GeneratedColumn<bool> resultIsFavorite = GeneratedColumn<bool>(
    'result_is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("result_is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant<bool>(false),
  );
  static const VerificationMeta _resultFavoritedAtMeta = const VerificationMeta(
    'resultFavoritedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resultFavoritedAt =
      GeneratedColumn<DateTime>(
        'result_favorited_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _resultFavoriteFeedbackSubmittedAtMeta =
      const VerificationMeta('resultFavoriteFeedbackSubmittedAt');
  @override
  late final GeneratedColumn<DateTime> resultFavoriteFeedbackSubmittedAt =
      GeneratedColumn<DateTime>(
        'result_favorite_feedback_submitted_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _resultNegativeFeedbackSubmittedAtMeta =
      const VerificationMeta('resultNegativeFeedbackSubmittedAt');
  @override
  late final GeneratedColumn<DateTime> resultNegativeFeedbackSubmittedAt =
      GeneratedColumn<DateTime>(
        'result_negative_feedback_submitted_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _promptStyleMeta = const VerificationMeta(
    'promptStyle',
  );
  @override
  late final GeneratedColumn<String> promptStyle = GeneratedColumn<String>(
    'prompt_style',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _captureModeMeta = const VerificationMeta(
    'captureMode',
  );
  @override
  late final GeneratedColumn<String> captureMode = GeneratedColumn<String>(
    'capture_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _appInputContractIdMeta =
      const VerificationMeta('appInputContractId');
  @override
  late final GeneratedColumn<String> appInputContractId =
      GeneratedColumn<String>(
        'app_input_contract_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _userInputJsonMeta = const VerificationMeta(
    'userInputJson',
  );
  @override
  late final GeneratedColumn<String> userInputJson = GeneratedColumn<String>(
    'user_input_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displaySnapshotJsonMeta =
      const VerificationMeta('displaySnapshotJson');
  @override
  late final GeneratedColumn<String> displaySnapshotJson =
      GeneratedColumn<String>(
        'display_snapshot_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultNotificationSeenAtMeta =
      const VerificationMeta('resultNotificationSeenAt');
  @override
  late final GeneratedColumn<DateTime> resultNotificationSeenAt =
      GeneratedColumn<DateTime>(
        'result_notification_seen_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    recordId,
    createdAt,
    updatedAt,
    pipelineStatus,
    originalSourceType,
    originalAvailability,
    resultAvailability,
    originalLocalPath,
    originalAssetId,
    originalCapturedAt,
    originalFormat,
    originalWidth,
    originalHeight,
    originalSizeBytes,
    originalSha256,
    originalHashStatus,
    originalHashError,
    originalClearedAt,
    uploadSessionId,
    sourceImageObjectId,
    uploadContentType,
    uploadSizeBytes,
    uploadSha256,
    taskId,
    taskStatus,
    resultImageObjectId,
    resultLocalCachePath,
    resultAssetId,
    resultSavedAt,
    resultSizeBytes,
    resultSha256,
    resultHashStatus,
    resultHashError,
    resultIsFavorite,
    resultFavoritedAt,
    resultFavoriteFeedbackSubmittedAt,
    resultNegativeFeedbackSubmittedAt,
    promptStyle,
    captureMode,
    appInputContractId,
    userInputJson,
    displaySnapshotJson,
    errorCode,
    errorMessage,
    resultNotificationSeenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'generation_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<GenerationRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('pipeline_status')) {
      context.handle(
        _pipelineStatusMeta,
        pipelineStatus.isAcceptableOrUnknown(
          data['pipeline_status']!,
          _pipelineStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pipelineStatusMeta);
    }
    if (data.containsKey('original_source_type')) {
      context.handle(
        _originalSourceTypeMeta,
        originalSourceType.isAcceptableOrUnknown(
          data['original_source_type']!,
          _originalSourceTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalSourceTypeMeta);
    }
    if (data.containsKey('original_availability')) {
      context.handle(
        _originalAvailabilityMeta,
        originalAvailability.isAcceptableOrUnknown(
          data['original_availability']!,
          _originalAvailabilityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalAvailabilityMeta);
    }
    if (data.containsKey('result_availability')) {
      context.handle(
        _resultAvailabilityMeta,
        resultAvailability.isAcceptableOrUnknown(
          data['result_availability']!,
          _resultAvailabilityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resultAvailabilityMeta);
    }
    if (data.containsKey('original_local_path')) {
      context.handle(
        _originalLocalPathMeta,
        originalLocalPath.isAcceptableOrUnknown(
          data['original_local_path']!,
          _originalLocalPathMeta,
        ),
      );
    }
    if (data.containsKey('original_asset_id')) {
      context.handle(
        _originalAssetIdMeta,
        originalAssetId.isAcceptableOrUnknown(
          data['original_asset_id']!,
          _originalAssetIdMeta,
        ),
      );
    }
    if (data.containsKey('original_captured_at')) {
      context.handle(
        _originalCapturedAtMeta,
        originalCapturedAt.isAcceptableOrUnknown(
          data['original_captured_at']!,
          _originalCapturedAtMeta,
        ),
      );
    }
    if (data.containsKey('original_format')) {
      context.handle(
        _originalFormatMeta,
        originalFormat.isAcceptableOrUnknown(
          data['original_format']!,
          _originalFormatMeta,
        ),
      );
    }
    if (data.containsKey('original_width')) {
      context.handle(
        _originalWidthMeta,
        originalWidth.isAcceptableOrUnknown(
          data['original_width']!,
          _originalWidthMeta,
        ),
      );
    }
    if (data.containsKey('original_height')) {
      context.handle(
        _originalHeightMeta,
        originalHeight.isAcceptableOrUnknown(
          data['original_height']!,
          _originalHeightMeta,
        ),
      );
    }
    if (data.containsKey('original_size_bytes')) {
      context.handle(
        _originalSizeBytesMeta,
        originalSizeBytes.isAcceptableOrUnknown(
          data['original_size_bytes']!,
          _originalSizeBytesMeta,
        ),
      );
    }
    if (data.containsKey('original_sha256')) {
      context.handle(
        _originalSha256Meta,
        originalSha256.isAcceptableOrUnknown(
          data['original_sha256']!,
          _originalSha256Meta,
        ),
      );
    }
    if (data.containsKey('original_hash_status')) {
      context.handle(
        _originalHashStatusMeta,
        originalHashStatus.isAcceptableOrUnknown(
          data['original_hash_status']!,
          _originalHashStatusMeta,
        ),
      );
    }
    if (data.containsKey('original_hash_error')) {
      context.handle(
        _originalHashErrorMeta,
        originalHashError.isAcceptableOrUnknown(
          data['original_hash_error']!,
          _originalHashErrorMeta,
        ),
      );
    }
    if (data.containsKey('original_cleared_at')) {
      context.handle(
        _originalClearedAtMeta,
        originalClearedAt.isAcceptableOrUnknown(
          data['original_cleared_at']!,
          _originalClearedAtMeta,
        ),
      );
    }
    if (data.containsKey('upload_session_id')) {
      context.handle(
        _uploadSessionIdMeta,
        uploadSessionId.isAcceptableOrUnknown(
          data['upload_session_id']!,
          _uploadSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('source_image_object_id')) {
      context.handle(
        _sourceImageObjectIdMeta,
        sourceImageObjectId.isAcceptableOrUnknown(
          data['source_image_object_id']!,
          _sourceImageObjectIdMeta,
        ),
      );
    }
    if (data.containsKey('upload_content_type')) {
      context.handle(
        _uploadContentTypeMeta,
        uploadContentType.isAcceptableOrUnknown(
          data['upload_content_type']!,
          _uploadContentTypeMeta,
        ),
      );
    }
    if (data.containsKey('upload_size_bytes')) {
      context.handle(
        _uploadSizeBytesMeta,
        uploadSizeBytes.isAcceptableOrUnknown(
          data['upload_size_bytes']!,
          _uploadSizeBytesMeta,
        ),
      );
    }
    if (data.containsKey('upload_sha256')) {
      context.handle(
        _uploadSha256Meta,
        uploadSha256.isAcceptableOrUnknown(
          data['upload_sha256']!,
          _uploadSha256Meta,
        ),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('task_status')) {
      context.handle(
        _taskStatusMeta,
        taskStatus.isAcceptableOrUnknown(data['task_status']!, _taskStatusMeta),
      );
    }
    if (data.containsKey('result_image_object_id')) {
      context.handle(
        _resultImageObjectIdMeta,
        resultImageObjectId.isAcceptableOrUnknown(
          data['result_image_object_id']!,
          _resultImageObjectIdMeta,
        ),
      );
    }
    if (data.containsKey('result_local_cache_path')) {
      context.handle(
        _resultLocalCachePathMeta,
        resultLocalCachePath.isAcceptableOrUnknown(
          data['result_local_cache_path']!,
          _resultLocalCachePathMeta,
        ),
      );
    }
    if (data.containsKey('result_asset_id')) {
      context.handle(
        _resultAssetIdMeta,
        resultAssetId.isAcceptableOrUnknown(
          data['result_asset_id']!,
          _resultAssetIdMeta,
        ),
      );
    }
    if (data.containsKey('result_saved_at')) {
      context.handle(
        _resultSavedAtMeta,
        resultSavedAt.isAcceptableOrUnknown(
          data['result_saved_at']!,
          _resultSavedAtMeta,
        ),
      );
    }
    if (data.containsKey('result_size_bytes')) {
      context.handle(
        _resultSizeBytesMeta,
        resultSizeBytes.isAcceptableOrUnknown(
          data['result_size_bytes']!,
          _resultSizeBytesMeta,
        ),
      );
    }
    if (data.containsKey('result_sha256')) {
      context.handle(
        _resultSha256Meta,
        resultSha256.isAcceptableOrUnknown(
          data['result_sha256']!,
          _resultSha256Meta,
        ),
      );
    }
    if (data.containsKey('result_hash_status')) {
      context.handle(
        _resultHashStatusMeta,
        resultHashStatus.isAcceptableOrUnknown(
          data['result_hash_status']!,
          _resultHashStatusMeta,
        ),
      );
    }
    if (data.containsKey('result_hash_error')) {
      context.handle(
        _resultHashErrorMeta,
        resultHashError.isAcceptableOrUnknown(
          data['result_hash_error']!,
          _resultHashErrorMeta,
        ),
      );
    }
    if (data.containsKey('result_is_favorite')) {
      context.handle(
        _resultIsFavoriteMeta,
        resultIsFavorite.isAcceptableOrUnknown(
          data['result_is_favorite']!,
          _resultIsFavoriteMeta,
        ),
      );
    }
    if (data.containsKey('result_favorited_at')) {
      context.handle(
        _resultFavoritedAtMeta,
        resultFavoritedAt.isAcceptableOrUnknown(
          data['result_favorited_at']!,
          _resultFavoritedAtMeta,
        ),
      );
    }
    if (data.containsKey('result_favorite_feedback_submitted_at')) {
      context.handle(
        _resultFavoriteFeedbackSubmittedAtMeta,
        resultFavoriteFeedbackSubmittedAt.isAcceptableOrUnknown(
          data['result_favorite_feedback_submitted_at']!,
          _resultFavoriteFeedbackSubmittedAtMeta,
        ),
      );
    }
    if (data.containsKey('result_negative_feedback_submitted_at')) {
      context.handle(
        _resultNegativeFeedbackSubmittedAtMeta,
        resultNegativeFeedbackSubmittedAt.isAcceptableOrUnknown(
          data['result_negative_feedback_submitted_at']!,
          _resultNegativeFeedbackSubmittedAtMeta,
        ),
      );
    }
    if (data.containsKey('prompt_style')) {
      context.handle(
        _promptStyleMeta,
        promptStyle.isAcceptableOrUnknown(
          data['prompt_style']!,
          _promptStyleMeta,
        ),
      );
    }
    if (data.containsKey('capture_mode')) {
      context.handle(
        _captureModeMeta,
        captureMode.isAcceptableOrUnknown(
          data['capture_mode']!,
          _captureModeMeta,
        ),
      );
    }
    if (data.containsKey('app_input_contract_id')) {
      context.handle(
        _appInputContractIdMeta,
        appInputContractId.isAcceptableOrUnknown(
          data['app_input_contract_id']!,
          _appInputContractIdMeta,
        ),
      );
    }
    if (data.containsKey('user_input_json')) {
      context.handle(
        _userInputJsonMeta,
        userInputJson.isAcceptableOrUnknown(
          data['user_input_json']!,
          _userInputJsonMeta,
        ),
      );
    }
    if (data.containsKey('display_snapshot_json')) {
      context.handle(
        _displaySnapshotJsonMeta,
        displaySnapshotJson.isAcceptableOrUnknown(
          data['display_snapshot_json']!,
          _displaySnapshotJsonMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('result_notification_seen_at')) {
      context.handle(
        _resultNotificationSeenAtMeta,
        resultNotificationSeenAt.isAcceptableOrUnknown(
          data['result_notification_seen_at']!,
          _resultNotificationSeenAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recordId};
  @override
  GenerationRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GenerationRecord(
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      pipelineStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pipeline_status'],
      )!,
      originalSourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_source_type'],
      )!,
      originalAvailability: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_availability'],
      )!,
      resultAvailability: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_availability'],
      )!,
      originalLocalPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_local_path'],
      ),
      originalAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_asset_id'],
      ),
      originalCapturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}original_captured_at'],
      ),
      originalFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_format'],
      ),
      originalWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}original_width'],
      ),
      originalHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}original_height'],
      ),
      originalSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}original_size_bytes'],
      ),
      originalSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_sha256'],
      ),
      originalHashStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_hash_status'],
      ),
      originalHashError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_hash_error'],
      ),
      originalClearedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}original_cleared_at'],
      ),
      uploadSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_session_id'],
      ),
      sourceImageObjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_image_object_id'],
      ),
      uploadContentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_content_type'],
      ),
      uploadSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}upload_size_bytes'],
      ),
      uploadSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_sha256'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      taskStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_status'],
      ),
      resultImageObjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_image_object_id'],
      ),
      resultLocalCachePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_local_cache_path'],
      ),
      resultAssetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_asset_id'],
      ),
      resultSavedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}result_saved_at'],
      ),
      resultSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}result_size_bytes'],
      ),
      resultSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_sha256'],
      ),
      resultHashStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_hash_status'],
      ),
      resultHashError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_hash_error'],
      ),
      resultIsFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}result_is_favorite'],
      )!,
      resultFavoritedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}result_favorited_at'],
      ),
      resultFavoriteFeedbackSubmittedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}result_favorite_feedback_submitted_at'],
      ),
      resultNegativeFeedbackSubmittedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}result_negative_feedback_submitted_at'],
      ),
      promptStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt_style'],
      ),
      captureMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capture_mode'],
      ),
      appInputContractId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_input_contract_id'],
      ),
      userInputJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_input_json'],
      ),
      displaySnapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_snapshot_json'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      resultNotificationSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}result_notification_seen_at'],
      ),
    );
  }

  @override
  $GenerationRecordsTable createAlias(String alias) {
    return $GenerationRecordsTable(attachedDatabase, alias);
  }
}

class GenerationRecord extends DataClass
    implements Insertable<GenerationRecord> {
  final String recordId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String pipelineStatus;
  final String originalSourceType;
  final String originalAvailability;
  final String resultAvailability;
  final String? originalLocalPath;
  final String? originalAssetId;
  final DateTime? originalCapturedAt;
  final String? originalFormat;
  final int? originalWidth;
  final int? originalHeight;
  final int? originalSizeBytes;
  final String? originalSha256;
  final String? originalHashStatus;
  final String? originalHashError;
  final DateTime? originalClearedAt;
  final String? uploadSessionId;
  final String? sourceImageObjectId;
  final String? uploadContentType;
  final int? uploadSizeBytes;
  final String? uploadSha256;
  final String? taskId;
  final String? taskStatus;
  final String? resultImageObjectId;
  final String? resultLocalCachePath;
  final String? resultAssetId;
  final DateTime? resultSavedAt;
  final int? resultSizeBytes;
  final String? resultSha256;
  final String? resultHashStatus;
  final String? resultHashError;
  final bool resultIsFavorite;
  final DateTime? resultFavoritedAt;
  final DateTime? resultFavoriteFeedbackSubmittedAt;
  final DateTime? resultNegativeFeedbackSubmittedAt;
  final String? promptStyle;
  final String? captureMode;
  final String? appInputContractId;
  final String? userInputJson;
  final String? displaySnapshotJson;
  final String? errorCode;
  final String? errorMessage;
  final DateTime? resultNotificationSeenAt;
  const GenerationRecord({
    required this.recordId,
    required this.createdAt,
    required this.updatedAt,
    required this.pipelineStatus,
    required this.originalSourceType,
    required this.originalAvailability,
    required this.resultAvailability,
    this.originalLocalPath,
    this.originalAssetId,
    this.originalCapturedAt,
    this.originalFormat,
    this.originalWidth,
    this.originalHeight,
    this.originalSizeBytes,
    this.originalSha256,
    this.originalHashStatus,
    this.originalHashError,
    this.originalClearedAt,
    this.uploadSessionId,
    this.sourceImageObjectId,
    this.uploadContentType,
    this.uploadSizeBytes,
    this.uploadSha256,
    this.taskId,
    this.taskStatus,
    this.resultImageObjectId,
    this.resultLocalCachePath,
    this.resultAssetId,
    this.resultSavedAt,
    this.resultSizeBytes,
    this.resultSha256,
    this.resultHashStatus,
    this.resultHashError,
    required this.resultIsFavorite,
    this.resultFavoritedAt,
    this.resultFavoriteFeedbackSubmittedAt,
    this.resultNegativeFeedbackSubmittedAt,
    this.promptStyle,
    this.captureMode,
    this.appInputContractId,
    this.userInputJson,
    this.displaySnapshotJson,
    this.errorCode,
    this.errorMessage,
    this.resultNotificationSeenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['record_id'] = Variable<String>(recordId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['pipeline_status'] = Variable<String>(pipelineStatus);
    map['original_source_type'] = Variable<String>(originalSourceType);
    map['original_availability'] = Variable<String>(originalAvailability);
    map['result_availability'] = Variable<String>(resultAvailability);
    if (!nullToAbsent || originalLocalPath != null) {
      map['original_local_path'] = Variable<String>(originalLocalPath);
    }
    if (!nullToAbsent || originalAssetId != null) {
      map['original_asset_id'] = Variable<String>(originalAssetId);
    }
    if (!nullToAbsent || originalCapturedAt != null) {
      map['original_captured_at'] = Variable<DateTime>(originalCapturedAt);
    }
    if (!nullToAbsent || originalFormat != null) {
      map['original_format'] = Variable<String>(originalFormat);
    }
    if (!nullToAbsent || originalWidth != null) {
      map['original_width'] = Variable<int>(originalWidth);
    }
    if (!nullToAbsent || originalHeight != null) {
      map['original_height'] = Variable<int>(originalHeight);
    }
    if (!nullToAbsent || originalSizeBytes != null) {
      map['original_size_bytes'] = Variable<int>(originalSizeBytes);
    }
    if (!nullToAbsent || originalSha256 != null) {
      map['original_sha256'] = Variable<String>(originalSha256);
    }
    if (!nullToAbsent || originalHashStatus != null) {
      map['original_hash_status'] = Variable<String>(originalHashStatus);
    }
    if (!nullToAbsent || originalHashError != null) {
      map['original_hash_error'] = Variable<String>(originalHashError);
    }
    if (!nullToAbsent || originalClearedAt != null) {
      map['original_cleared_at'] = Variable<DateTime>(originalClearedAt);
    }
    if (!nullToAbsent || uploadSessionId != null) {
      map['upload_session_id'] = Variable<String>(uploadSessionId);
    }
    if (!nullToAbsent || sourceImageObjectId != null) {
      map['source_image_object_id'] = Variable<String>(sourceImageObjectId);
    }
    if (!nullToAbsent || uploadContentType != null) {
      map['upload_content_type'] = Variable<String>(uploadContentType);
    }
    if (!nullToAbsent || uploadSizeBytes != null) {
      map['upload_size_bytes'] = Variable<int>(uploadSizeBytes);
    }
    if (!nullToAbsent || uploadSha256 != null) {
      map['upload_sha256'] = Variable<String>(uploadSha256);
    }
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    if (!nullToAbsent || taskStatus != null) {
      map['task_status'] = Variable<String>(taskStatus);
    }
    if (!nullToAbsent || resultImageObjectId != null) {
      map['result_image_object_id'] = Variable<String>(resultImageObjectId);
    }
    if (!nullToAbsent || resultLocalCachePath != null) {
      map['result_local_cache_path'] = Variable<String>(resultLocalCachePath);
    }
    if (!nullToAbsent || resultAssetId != null) {
      map['result_asset_id'] = Variable<String>(resultAssetId);
    }
    if (!nullToAbsent || resultSavedAt != null) {
      map['result_saved_at'] = Variable<DateTime>(resultSavedAt);
    }
    if (!nullToAbsent || resultSizeBytes != null) {
      map['result_size_bytes'] = Variable<int>(resultSizeBytes);
    }
    if (!nullToAbsent || resultSha256 != null) {
      map['result_sha256'] = Variable<String>(resultSha256);
    }
    if (!nullToAbsent || resultHashStatus != null) {
      map['result_hash_status'] = Variable<String>(resultHashStatus);
    }
    if (!nullToAbsent || resultHashError != null) {
      map['result_hash_error'] = Variable<String>(resultHashError);
    }
    map['result_is_favorite'] = Variable<bool>(resultIsFavorite);
    if (!nullToAbsent || resultFavoritedAt != null) {
      map['result_favorited_at'] = Variable<DateTime>(resultFavoritedAt);
    }
    if (!nullToAbsent || resultFavoriteFeedbackSubmittedAt != null) {
      map['result_favorite_feedback_submitted_at'] = Variable<DateTime>(
        resultFavoriteFeedbackSubmittedAt,
      );
    }
    if (!nullToAbsent || resultNegativeFeedbackSubmittedAt != null) {
      map['result_negative_feedback_submitted_at'] = Variable<DateTime>(
        resultNegativeFeedbackSubmittedAt,
      );
    }
    if (!nullToAbsent || promptStyle != null) {
      map['prompt_style'] = Variable<String>(promptStyle);
    }
    if (!nullToAbsent || captureMode != null) {
      map['capture_mode'] = Variable<String>(captureMode);
    }
    if (!nullToAbsent || appInputContractId != null) {
      map['app_input_contract_id'] = Variable<String>(appInputContractId);
    }
    if (!nullToAbsent || userInputJson != null) {
      map['user_input_json'] = Variable<String>(userInputJson);
    }
    if (!nullToAbsent || displaySnapshotJson != null) {
      map['display_snapshot_json'] = Variable<String>(displaySnapshotJson);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || resultNotificationSeenAt != null) {
      map['result_notification_seen_at'] = Variable<DateTime>(
        resultNotificationSeenAt,
      );
    }
    return map;
  }

  GenerationRecordsCompanion toCompanion(bool nullToAbsent) {
    return GenerationRecordsCompanion(
      recordId: Value(recordId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pipelineStatus: Value(pipelineStatus),
      originalSourceType: Value(originalSourceType),
      originalAvailability: Value(originalAvailability),
      resultAvailability: Value(resultAvailability),
      originalLocalPath: originalLocalPath == null && nullToAbsent
          ? const Value.absent()
          : Value(originalLocalPath),
      originalAssetId: originalAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(originalAssetId),
      originalCapturedAt: originalCapturedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(originalCapturedAt),
      originalFormat: originalFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(originalFormat),
      originalWidth: originalWidth == null && nullToAbsent
          ? const Value.absent()
          : Value(originalWidth),
      originalHeight: originalHeight == null && nullToAbsent
          ? const Value.absent()
          : Value(originalHeight),
      originalSizeBytes: originalSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(originalSizeBytes),
      originalSha256: originalSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(originalSha256),
      originalHashStatus: originalHashStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(originalHashStatus),
      originalHashError: originalHashError == null && nullToAbsent
          ? const Value.absent()
          : Value(originalHashError),
      originalClearedAt: originalClearedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(originalClearedAt),
      uploadSessionId: uploadSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadSessionId),
      sourceImageObjectId: sourceImageObjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceImageObjectId),
      uploadContentType: uploadContentType == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadContentType),
      uploadSizeBytes: uploadSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadSizeBytes),
      uploadSha256: uploadSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadSha256),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      taskStatus: taskStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(taskStatus),
      resultImageObjectId: resultImageObjectId == null && nullToAbsent
          ? const Value.absent()
          : Value(resultImageObjectId),
      resultLocalCachePath: resultLocalCachePath == null && nullToAbsent
          ? const Value.absent()
          : Value(resultLocalCachePath),
      resultAssetId: resultAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(resultAssetId),
      resultSavedAt: resultSavedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resultSavedAt),
      resultSizeBytes: resultSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(resultSizeBytes),
      resultSha256: resultSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(resultSha256),
      resultHashStatus: resultHashStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(resultHashStatus),
      resultHashError: resultHashError == null && nullToAbsent
          ? const Value.absent()
          : Value(resultHashError),
      resultIsFavorite: Value(resultIsFavorite),
      resultFavoritedAt: resultFavoritedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resultFavoritedAt),
      resultFavoriteFeedbackSubmittedAt:
          resultFavoriteFeedbackSubmittedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resultFavoriteFeedbackSubmittedAt),
      resultNegativeFeedbackSubmittedAt:
          resultNegativeFeedbackSubmittedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resultNegativeFeedbackSubmittedAt),
      promptStyle: promptStyle == null && nullToAbsent
          ? const Value.absent()
          : Value(promptStyle),
      captureMode: captureMode == null && nullToAbsent
          ? const Value.absent()
          : Value(captureMode),
      appInputContractId: appInputContractId == null && nullToAbsent
          ? const Value.absent()
          : Value(appInputContractId),
      userInputJson: userInputJson == null && nullToAbsent
          ? const Value.absent()
          : Value(userInputJson),
      displaySnapshotJson: displaySnapshotJson == null && nullToAbsent
          ? const Value.absent()
          : Value(displaySnapshotJson),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      resultNotificationSeenAt: resultNotificationSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resultNotificationSeenAt),
    );
  }

  factory GenerationRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GenerationRecord(
      recordId: serializer.fromJson<String>(json['recordId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      pipelineStatus: serializer.fromJson<String>(json['pipelineStatus']),
      originalSourceType: serializer.fromJson<String>(
        json['originalSourceType'],
      ),
      originalAvailability: serializer.fromJson<String>(
        json['originalAvailability'],
      ),
      resultAvailability: serializer.fromJson<String>(
        json['resultAvailability'],
      ),
      originalLocalPath: serializer.fromJson<String?>(
        json['originalLocalPath'],
      ),
      originalAssetId: serializer.fromJson<String?>(json['originalAssetId']),
      originalCapturedAt: serializer.fromJson<DateTime?>(
        json['originalCapturedAt'],
      ),
      originalFormat: serializer.fromJson<String?>(json['originalFormat']),
      originalWidth: serializer.fromJson<int?>(json['originalWidth']),
      originalHeight: serializer.fromJson<int?>(json['originalHeight']),
      originalSizeBytes: serializer.fromJson<int?>(json['originalSizeBytes']),
      originalSha256: serializer.fromJson<String?>(json['originalSha256']),
      originalHashStatus: serializer.fromJson<String?>(
        json['originalHashStatus'],
      ),
      originalHashError: serializer.fromJson<String?>(
        json['originalHashError'],
      ),
      originalClearedAt: serializer.fromJson<DateTime?>(
        json['originalClearedAt'],
      ),
      uploadSessionId: serializer.fromJson<String?>(json['uploadSessionId']),
      sourceImageObjectId: serializer.fromJson<String?>(
        json['sourceImageObjectId'],
      ),
      uploadContentType: serializer.fromJson<String?>(
        json['uploadContentType'],
      ),
      uploadSizeBytes: serializer.fromJson<int?>(json['uploadSizeBytes']),
      uploadSha256: serializer.fromJson<String?>(json['uploadSha256']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      taskStatus: serializer.fromJson<String?>(json['taskStatus']),
      resultImageObjectId: serializer.fromJson<String?>(
        json['resultImageObjectId'],
      ),
      resultLocalCachePath: serializer.fromJson<String?>(
        json['resultLocalCachePath'],
      ),
      resultAssetId: serializer.fromJson<String?>(json['resultAssetId']),
      resultSavedAt: serializer.fromJson<DateTime?>(json['resultSavedAt']),
      resultSizeBytes: serializer.fromJson<int?>(json['resultSizeBytes']),
      resultSha256: serializer.fromJson<String?>(json['resultSha256']),
      resultHashStatus: serializer.fromJson<String?>(json['resultHashStatus']),
      resultHashError: serializer.fromJson<String?>(json['resultHashError']),
      resultIsFavorite: serializer.fromJson<bool>(json['resultIsFavorite']),
      resultFavoritedAt: serializer.fromJson<DateTime?>(
        json['resultFavoritedAt'],
      ),
      resultFavoriteFeedbackSubmittedAt: serializer.fromJson<DateTime?>(
        json['resultFavoriteFeedbackSubmittedAt'],
      ),
      resultNegativeFeedbackSubmittedAt: serializer.fromJson<DateTime?>(
        json['resultNegativeFeedbackSubmittedAt'],
      ),
      promptStyle: serializer.fromJson<String?>(json['promptStyle']),
      captureMode: serializer.fromJson<String?>(json['captureMode']),
      appInputContractId: serializer.fromJson<String?>(
        json['appInputContractId'],
      ),
      userInputJson: serializer.fromJson<String?>(json['userInputJson']),
      displaySnapshotJson: serializer.fromJson<String?>(
        json['displaySnapshotJson'],
      ),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      resultNotificationSeenAt: serializer.fromJson<DateTime?>(
        json['resultNotificationSeenAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recordId': serializer.toJson<String>(recordId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'pipelineStatus': serializer.toJson<String>(pipelineStatus),
      'originalSourceType': serializer.toJson<String>(originalSourceType),
      'originalAvailability': serializer.toJson<String>(originalAvailability),
      'resultAvailability': serializer.toJson<String>(resultAvailability),
      'originalLocalPath': serializer.toJson<String?>(originalLocalPath),
      'originalAssetId': serializer.toJson<String?>(originalAssetId),
      'originalCapturedAt': serializer.toJson<DateTime?>(originalCapturedAt),
      'originalFormat': serializer.toJson<String?>(originalFormat),
      'originalWidth': serializer.toJson<int?>(originalWidth),
      'originalHeight': serializer.toJson<int?>(originalHeight),
      'originalSizeBytes': serializer.toJson<int?>(originalSizeBytes),
      'originalSha256': serializer.toJson<String?>(originalSha256),
      'originalHashStatus': serializer.toJson<String?>(originalHashStatus),
      'originalHashError': serializer.toJson<String?>(originalHashError),
      'originalClearedAt': serializer.toJson<DateTime?>(originalClearedAt),
      'uploadSessionId': serializer.toJson<String?>(uploadSessionId),
      'sourceImageObjectId': serializer.toJson<String?>(sourceImageObjectId),
      'uploadContentType': serializer.toJson<String?>(uploadContentType),
      'uploadSizeBytes': serializer.toJson<int?>(uploadSizeBytes),
      'uploadSha256': serializer.toJson<String?>(uploadSha256),
      'taskId': serializer.toJson<String?>(taskId),
      'taskStatus': serializer.toJson<String?>(taskStatus),
      'resultImageObjectId': serializer.toJson<String?>(resultImageObjectId),
      'resultLocalCachePath': serializer.toJson<String?>(resultLocalCachePath),
      'resultAssetId': serializer.toJson<String?>(resultAssetId),
      'resultSavedAt': serializer.toJson<DateTime?>(resultSavedAt),
      'resultSizeBytes': serializer.toJson<int?>(resultSizeBytes),
      'resultSha256': serializer.toJson<String?>(resultSha256),
      'resultHashStatus': serializer.toJson<String?>(resultHashStatus),
      'resultHashError': serializer.toJson<String?>(resultHashError),
      'resultIsFavorite': serializer.toJson<bool>(resultIsFavorite),
      'resultFavoritedAt': serializer.toJson<DateTime?>(resultFavoritedAt),
      'resultFavoriteFeedbackSubmittedAt': serializer.toJson<DateTime?>(
        resultFavoriteFeedbackSubmittedAt,
      ),
      'resultNegativeFeedbackSubmittedAt': serializer.toJson<DateTime?>(
        resultNegativeFeedbackSubmittedAt,
      ),
      'promptStyle': serializer.toJson<String?>(promptStyle),
      'captureMode': serializer.toJson<String?>(captureMode),
      'appInputContractId': serializer.toJson<String?>(appInputContractId),
      'userInputJson': serializer.toJson<String?>(userInputJson),
      'displaySnapshotJson': serializer.toJson<String?>(displaySnapshotJson),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'resultNotificationSeenAt': serializer.toJson<DateTime?>(
        resultNotificationSeenAt,
      ),
    };
  }

  GenerationRecord copyWith({
    String? recordId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? pipelineStatus,
    String? originalSourceType,
    String? originalAvailability,
    String? resultAvailability,
    Value<String?> originalLocalPath = const Value.absent(),
    Value<String?> originalAssetId = const Value.absent(),
    Value<DateTime?> originalCapturedAt = const Value.absent(),
    Value<String?> originalFormat = const Value.absent(),
    Value<int?> originalWidth = const Value.absent(),
    Value<int?> originalHeight = const Value.absent(),
    Value<int?> originalSizeBytes = const Value.absent(),
    Value<String?> originalSha256 = const Value.absent(),
    Value<String?> originalHashStatus = const Value.absent(),
    Value<String?> originalHashError = const Value.absent(),
    Value<DateTime?> originalClearedAt = const Value.absent(),
    Value<String?> uploadSessionId = const Value.absent(),
    Value<String?> sourceImageObjectId = const Value.absent(),
    Value<String?> uploadContentType = const Value.absent(),
    Value<int?> uploadSizeBytes = const Value.absent(),
    Value<String?> uploadSha256 = const Value.absent(),
    Value<String?> taskId = const Value.absent(),
    Value<String?> taskStatus = const Value.absent(),
    Value<String?> resultImageObjectId = const Value.absent(),
    Value<String?> resultLocalCachePath = const Value.absent(),
    Value<String?> resultAssetId = const Value.absent(),
    Value<DateTime?> resultSavedAt = const Value.absent(),
    Value<int?> resultSizeBytes = const Value.absent(),
    Value<String?> resultSha256 = const Value.absent(),
    Value<String?> resultHashStatus = const Value.absent(),
    Value<String?> resultHashError = const Value.absent(),
    bool? resultIsFavorite,
    Value<DateTime?> resultFavoritedAt = const Value.absent(),
    Value<DateTime?> resultFavoriteFeedbackSubmittedAt = const Value.absent(),
    Value<DateTime?> resultNegativeFeedbackSubmittedAt = const Value.absent(),
    Value<String?> promptStyle = const Value.absent(),
    Value<String?> captureMode = const Value.absent(),
    Value<String?> appInputContractId = const Value.absent(),
    Value<String?> userInputJson = const Value.absent(),
    Value<String?> displaySnapshotJson = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    Value<DateTime?> resultNotificationSeenAt = const Value.absent(),
  }) => GenerationRecord(
    recordId: recordId ?? this.recordId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    pipelineStatus: pipelineStatus ?? this.pipelineStatus,
    originalSourceType: originalSourceType ?? this.originalSourceType,
    originalAvailability: originalAvailability ?? this.originalAvailability,
    resultAvailability: resultAvailability ?? this.resultAvailability,
    originalLocalPath: originalLocalPath.present
        ? originalLocalPath.value
        : this.originalLocalPath,
    originalAssetId: originalAssetId.present
        ? originalAssetId.value
        : this.originalAssetId,
    originalCapturedAt: originalCapturedAt.present
        ? originalCapturedAt.value
        : this.originalCapturedAt,
    originalFormat: originalFormat.present
        ? originalFormat.value
        : this.originalFormat,
    originalWidth: originalWidth.present
        ? originalWidth.value
        : this.originalWidth,
    originalHeight: originalHeight.present
        ? originalHeight.value
        : this.originalHeight,
    originalSizeBytes: originalSizeBytes.present
        ? originalSizeBytes.value
        : this.originalSizeBytes,
    originalSha256: originalSha256.present
        ? originalSha256.value
        : this.originalSha256,
    originalHashStatus: originalHashStatus.present
        ? originalHashStatus.value
        : this.originalHashStatus,
    originalHashError: originalHashError.present
        ? originalHashError.value
        : this.originalHashError,
    originalClearedAt: originalClearedAt.present
        ? originalClearedAt.value
        : this.originalClearedAt,
    uploadSessionId: uploadSessionId.present
        ? uploadSessionId.value
        : this.uploadSessionId,
    sourceImageObjectId: sourceImageObjectId.present
        ? sourceImageObjectId.value
        : this.sourceImageObjectId,
    uploadContentType: uploadContentType.present
        ? uploadContentType.value
        : this.uploadContentType,
    uploadSizeBytes: uploadSizeBytes.present
        ? uploadSizeBytes.value
        : this.uploadSizeBytes,
    uploadSha256: uploadSha256.present ? uploadSha256.value : this.uploadSha256,
    taskId: taskId.present ? taskId.value : this.taskId,
    taskStatus: taskStatus.present ? taskStatus.value : this.taskStatus,
    resultImageObjectId: resultImageObjectId.present
        ? resultImageObjectId.value
        : this.resultImageObjectId,
    resultLocalCachePath: resultLocalCachePath.present
        ? resultLocalCachePath.value
        : this.resultLocalCachePath,
    resultAssetId: resultAssetId.present
        ? resultAssetId.value
        : this.resultAssetId,
    resultSavedAt: resultSavedAt.present
        ? resultSavedAt.value
        : this.resultSavedAt,
    resultSizeBytes: resultSizeBytes.present
        ? resultSizeBytes.value
        : this.resultSizeBytes,
    resultSha256: resultSha256.present ? resultSha256.value : this.resultSha256,
    resultHashStatus: resultHashStatus.present
        ? resultHashStatus.value
        : this.resultHashStatus,
    resultHashError: resultHashError.present
        ? resultHashError.value
        : this.resultHashError,
    resultIsFavorite: resultIsFavorite ?? this.resultIsFavorite,
    resultFavoritedAt: resultFavoritedAt.present
        ? resultFavoritedAt.value
        : this.resultFavoritedAt,
    resultFavoriteFeedbackSubmittedAt: resultFavoriteFeedbackSubmittedAt.present
        ? resultFavoriteFeedbackSubmittedAt.value
        : this.resultFavoriteFeedbackSubmittedAt,
    resultNegativeFeedbackSubmittedAt: resultNegativeFeedbackSubmittedAt.present
        ? resultNegativeFeedbackSubmittedAt.value
        : this.resultNegativeFeedbackSubmittedAt,
    promptStyle: promptStyle.present ? promptStyle.value : this.promptStyle,
    captureMode: captureMode.present ? captureMode.value : this.captureMode,
    appInputContractId: appInputContractId.present
        ? appInputContractId.value
        : this.appInputContractId,
    userInputJson: userInputJson.present
        ? userInputJson.value
        : this.userInputJson,
    displaySnapshotJson: displaySnapshotJson.present
        ? displaySnapshotJson.value
        : this.displaySnapshotJson,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    resultNotificationSeenAt: resultNotificationSeenAt.present
        ? resultNotificationSeenAt.value
        : this.resultNotificationSeenAt,
  );
  GenerationRecord copyWithCompanion(GenerationRecordsCompanion data) {
    return GenerationRecord(
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      pipelineStatus: data.pipelineStatus.present
          ? data.pipelineStatus.value
          : this.pipelineStatus,
      originalSourceType: data.originalSourceType.present
          ? data.originalSourceType.value
          : this.originalSourceType,
      originalAvailability: data.originalAvailability.present
          ? data.originalAvailability.value
          : this.originalAvailability,
      resultAvailability: data.resultAvailability.present
          ? data.resultAvailability.value
          : this.resultAvailability,
      originalLocalPath: data.originalLocalPath.present
          ? data.originalLocalPath.value
          : this.originalLocalPath,
      originalAssetId: data.originalAssetId.present
          ? data.originalAssetId.value
          : this.originalAssetId,
      originalCapturedAt: data.originalCapturedAt.present
          ? data.originalCapturedAt.value
          : this.originalCapturedAt,
      originalFormat: data.originalFormat.present
          ? data.originalFormat.value
          : this.originalFormat,
      originalWidth: data.originalWidth.present
          ? data.originalWidth.value
          : this.originalWidth,
      originalHeight: data.originalHeight.present
          ? data.originalHeight.value
          : this.originalHeight,
      originalSizeBytes: data.originalSizeBytes.present
          ? data.originalSizeBytes.value
          : this.originalSizeBytes,
      originalSha256: data.originalSha256.present
          ? data.originalSha256.value
          : this.originalSha256,
      originalHashStatus: data.originalHashStatus.present
          ? data.originalHashStatus.value
          : this.originalHashStatus,
      originalHashError: data.originalHashError.present
          ? data.originalHashError.value
          : this.originalHashError,
      originalClearedAt: data.originalClearedAt.present
          ? data.originalClearedAt.value
          : this.originalClearedAt,
      uploadSessionId: data.uploadSessionId.present
          ? data.uploadSessionId.value
          : this.uploadSessionId,
      sourceImageObjectId: data.sourceImageObjectId.present
          ? data.sourceImageObjectId.value
          : this.sourceImageObjectId,
      uploadContentType: data.uploadContentType.present
          ? data.uploadContentType.value
          : this.uploadContentType,
      uploadSizeBytes: data.uploadSizeBytes.present
          ? data.uploadSizeBytes.value
          : this.uploadSizeBytes,
      uploadSha256: data.uploadSha256.present
          ? data.uploadSha256.value
          : this.uploadSha256,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      taskStatus: data.taskStatus.present
          ? data.taskStatus.value
          : this.taskStatus,
      resultImageObjectId: data.resultImageObjectId.present
          ? data.resultImageObjectId.value
          : this.resultImageObjectId,
      resultLocalCachePath: data.resultLocalCachePath.present
          ? data.resultLocalCachePath.value
          : this.resultLocalCachePath,
      resultAssetId: data.resultAssetId.present
          ? data.resultAssetId.value
          : this.resultAssetId,
      resultSavedAt: data.resultSavedAt.present
          ? data.resultSavedAt.value
          : this.resultSavedAt,
      resultSizeBytes: data.resultSizeBytes.present
          ? data.resultSizeBytes.value
          : this.resultSizeBytes,
      resultSha256: data.resultSha256.present
          ? data.resultSha256.value
          : this.resultSha256,
      resultHashStatus: data.resultHashStatus.present
          ? data.resultHashStatus.value
          : this.resultHashStatus,
      resultHashError: data.resultHashError.present
          ? data.resultHashError.value
          : this.resultHashError,
      resultIsFavorite: data.resultIsFavorite.present
          ? data.resultIsFavorite.value
          : this.resultIsFavorite,
      resultFavoritedAt: data.resultFavoritedAt.present
          ? data.resultFavoritedAt.value
          : this.resultFavoritedAt,
      resultFavoriteFeedbackSubmittedAt:
          data.resultFavoriteFeedbackSubmittedAt.present
          ? data.resultFavoriteFeedbackSubmittedAt.value
          : this.resultFavoriteFeedbackSubmittedAt,
      resultNegativeFeedbackSubmittedAt:
          data.resultNegativeFeedbackSubmittedAt.present
          ? data.resultNegativeFeedbackSubmittedAt.value
          : this.resultNegativeFeedbackSubmittedAt,
      promptStyle: data.promptStyle.present
          ? data.promptStyle.value
          : this.promptStyle,
      captureMode: data.captureMode.present
          ? data.captureMode.value
          : this.captureMode,
      appInputContractId: data.appInputContractId.present
          ? data.appInputContractId.value
          : this.appInputContractId,
      userInputJson: data.userInputJson.present
          ? data.userInputJson.value
          : this.userInputJson,
      displaySnapshotJson: data.displaySnapshotJson.present
          ? data.displaySnapshotJson.value
          : this.displaySnapshotJson,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      resultNotificationSeenAt: data.resultNotificationSeenAt.present
          ? data.resultNotificationSeenAt.value
          : this.resultNotificationSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GenerationRecord(')
          ..write('recordId: $recordId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pipelineStatus: $pipelineStatus, ')
          ..write('originalSourceType: $originalSourceType, ')
          ..write('originalAvailability: $originalAvailability, ')
          ..write('resultAvailability: $resultAvailability, ')
          ..write('originalLocalPath: $originalLocalPath, ')
          ..write('originalAssetId: $originalAssetId, ')
          ..write('originalCapturedAt: $originalCapturedAt, ')
          ..write('originalFormat: $originalFormat, ')
          ..write('originalWidth: $originalWidth, ')
          ..write('originalHeight: $originalHeight, ')
          ..write('originalSizeBytes: $originalSizeBytes, ')
          ..write('originalSha256: $originalSha256, ')
          ..write('originalHashStatus: $originalHashStatus, ')
          ..write('originalHashError: $originalHashError, ')
          ..write('originalClearedAt: $originalClearedAt, ')
          ..write('uploadSessionId: $uploadSessionId, ')
          ..write('sourceImageObjectId: $sourceImageObjectId, ')
          ..write('uploadContentType: $uploadContentType, ')
          ..write('uploadSizeBytes: $uploadSizeBytes, ')
          ..write('uploadSha256: $uploadSha256, ')
          ..write('taskId: $taskId, ')
          ..write('taskStatus: $taskStatus, ')
          ..write('resultImageObjectId: $resultImageObjectId, ')
          ..write('resultLocalCachePath: $resultLocalCachePath, ')
          ..write('resultAssetId: $resultAssetId, ')
          ..write('resultSavedAt: $resultSavedAt, ')
          ..write('resultSizeBytes: $resultSizeBytes, ')
          ..write('resultSha256: $resultSha256, ')
          ..write('resultHashStatus: $resultHashStatus, ')
          ..write('resultHashError: $resultHashError, ')
          ..write('resultIsFavorite: $resultIsFavorite, ')
          ..write('resultFavoritedAt: $resultFavoritedAt, ')
          ..write(
            'resultFavoriteFeedbackSubmittedAt: $resultFavoriteFeedbackSubmittedAt, ',
          )
          ..write(
            'resultNegativeFeedbackSubmittedAt: $resultNegativeFeedbackSubmittedAt, ',
          )
          ..write('promptStyle: $promptStyle, ')
          ..write('captureMode: $captureMode, ')
          ..write('appInputContractId: $appInputContractId, ')
          ..write('userInputJson: $userInputJson, ')
          ..write('displaySnapshotJson: $displaySnapshotJson, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('resultNotificationSeenAt: $resultNotificationSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    recordId,
    createdAt,
    updatedAt,
    pipelineStatus,
    originalSourceType,
    originalAvailability,
    resultAvailability,
    originalLocalPath,
    originalAssetId,
    originalCapturedAt,
    originalFormat,
    originalWidth,
    originalHeight,
    originalSizeBytes,
    originalSha256,
    originalHashStatus,
    originalHashError,
    originalClearedAt,
    uploadSessionId,
    sourceImageObjectId,
    uploadContentType,
    uploadSizeBytes,
    uploadSha256,
    taskId,
    taskStatus,
    resultImageObjectId,
    resultLocalCachePath,
    resultAssetId,
    resultSavedAt,
    resultSizeBytes,
    resultSha256,
    resultHashStatus,
    resultHashError,
    resultIsFavorite,
    resultFavoritedAt,
    resultFavoriteFeedbackSubmittedAt,
    resultNegativeFeedbackSubmittedAt,
    promptStyle,
    captureMode,
    appInputContractId,
    userInputJson,
    displaySnapshotJson,
    errorCode,
    errorMessage,
    resultNotificationSeenAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GenerationRecord &&
          other.recordId == this.recordId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.pipelineStatus == this.pipelineStatus &&
          other.originalSourceType == this.originalSourceType &&
          other.originalAvailability == this.originalAvailability &&
          other.resultAvailability == this.resultAvailability &&
          other.originalLocalPath == this.originalLocalPath &&
          other.originalAssetId == this.originalAssetId &&
          other.originalCapturedAt == this.originalCapturedAt &&
          other.originalFormat == this.originalFormat &&
          other.originalWidth == this.originalWidth &&
          other.originalHeight == this.originalHeight &&
          other.originalSizeBytes == this.originalSizeBytes &&
          other.originalSha256 == this.originalSha256 &&
          other.originalHashStatus == this.originalHashStatus &&
          other.originalHashError == this.originalHashError &&
          other.originalClearedAt == this.originalClearedAt &&
          other.uploadSessionId == this.uploadSessionId &&
          other.sourceImageObjectId == this.sourceImageObjectId &&
          other.uploadContentType == this.uploadContentType &&
          other.uploadSizeBytes == this.uploadSizeBytes &&
          other.uploadSha256 == this.uploadSha256 &&
          other.taskId == this.taskId &&
          other.taskStatus == this.taskStatus &&
          other.resultImageObjectId == this.resultImageObjectId &&
          other.resultLocalCachePath == this.resultLocalCachePath &&
          other.resultAssetId == this.resultAssetId &&
          other.resultSavedAt == this.resultSavedAt &&
          other.resultSizeBytes == this.resultSizeBytes &&
          other.resultSha256 == this.resultSha256 &&
          other.resultHashStatus == this.resultHashStatus &&
          other.resultHashError == this.resultHashError &&
          other.resultIsFavorite == this.resultIsFavorite &&
          other.resultFavoritedAt == this.resultFavoritedAt &&
          other.resultFavoriteFeedbackSubmittedAt ==
              this.resultFavoriteFeedbackSubmittedAt &&
          other.resultNegativeFeedbackSubmittedAt ==
              this.resultNegativeFeedbackSubmittedAt &&
          other.promptStyle == this.promptStyle &&
          other.captureMode == this.captureMode &&
          other.appInputContractId == this.appInputContractId &&
          other.userInputJson == this.userInputJson &&
          other.displaySnapshotJson == this.displaySnapshotJson &&
          other.errorCode == this.errorCode &&
          other.errorMessage == this.errorMessage &&
          other.resultNotificationSeenAt == this.resultNotificationSeenAt);
}

class GenerationRecordsCompanion extends UpdateCompanion<GenerationRecord> {
  final Value<String> recordId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> pipelineStatus;
  final Value<String> originalSourceType;
  final Value<String> originalAvailability;
  final Value<String> resultAvailability;
  final Value<String?> originalLocalPath;
  final Value<String?> originalAssetId;
  final Value<DateTime?> originalCapturedAt;
  final Value<String?> originalFormat;
  final Value<int?> originalWidth;
  final Value<int?> originalHeight;
  final Value<int?> originalSizeBytes;
  final Value<String?> originalSha256;
  final Value<String?> originalHashStatus;
  final Value<String?> originalHashError;
  final Value<DateTime?> originalClearedAt;
  final Value<String?> uploadSessionId;
  final Value<String?> sourceImageObjectId;
  final Value<String?> uploadContentType;
  final Value<int?> uploadSizeBytes;
  final Value<String?> uploadSha256;
  final Value<String?> taskId;
  final Value<String?> taskStatus;
  final Value<String?> resultImageObjectId;
  final Value<String?> resultLocalCachePath;
  final Value<String?> resultAssetId;
  final Value<DateTime?> resultSavedAt;
  final Value<int?> resultSizeBytes;
  final Value<String?> resultSha256;
  final Value<String?> resultHashStatus;
  final Value<String?> resultHashError;
  final Value<bool> resultIsFavorite;
  final Value<DateTime?> resultFavoritedAt;
  final Value<DateTime?> resultFavoriteFeedbackSubmittedAt;
  final Value<DateTime?> resultNegativeFeedbackSubmittedAt;
  final Value<String?> promptStyle;
  final Value<String?> captureMode;
  final Value<String?> appInputContractId;
  final Value<String?> userInputJson;
  final Value<String?> displaySnapshotJson;
  final Value<String?> errorCode;
  final Value<String?> errorMessage;
  final Value<DateTime?> resultNotificationSeenAt;
  final Value<int> rowid;
  const GenerationRecordsCompanion({
    this.recordId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.pipelineStatus = const Value.absent(),
    this.originalSourceType = const Value.absent(),
    this.originalAvailability = const Value.absent(),
    this.resultAvailability = const Value.absent(),
    this.originalLocalPath = const Value.absent(),
    this.originalAssetId = const Value.absent(),
    this.originalCapturedAt = const Value.absent(),
    this.originalFormat = const Value.absent(),
    this.originalWidth = const Value.absent(),
    this.originalHeight = const Value.absent(),
    this.originalSizeBytes = const Value.absent(),
    this.originalSha256 = const Value.absent(),
    this.originalHashStatus = const Value.absent(),
    this.originalHashError = const Value.absent(),
    this.originalClearedAt = const Value.absent(),
    this.uploadSessionId = const Value.absent(),
    this.sourceImageObjectId = const Value.absent(),
    this.uploadContentType = const Value.absent(),
    this.uploadSizeBytes = const Value.absent(),
    this.uploadSha256 = const Value.absent(),
    this.taskId = const Value.absent(),
    this.taskStatus = const Value.absent(),
    this.resultImageObjectId = const Value.absent(),
    this.resultLocalCachePath = const Value.absent(),
    this.resultAssetId = const Value.absent(),
    this.resultSavedAt = const Value.absent(),
    this.resultSizeBytes = const Value.absent(),
    this.resultSha256 = const Value.absent(),
    this.resultHashStatus = const Value.absent(),
    this.resultHashError = const Value.absent(),
    this.resultIsFavorite = const Value.absent(),
    this.resultFavoritedAt = const Value.absent(),
    this.resultFavoriteFeedbackSubmittedAt = const Value.absent(),
    this.resultNegativeFeedbackSubmittedAt = const Value.absent(),
    this.promptStyle = const Value.absent(),
    this.captureMode = const Value.absent(),
    this.appInputContractId = const Value.absent(),
    this.userInputJson = const Value.absent(),
    this.displaySnapshotJson = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.resultNotificationSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GenerationRecordsCompanion.insert({
    required String recordId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String pipelineStatus,
    required String originalSourceType,
    required String originalAvailability,
    required String resultAvailability,
    this.originalLocalPath = const Value.absent(),
    this.originalAssetId = const Value.absent(),
    this.originalCapturedAt = const Value.absent(),
    this.originalFormat = const Value.absent(),
    this.originalWidth = const Value.absent(),
    this.originalHeight = const Value.absent(),
    this.originalSizeBytes = const Value.absent(),
    this.originalSha256 = const Value.absent(),
    this.originalHashStatus = const Value.absent(),
    this.originalHashError = const Value.absent(),
    this.originalClearedAt = const Value.absent(),
    this.uploadSessionId = const Value.absent(),
    this.sourceImageObjectId = const Value.absent(),
    this.uploadContentType = const Value.absent(),
    this.uploadSizeBytes = const Value.absent(),
    this.uploadSha256 = const Value.absent(),
    this.taskId = const Value.absent(),
    this.taskStatus = const Value.absent(),
    this.resultImageObjectId = const Value.absent(),
    this.resultLocalCachePath = const Value.absent(),
    this.resultAssetId = const Value.absent(),
    this.resultSavedAt = const Value.absent(),
    this.resultSizeBytes = const Value.absent(),
    this.resultSha256 = const Value.absent(),
    this.resultHashStatus = const Value.absent(),
    this.resultHashError = const Value.absent(),
    this.resultIsFavorite = const Value.absent(),
    this.resultFavoritedAt = const Value.absent(),
    this.resultFavoriteFeedbackSubmittedAt = const Value.absent(),
    this.resultNegativeFeedbackSubmittedAt = const Value.absent(),
    this.promptStyle = const Value.absent(),
    this.captureMode = const Value.absent(),
    this.appInputContractId = const Value.absent(),
    this.userInputJson = const Value.absent(),
    this.displaySnapshotJson = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.resultNotificationSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : recordId = Value(recordId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       pipelineStatus = Value(pipelineStatus),
       originalSourceType = Value(originalSourceType),
       originalAvailability = Value(originalAvailability),
       resultAvailability = Value(resultAvailability);
  static Insertable<GenerationRecord> custom({
    Expression<String>? recordId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? pipelineStatus,
    Expression<String>? originalSourceType,
    Expression<String>? originalAvailability,
    Expression<String>? resultAvailability,
    Expression<String>? originalLocalPath,
    Expression<String>? originalAssetId,
    Expression<DateTime>? originalCapturedAt,
    Expression<String>? originalFormat,
    Expression<int>? originalWidth,
    Expression<int>? originalHeight,
    Expression<int>? originalSizeBytes,
    Expression<String>? originalSha256,
    Expression<String>? originalHashStatus,
    Expression<String>? originalHashError,
    Expression<DateTime>? originalClearedAt,
    Expression<String>? uploadSessionId,
    Expression<String>? sourceImageObjectId,
    Expression<String>? uploadContentType,
    Expression<int>? uploadSizeBytes,
    Expression<String>? uploadSha256,
    Expression<String>? taskId,
    Expression<String>? taskStatus,
    Expression<String>? resultImageObjectId,
    Expression<String>? resultLocalCachePath,
    Expression<String>? resultAssetId,
    Expression<DateTime>? resultSavedAt,
    Expression<int>? resultSizeBytes,
    Expression<String>? resultSha256,
    Expression<String>? resultHashStatus,
    Expression<String>? resultHashError,
    Expression<bool>? resultIsFavorite,
    Expression<DateTime>? resultFavoritedAt,
    Expression<DateTime>? resultFavoriteFeedbackSubmittedAt,
    Expression<DateTime>? resultNegativeFeedbackSubmittedAt,
    Expression<String>? promptStyle,
    Expression<String>? captureMode,
    Expression<String>? appInputContractId,
    Expression<String>? userInputJson,
    Expression<String>? displaySnapshotJson,
    Expression<String>? errorCode,
    Expression<String>? errorMessage,
    Expression<DateTime>? resultNotificationSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recordId != null) 'record_id': recordId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (pipelineStatus != null) 'pipeline_status': pipelineStatus,
      if (originalSourceType != null)
        'original_source_type': originalSourceType,
      if (originalAvailability != null)
        'original_availability': originalAvailability,
      if (resultAvailability != null) 'result_availability': resultAvailability,
      if (originalLocalPath != null) 'original_local_path': originalLocalPath,
      if (originalAssetId != null) 'original_asset_id': originalAssetId,
      if (originalCapturedAt != null)
        'original_captured_at': originalCapturedAt,
      if (originalFormat != null) 'original_format': originalFormat,
      if (originalWidth != null) 'original_width': originalWidth,
      if (originalHeight != null) 'original_height': originalHeight,
      if (originalSizeBytes != null) 'original_size_bytes': originalSizeBytes,
      if (originalSha256 != null) 'original_sha256': originalSha256,
      if (originalHashStatus != null)
        'original_hash_status': originalHashStatus,
      if (originalHashError != null) 'original_hash_error': originalHashError,
      if (originalClearedAt != null) 'original_cleared_at': originalClearedAt,
      if (uploadSessionId != null) 'upload_session_id': uploadSessionId,
      if (sourceImageObjectId != null)
        'source_image_object_id': sourceImageObjectId,
      if (uploadContentType != null) 'upload_content_type': uploadContentType,
      if (uploadSizeBytes != null) 'upload_size_bytes': uploadSizeBytes,
      if (uploadSha256 != null) 'upload_sha256': uploadSha256,
      if (taskId != null) 'task_id': taskId,
      if (taskStatus != null) 'task_status': taskStatus,
      if (resultImageObjectId != null)
        'result_image_object_id': resultImageObjectId,
      if (resultLocalCachePath != null)
        'result_local_cache_path': resultLocalCachePath,
      if (resultAssetId != null) 'result_asset_id': resultAssetId,
      if (resultSavedAt != null) 'result_saved_at': resultSavedAt,
      if (resultSizeBytes != null) 'result_size_bytes': resultSizeBytes,
      if (resultSha256 != null) 'result_sha256': resultSha256,
      if (resultHashStatus != null) 'result_hash_status': resultHashStatus,
      if (resultHashError != null) 'result_hash_error': resultHashError,
      if (resultIsFavorite != null) 'result_is_favorite': resultIsFavorite,
      if (resultFavoritedAt != null) 'result_favorited_at': resultFavoritedAt,
      if (resultFavoriteFeedbackSubmittedAt != null)
        'result_favorite_feedback_submitted_at':
            resultFavoriteFeedbackSubmittedAt,
      if (resultNegativeFeedbackSubmittedAt != null)
        'result_negative_feedback_submitted_at':
            resultNegativeFeedbackSubmittedAt,
      if (promptStyle != null) 'prompt_style': promptStyle,
      if (captureMode != null) 'capture_mode': captureMode,
      if (appInputContractId != null)
        'app_input_contract_id': appInputContractId,
      if (userInputJson != null) 'user_input_json': userInputJson,
      if (displaySnapshotJson != null)
        'display_snapshot_json': displaySnapshotJson,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
      if (resultNotificationSeenAt != null)
        'result_notification_seen_at': resultNotificationSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GenerationRecordsCompanion copyWith({
    Value<String>? recordId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? pipelineStatus,
    Value<String>? originalSourceType,
    Value<String>? originalAvailability,
    Value<String>? resultAvailability,
    Value<String?>? originalLocalPath,
    Value<String?>? originalAssetId,
    Value<DateTime?>? originalCapturedAt,
    Value<String?>? originalFormat,
    Value<int?>? originalWidth,
    Value<int?>? originalHeight,
    Value<int?>? originalSizeBytes,
    Value<String?>? originalSha256,
    Value<String?>? originalHashStatus,
    Value<String?>? originalHashError,
    Value<DateTime?>? originalClearedAt,
    Value<String?>? uploadSessionId,
    Value<String?>? sourceImageObjectId,
    Value<String?>? uploadContentType,
    Value<int?>? uploadSizeBytes,
    Value<String?>? uploadSha256,
    Value<String?>? taskId,
    Value<String?>? taskStatus,
    Value<String?>? resultImageObjectId,
    Value<String?>? resultLocalCachePath,
    Value<String?>? resultAssetId,
    Value<DateTime?>? resultSavedAt,
    Value<int?>? resultSizeBytes,
    Value<String?>? resultSha256,
    Value<String?>? resultHashStatus,
    Value<String?>? resultHashError,
    Value<bool>? resultIsFavorite,
    Value<DateTime?>? resultFavoritedAt,
    Value<DateTime?>? resultFavoriteFeedbackSubmittedAt,
    Value<DateTime?>? resultNegativeFeedbackSubmittedAt,
    Value<String?>? promptStyle,
    Value<String?>? captureMode,
    Value<String?>? appInputContractId,
    Value<String?>? userInputJson,
    Value<String?>? displaySnapshotJson,
    Value<String?>? errorCode,
    Value<String?>? errorMessage,
    Value<DateTime?>? resultNotificationSeenAt,
    Value<int>? rowid,
  }) {
    return GenerationRecordsCompanion(
      recordId: recordId ?? this.recordId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pipelineStatus: pipelineStatus ?? this.pipelineStatus,
      originalSourceType: originalSourceType ?? this.originalSourceType,
      originalAvailability: originalAvailability ?? this.originalAvailability,
      resultAvailability: resultAvailability ?? this.resultAvailability,
      originalLocalPath: originalLocalPath ?? this.originalLocalPath,
      originalAssetId: originalAssetId ?? this.originalAssetId,
      originalCapturedAt: originalCapturedAt ?? this.originalCapturedAt,
      originalFormat: originalFormat ?? this.originalFormat,
      originalWidth: originalWidth ?? this.originalWidth,
      originalHeight: originalHeight ?? this.originalHeight,
      originalSizeBytes: originalSizeBytes ?? this.originalSizeBytes,
      originalSha256: originalSha256 ?? this.originalSha256,
      originalHashStatus: originalHashStatus ?? this.originalHashStatus,
      originalHashError: originalHashError ?? this.originalHashError,
      originalClearedAt: originalClearedAt ?? this.originalClearedAt,
      uploadSessionId: uploadSessionId ?? this.uploadSessionId,
      sourceImageObjectId: sourceImageObjectId ?? this.sourceImageObjectId,
      uploadContentType: uploadContentType ?? this.uploadContentType,
      uploadSizeBytes: uploadSizeBytes ?? this.uploadSizeBytes,
      uploadSha256: uploadSha256 ?? this.uploadSha256,
      taskId: taskId ?? this.taskId,
      taskStatus: taskStatus ?? this.taskStatus,
      resultImageObjectId: resultImageObjectId ?? this.resultImageObjectId,
      resultLocalCachePath: resultLocalCachePath ?? this.resultLocalCachePath,
      resultAssetId: resultAssetId ?? this.resultAssetId,
      resultSavedAt: resultSavedAt ?? this.resultSavedAt,
      resultSizeBytes: resultSizeBytes ?? this.resultSizeBytes,
      resultSha256: resultSha256 ?? this.resultSha256,
      resultHashStatus: resultHashStatus ?? this.resultHashStatus,
      resultHashError: resultHashError ?? this.resultHashError,
      resultIsFavorite: resultIsFavorite ?? this.resultIsFavorite,
      resultFavoritedAt: resultFavoritedAt ?? this.resultFavoritedAt,
      resultFavoriteFeedbackSubmittedAt:
          resultFavoriteFeedbackSubmittedAt ??
          this.resultFavoriteFeedbackSubmittedAt,
      resultNegativeFeedbackSubmittedAt:
          resultNegativeFeedbackSubmittedAt ??
          this.resultNegativeFeedbackSubmittedAt,
      promptStyle: promptStyle ?? this.promptStyle,
      captureMode: captureMode ?? this.captureMode,
      appInputContractId: appInputContractId ?? this.appInputContractId,
      userInputJson: userInputJson ?? this.userInputJson,
      displaySnapshotJson: displaySnapshotJson ?? this.displaySnapshotJson,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      resultNotificationSeenAt:
          resultNotificationSeenAt ?? this.resultNotificationSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (pipelineStatus.present) {
      map['pipeline_status'] = Variable<String>(pipelineStatus.value);
    }
    if (originalSourceType.present) {
      map['original_source_type'] = Variable<String>(originalSourceType.value);
    }
    if (originalAvailability.present) {
      map['original_availability'] = Variable<String>(
        originalAvailability.value,
      );
    }
    if (resultAvailability.present) {
      map['result_availability'] = Variable<String>(resultAvailability.value);
    }
    if (originalLocalPath.present) {
      map['original_local_path'] = Variable<String>(originalLocalPath.value);
    }
    if (originalAssetId.present) {
      map['original_asset_id'] = Variable<String>(originalAssetId.value);
    }
    if (originalCapturedAt.present) {
      map['original_captured_at'] = Variable<DateTime>(
        originalCapturedAt.value,
      );
    }
    if (originalFormat.present) {
      map['original_format'] = Variable<String>(originalFormat.value);
    }
    if (originalWidth.present) {
      map['original_width'] = Variable<int>(originalWidth.value);
    }
    if (originalHeight.present) {
      map['original_height'] = Variable<int>(originalHeight.value);
    }
    if (originalSizeBytes.present) {
      map['original_size_bytes'] = Variable<int>(originalSizeBytes.value);
    }
    if (originalSha256.present) {
      map['original_sha256'] = Variable<String>(originalSha256.value);
    }
    if (originalHashStatus.present) {
      map['original_hash_status'] = Variable<String>(originalHashStatus.value);
    }
    if (originalHashError.present) {
      map['original_hash_error'] = Variable<String>(originalHashError.value);
    }
    if (originalClearedAt.present) {
      map['original_cleared_at'] = Variable<DateTime>(originalClearedAt.value);
    }
    if (uploadSessionId.present) {
      map['upload_session_id'] = Variable<String>(uploadSessionId.value);
    }
    if (sourceImageObjectId.present) {
      map['source_image_object_id'] = Variable<String>(
        sourceImageObjectId.value,
      );
    }
    if (uploadContentType.present) {
      map['upload_content_type'] = Variable<String>(uploadContentType.value);
    }
    if (uploadSizeBytes.present) {
      map['upload_size_bytes'] = Variable<int>(uploadSizeBytes.value);
    }
    if (uploadSha256.present) {
      map['upload_sha256'] = Variable<String>(uploadSha256.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (taskStatus.present) {
      map['task_status'] = Variable<String>(taskStatus.value);
    }
    if (resultImageObjectId.present) {
      map['result_image_object_id'] = Variable<String>(
        resultImageObjectId.value,
      );
    }
    if (resultLocalCachePath.present) {
      map['result_local_cache_path'] = Variable<String>(
        resultLocalCachePath.value,
      );
    }
    if (resultAssetId.present) {
      map['result_asset_id'] = Variable<String>(resultAssetId.value);
    }
    if (resultSavedAt.present) {
      map['result_saved_at'] = Variable<DateTime>(resultSavedAt.value);
    }
    if (resultSizeBytes.present) {
      map['result_size_bytes'] = Variable<int>(resultSizeBytes.value);
    }
    if (resultSha256.present) {
      map['result_sha256'] = Variable<String>(resultSha256.value);
    }
    if (resultHashStatus.present) {
      map['result_hash_status'] = Variable<String>(resultHashStatus.value);
    }
    if (resultHashError.present) {
      map['result_hash_error'] = Variable<String>(resultHashError.value);
    }
    if (resultIsFavorite.present) {
      map['result_is_favorite'] = Variable<bool>(resultIsFavorite.value);
    }
    if (resultFavoritedAt.present) {
      map['result_favorited_at'] = Variable<DateTime>(resultFavoritedAt.value);
    }
    if (resultFavoriteFeedbackSubmittedAt.present) {
      map['result_favorite_feedback_submitted_at'] = Variable<DateTime>(
        resultFavoriteFeedbackSubmittedAt.value,
      );
    }
    if (resultNegativeFeedbackSubmittedAt.present) {
      map['result_negative_feedback_submitted_at'] = Variable<DateTime>(
        resultNegativeFeedbackSubmittedAt.value,
      );
    }
    if (promptStyle.present) {
      map['prompt_style'] = Variable<String>(promptStyle.value);
    }
    if (captureMode.present) {
      map['capture_mode'] = Variable<String>(captureMode.value);
    }
    if (appInputContractId.present) {
      map['app_input_contract_id'] = Variable<String>(appInputContractId.value);
    }
    if (userInputJson.present) {
      map['user_input_json'] = Variable<String>(userInputJson.value);
    }
    if (displaySnapshotJson.present) {
      map['display_snapshot_json'] = Variable<String>(
        displaySnapshotJson.value,
      );
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (resultNotificationSeenAt.present) {
      map['result_notification_seen_at'] = Variable<DateTime>(
        resultNotificationSeenAt.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GenerationRecordsCompanion(')
          ..write('recordId: $recordId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pipelineStatus: $pipelineStatus, ')
          ..write('originalSourceType: $originalSourceType, ')
          ..write('originalAvailability: $originalAvailability, ')
          ..write('resultAvailability: $resultAvailability, ')
          ..write('originalLocalPath: $originalLocalPath, ')
          ..write('originalAssetId: $originalAssetId, ')
          ..write('originalCapturedAt: $originalCapturedAt, ')
          ..write('originalFormat: $originalFormat, ')
          ..write('originalWidth: $originalWidth, ')
          ..write('originalHeight: $originalHeight, ')
          ..write('originalSizeBytes: $originalSizeBytes, ')
          ..write('originalSha256: $originalSha256, ')
          ..write('originalHashStatus: $originalHashStatus, ')
          ..write('originalHashError: $originalHashError, ')
          ..write('originalClearedAt: $originalClearedAt, ')
          ..write('uploadSessionId: $uploadSessionId, ')
          ..write('sourceImageObjectId: $sourceImageObjectId, ')
          ..write('uploadContentType: $uploadContentType, ')
          ..write('uploadSizeBytes: $uploadSizeBytes, ')
          ..write('uploadSha256: $uploadSha256, ')
          ..write('taskId: $taskId, ')
          ..write('taskStatus: $taskStatus, ')
          ..write('resultImageObjectId: $resultImageObjectId, ')
          ..write('resultLocalCachePath: $resultLocalCachePath, ')
          ..write('resultAssetId: $resultAssetId, ')
          ..write('resultSavedAt: $resultSavedAt, ')
          ..write('resultSizeBytes: $resultSizeBytes, ')
          ..write('resultSha256: $resultSha256, ')
          ..write('resultHashStatus: $resultHashStatus, ')
          ..write('resultHashError: $resultHashError, ')
          ..write('resultIsFavorite: $resultIsFavorite, ')
          ..write('resultFavoritedAt: $resultFavoritedAt, ')
          ..write(
            'resultFavoriteFeedbackSubmittedAt: $resultFavoriteFeedbackSubmittedAt, ',
          )
          ..write(
            'resultNegativeFeedbackSubmittedAt: $resultNegativeFeedbackSubmittedAt, ',
          )
          ..write('promptStyle: $promptStyle, ')
          ..write('captureMode: $captureMode, ')
          ..write('appInputContractId: $appInputContractId, ')
          ..write('userInputJson: $userInputJson, ')
          ..write('displaySnapshotJson: $displaySnapshotJson, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('resultNotificationSeenAt: $resultNotificationSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$GenerationRecordDatabase extends GeneratedDatabase {
  _$GenerationRecordDatabase(QueryExecutor e) : super(e);
  $GenerationRecordDatabaseManager get managers =>
      $GenerationRecordDatabaseManager(this);
  late final $GenerationRecordsTable generationRecords =
      $GenerationRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [generationRecords];
}

typedef $$GenerationRecordsTableCreateCompanionBuilder =
    GenerationRecordsCompanion Function({
      required String recordId,
      required DateTime createdAt,
      required DateTime updatedAt,
      required String pipelineStatus,
      required String originalSourceType,
      required String originalAvailability,
      required String resultAvailability,
      Value<String?> originalLocalPath,
      Value<String?> originalAssetId,
      Value<DateTime?> originalCapturedAt,
      Value<String?> originalFormat,
      Value<int?> originalWidth,
      Value<int?> originalHeight,
      Value<int?> originalSizeBytes,
      Value<String?> originalSha256,
      Value<String?> originalHashStatus,
      Value<String?> originalHashError,
      Value<DateTime?> originalClearedAt,
      Value<String?> uploadSessionId,
      Value<String?> sourceImageObjectId,
      Value<String?> uploadContentType,
      Value<int?> uploadSizeBytes,
      Value<String?> uploadSha256,
      Value<String?> taskId,
      Value<String?> taskStatus,
      Value<String?> resultImageObjectId,
      Value<String?> resultLocalCachePath,
      Value<String?> resultAssetId,
      Value<DateTime?> resultSavedAt,
      Value<int?> resultSizeBytes,
      Value<String?> resultSha256,
      Value<String?> resultHashStatus,
      Value<String?> resultHashError,
      Value<bool> resultIsFavorite,
      Value<DateTime?> resultFavoritedAt,
      Value<DateTime?> resultFavoriteFeedbackSubmittedAt,
      Value<DateTime?> resultNegativeFeedbackSubmittedAt,
      Value<String?> promptStyle,
      Value<String?> captureMode,
      Value<String?> appInputContractId,
      Value<String?> userInputJson,
      Value<String?> displaySnapshotJson,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<DateTime?> resultNotificationSeenAt,
      Value<int> rowid,
    });
typedef $$GenerationRecordsTableUpdateCompanionBuilder =
    GenerationRecordsCompanion Function({
      Value<String> recordId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> pipelineStatus,
      Value<String> originalSourceType,
      Value<String> originalAvailability,
      Value<String> resultAvailability,
      Value<String?> originalLocalPath,
      Value<String?> originalAssetId,
      Value<DateTime?> originalCapturedAt,
      Value<String?> originalFormat,
      Value<int?> originalWidth,
      Value<int?> originalHeight,
      Value<int?> originalSizeBytes,
      Value<String?> originalSha256,
      Value<String?> originalHashStatus,
      Value<String?> originalHashError,
      Value<DateTime?> originalClearedAt,
      Value<String?> uploadSessionId,
      Value<String?> sourceImageObjectId,
      Value<String?> uploadContentType,
      Value<int?> uploadSizeBytes,
      Value<String?> uploadSha256,
      Value<String?> taskId,
      Value<String?> taskStatus,
      Value<String?> resultImageObjectId,
      Value<String?> resultLocalCachePath,
      Value<String?> resultAssetId,
      Value<DateTime?> resultSavedAt,
      Value<int?> resultSizeBytes,
      Value<String?> resultSha256,
      Value<String?> resultHashStatus,
      Value<String?> resultHashError,
      Value<bool> resultIsFavorite,
      Value<DateTime?> resultFavoritedAt,
      Value<DateTime?> resultFavoriteFeedbackSubmittedAt,
      Value<DateTime?> resultNegativeFeedbackSubmittedAt,
      Value<String?> promptStyle,
      Value<String?> captureMode,
      Value<String?> appInputContractId,
      Value<String?> userInputJson,
      Value<String?> displaySnapshotJson,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<DateTime?> resultNotificationSeenAt,
      Value<int> rowid,
    });

class $$GenerationRecordsTableFilterComposer
    extends Composer<_$GenerationRecordDatabase, $GenerationRecordsTable> {
  $$GenerationRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pipelineStatus => $composableBuilder(
    column: $table.pipelineStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalSourceType => $composableBuilder(
    column: $table.originalSourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalAvailability => $composableBuilder(
    column: $table.originalAvailability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultAvailability => $composableBuilder(
    column: $table.resultAvailability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalLocalPath => $composableBuilder(
    column: $table.originalLocalPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalAssetId => $composableBuilder(
    column: $table.originalAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get originalCapturedAt => $composableBuilder(
    column: $table.originalCapturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalFormat => $composableBuilder(
    column: $table.originalFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get originalWidth => $composableBuilder(
    column: $table.originalWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get originalHeight => $composableBuilder(
    column: $table.originalHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get originalSizeBytes => $composableBuilder(
    column: $table.originalSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalSha256 => $composableBuilder(
    column: $table.originalSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalHashStatus => $composableBuilder(
    column: $table.originalHashStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalHashError => $composableBuilder(
    column: $table.originalHashError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get originalClearedAt => $composableBuilder(
    column: $table.originalClearedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadSessionId => $composableBuilder(
    column: $table.uploadSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceImageObjectId => $composableBuilder(
    column: $table.sourceImageObjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadContentType => $composableBuilder(
    column: $table.uploadContentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uploadSizeBytes => $composableBuilder(
    column: $table.uploadSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadSha256 => $composableBuilder(
    column: $table.uploadSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskStatus => $composableBuilder(
    column: $table.taskStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultImageObjectId => $composableBuilder(
    column: $table.resultImageObjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultLocalCachePath => $composableBuilder(
    column: $table.resultLocalCachePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultAssetId => $composableBuilder(
    column: $table.resultAssetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resultSavedAt => $composableBuilder(
    column: $table.resultSavedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resultSizeBytes => $composableBuilder(
    column: $table.resultSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultSha256 => $composableBuilder(
    column: $table.resultSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultHashStatus => $composableBuilder(
    column: $table.resultHashStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultHashError => $composableBuilder(
    column: $table.resultHashError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get resultIsFavorite => $composableBuilder(
    column: $table.resultIsFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resultFavoritedAt => $composableBuilder(
    column: $table.resultFavoritedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resultFavoriteFeedbackSubmittedAt =>
      $composableBuilder(
        column: $table.resultFavoriteFeedbackSubmittedAt,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<DateTime> get resultNegativeFeedbackSubmittedAt =>
      $composableBuilder(
        column: $table.resultNegativeFeedbackSubmittedAt,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<String> get promptStyle => $composableBuilder(
    column: $table.promptStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get captureMode => $composableBuilder(
    column: $table.captureMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appInputContractId => $composableBuilder(
    column: $table.appInputContractId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userInputJson => $composableBuilder(
    column: $table.userInputJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displaySnapshotJson => $composableBuilder(
    column: $table.displaySnapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resultNotificationSeenAt => $composableBuilder(
    column: $table.resultNotificationSeenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GenerationRecordsTableOrderingComposer
    extends Composer<_$GenerationRecordDatabase, $GenerationRecordsTable> {
  $$GenerationRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pipelineStatus => $composableBuilder(
    column: $table.pipelineStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalSourceType => $composableBuilder(
    column: $table.originalSourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalAvailability => $composableBuilder(
    column: $table.originalAvailability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultAvailability => $composableBuilder(
    column: $table.resultAvailability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalLocalPath => $composableBuilder(
    column: $table.originalLocalPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalAssetId => $composableBuilder(
    column: $table.originalAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get originalCapturedAt => $composableBuilder(
    column: $table.originalCapturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalFormat => $composableBuilder(
    column: $table.originalFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get originalWidth => $composableBuilder(
    column: $table.originalWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get originalHeight => $composableBuilder(
    column: $table.originalHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get originalSizeBytes => $composableBuilder(
    column: $table.originalSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalSha256 => $composableBuilder(
    column: $table.originalSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalHashStatus => $composableBuilder(
    column: $table.originalHashStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalHashError => $composableBuilder(
    column: $table.originalHashError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get originalClearedAt => $composableBuilder(
    column: $table.originalClearedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadSessionId => $composableBuilder(
    column: $table.uploadSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceImageObjectId => $composableBuilder(
    column: $table.sourceImageObjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadContentType => $composableBuilder(
    column: $table.uploadContentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uploadSizeBytes => $composableBuilder(
    column: $table.uploadSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadSha256 => $composableBuilder(
    column: $table.uploadSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskStatus => $composableBuilder(
    column: $table.taskStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultImageObjectId => $composableBuilder(
    column: $table.resultImageObjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultLocalCachePath => $composableBuilder(
    column: $table.resultLocalCachePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultAssetId => $composableBuilder(
    column: $table.resultAssetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resultSavedAt => $composableBuilder(
    column: $table.resultSavedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resultSizeBytes => $composableBuilder(
    column: $table.resultSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultSha256 => $composableBuilder(
    column: $table.resultSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultHashStatus => $composableBuilder(
    column: $table.resultHashStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultHashError => $composableBuilder(
    column: $table.resultHashError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get resultIsFavorite => $composableBuilder(
    column: $table.resultIsFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resultFavoritedAt => $composableBuilder(
    column: $table.resultFavoritedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resultFavoriteFeedbackSubmittedAt =>
      $composableBuilder(
        column: $table.resultFavoriteFeedbackSubmittedAt,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<DateTime> get resultNegativeFeedbackSubmittedAt =>
      $composableBuilder(
        column: $table.resultNegativeFeedbackSubmittedAt,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get promptStyle => $composableBuilder(
    column: $table.promptStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get captureMode => $composableBuilder(
    column: $table.captureMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appInputContractId => $composableBuilder(
    column: $table.appInputContractId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userInputJson => $composableBuilder(
    column: $table.userInputJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displaySnapshotJson => $composableBuilder(
    column: $table.displaySnapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resultNotificationSeenAt => $composableBuilder(
    column: $table.resultNotificationSeenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GenerationRecordsTableAnnotationComposer
    extends Composer<_$GenerationRecordDatabase, $GenerationRecordsTable> {
  $$GenerationRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get pipelineStatus => $composableBuilder(
    column: $table.pipelineStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalSourceType => $composableBuilder(
    column: $table.originalSourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalAvailability => $composableBuilder(
    column: $table.originalAvailability,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultAvailability => $composableBuilder(
    column: $table.resultAvailability,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalLocalPath => $composableBuilder(
    column: $table.originalLocalPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalAssetId => $composableBuilder(
    column: $table.originalAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get originalCapturedAt => $composableBuilder(
    column: $table.originalCapturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalFormat => $composableBuilder(
    column: $table.originalFormat,
    builder: (column) => column,
  );

  GeneratedColumn<int> get originalWidth => $composableBuilder(
    column: $table.originalWidth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get originalHeight => $composableBuilder(
    column: $table.originalHeight,
    builder: (column) => column,
  );

  GeneratedColumn<int> get originalSizeBytes => $composableBuilder(
    column: $table.originalSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalSha256 => $composableBuilder(
    column: $table.originalSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalHashStatus => $composableBuilder(
    column: $table.originalHashStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalHashError => $composableBuilder(
    column: $table.originalHashError,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get originalClearedAt => $composableBuilder(
    column: $table.originalClearedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uploadSessionId => $composableBuilder(
    column: $table.uploadSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceImageObjectId => $composableBuilder(
    column: $table.sourceImageObjectId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uploadContentType => $composableBuilder(
    column: $table.uploadContentType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get uploadSizeBytes => $composableBuilder(
    column: $table.uploadSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uploadSha256 => $composableBuilder(
    column: $table.uploadSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get taskStatus => $composableBuilder(
    column: $table.taskStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultImageObjectId => $composableBuilder(
    column: $table.resultImageObjectId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultLocalCachePath => $composableBuilder(
    column: $table.resultLocalCachePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultAssetId => $composableBuilder(
    column: $table.resultAssetId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resultSavedAt => $composableBuilder(
    column: $table.resultSavedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resultSizeBytes => $composableBuilder(
    column: $table.resultSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultSha256 => $composableBuilder(
    column: $table.resultSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultHashStatus => $composableBuilder(
    column: $table.resultHashStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultHashError => $composableBuilder(
    column: $table.resultHashError,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get resultIsFavorite => $composableBuilder(
    column: $table.resultIsFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resultFavoritedAt => $composableBuilder(
    column: $table.resultFavoritedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resultFavoriteFeedbackSubmittedAt =>
      $composableBuilder(
        column: $table.resultFavoriteFeedbackSubmittedAt,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get resultNegativeFeedbackSubmittedAt =>
      $composableBuilder(
        column: $table.resultNegativeFeedbackSubmittedAt,
        builder: (column) => column,
      );

  GeneratedColumn<String> get promptStyle => $composableBuilder(
    column: $table.promptStyle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get captureMode => $composableBuilder(
    column: $table.captureMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get appInputContractId => $composableBuilder(
    column: $table.appInputContractId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userInputJson => $composableBuilder(
    column: $table.userInputJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displaySnapshotJson => $composableBuilder(
    column: $table.displaySnapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resultNotificationSeenAt => $composableBuilder(
    column: $table.resultNotificationSeenAt,
    builder: (column) => column,
  );
}

class $$GenerationRecordsTableTableManager
    extends
        RootTableManager<
          _$GenerationRecordDatabase,
          $GenerationRecordsTable,
          GenerationRecord,
          $$GenerationRecordsTableFilterComposer,
          $$GenerationRecordsTableOrderingComposer,
          $$GenerationRecordsTableAnnotationComposer,
          $$GenerationRecordsTableCreateCompanionBuilder,
          $$GenerationRecordsTableUpdateCompanionBuilder,
          (
            GenerationRecord,
            BaseReferences<
              _$GenerationRecordDatabase,
              $GenerationRecordsTable,
              GenerationRecord
            >,
          ),
          GenerationRecord,
          PrefetchHooks Function()
        > {
  $$GenerationRecordsTableTableManager(
    _$GenerationRecordDatabase db,
    $GenerationRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GenerationRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GenerationRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GenerationRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> recordId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> pipelineStatus = const Value.absent(),
                Value<String> originalSourceType = const Value.absent(),
                Value<String> originalAvailability = const Value.absent(),
                Value<String> resultAvailability = const Value.absent(),
                Value<String?> originalLocalPath = const Value.absent(),
                Value<String?> originalAssetId = const Value.absent(),
                Value<DateTime?> originalCapturedAt = const Value.absent(),
                Value<String?> originalFormat = const Value.absent(),
                Value<int?> originalWidth = const Value.absent(),
                Value<int?> originalHeight = const Value.absent(),
                Value<int?> originalSizeBytes = const Value.absent(),
                Value<String?> originalSha256 = const Value.absent(),
                Value<String?> originalHashStatus = const Value.absent(),
                Value<String?> originalHashError = const Value.absent(),
                Value<DateTime?> originalClearedAt = const Value.absent(),
                Value<String?> uploadSessionId = const Value.absent(),
                Value<String?> sourceImageObjectId = const Value.absent(),
                Value<String?> uploadContentType = const Value.absent(),
                Value<int?> uploadSizeBytes = const Value.absent(),
                Value<String?> uploadSha256 = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> taskStatus = const Value.absent(),
                Value<String?> resultImageObjectId = const Value.absent(),
                Value<String?> resultLocalCachePath = const Value.absent(),
                Value<String?> resultAssetId = const Value.absent(),
                Value<DateTime?> resultSavedAt = const Value.absent(),
                Value<int?> resultSizeBytes = const Value.absent(),
                Value<String?> resultSha256 = const Value.absent(),
                Value<String?> resultHashStatus = const Value.absent(),
                Value<String?> resultHashError = const Value.absent(),
                Value<bool> resultIsFavorite = const Value.absent(),
                Value<DateTime?> resultFavoritedAt = const Value.absent(),
                Value<DateTime?> resultFavoriteFeedbackSubmittedAt =
                    const Value.absent(),
                Value<DateTime?> resultNegativeFeedbackSubmittedAt =
                    const Value.absent(),
                Value<String?> promptStyle = const Value.absent(),
                Value<String?> captureMode = const Value.absent(),
                Value<String?> appInputContractId = const Value.absent(),
                Value<String?> userInputJson = const Value.absent(),
                Value<String?> displaySnapshotJson = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime?> resultNotificationSeenAt =
                    const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GenerationRecordsCompanion(
                recordId: recordId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                pipelineStatus: pipelineStatus,
                originalSourceType: originalSourceType,
                originalAvailability: originalAvailability,
                resultAvailability: resultAvailability,
                originalLocalPath: originalLocalPath,
                originalAssetId: originalAssetId,
                originalCapturedAt: originalCapturedAt,
                originalFormat: originalFormat,
                originalWidth: originalWidth,
                originalHeight: originalHeight,
                originalSizeBytes: originalSizeBytes,
                originalSha256: originalSha256,
                originalHashStatus: originalHashStatus,
                originalHashError: originalHashError,
                originalClearedAt: originalClearedAt,
                uploadSessionId: uploadSessionId,
                sourceImageObjectId: sourceImageObjectId,
                uploadContentType: uploadContentType,
                uploadSizeBytes: uploadSizeBytes,
                uploadSha256: uploadSha256,
                taskId: taskId,
                taskStatus: taskStatus,
                resultImageObjectId: resultImageObjectId,
                resultLocalCachePath: resultLocalCachePath,
                resultAssetId: resultAssetId,
                resultSavedAt: resultSavedAt,
                resultSizeBytes: resultSizeBytes,
                resultSha256: resultSha256,
                resultHashStatus: resultHashStatus,
                resultHashError: resultHashError,
                resultIsFavorite: resultIsFavorite,
                resultFavoritedAt: resultFavoritedAt,
                resultFavoriteFeedbackSubmittedAt:
                    resultFavoriteFeedbackSubmittedAt,
                resultNegativeFeedbackSubmittedAt:
                    resultNegativeFeedbackSubmittedAt,
                promptStyle: promptStyle,
                captureMode: captureMode,
                appInputContractId: appInputContractId,
                userInputJson: userInputJson,
                displaySnapshotJson: displaySnapshotJson,
                errorCode: errorCode,
                errorMessage: errorMessage,
                resultNotificationSeenAt: resultNotificationSeenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String recordId,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String pipelineStatus,
                required String originalSourceType,
                required String originalAvailability,
                required String resultAvailability,
                Value<String?> originalLocalPath = const Value.absent(),
                Value<String?> originalAssetId = const Value.absent(),
                Value<DateTime?> originalCapturedAt = const Value.absent(),
                Value<String?> originalFormat = const Value.absent(),
                Value<int?> originalWidth = const Value.absent(),
                Value<int?> originalHeight = const Value.absent(),
                Value<int?> originalSizeBytes = const Value.absent(),
                Value<String?> originalSha256 = const Value.absent(),
                Value<String?> originalHashStatus = const Value.absent(),
                Value<String?> originalHashError = const Value.absent(),
                Value<DateTime?> originalClearedAt = const Value.absent(),
                Value<String?> uploadSessionId = const Value.absent(),
                Value<String?> sourceImageObjectId = const Value.absent(),
                Value<String?> uploadContentType = const Value.absent(),
                Value<int?> uploadSizeBytes = const Value.absent(),
                Value<String?> uploadSha256 = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<String?> taskStatus = const Value.absent(),
                Value<String?> resultImageObjectId = const Value.absent(),
                Value<String?> resultLocalCachePath = const Value.absent(),
                Value<String?> resultAssetId = const Value.absent(),
                Value<DateTime?> resultSavedAt = const Value.absent(),
                Value<int?> resultSizeBytes = const Value.absent(),
                Value<String?> resultSha256 = const Value.absent(),
                Value<String?> resultHashStatus = const Value.absent(),
                Value<String?> resultHashError = const Value.absent(),
                Value<bool> resultIsFavorite = const Value.absent(),
                Value<DateTime?> resultFavoritedAt = const Value.absent(),
                Value<DateTime?> resultFavoriteFeedbackSubmittedAt =
                    const Value.absent(),
                Value<DateTime?> resultNegativeFeedbackSubmittedAt =
                    const Value.absent(),
                Value<String?> promptStyle = const Value.absent(),
                Value<String?> captureMode = const Value.absent(),
                Value<String?> appInputContractId = const Value.absent(),
                Value<String?> userInputJson = const Value.absent(),
                Value<String?> displaySnapshotJson = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime?> resultNotificationSeenAt =
                    const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GenerationRecordsCompanion.insert(
                recordId: recordId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                pipelineStatus: pipelineStatus,
                originalSourceType: originalSourceType,
                originalAvailability: originalAvailability,
                resultAvailability: resultAvailability,
                originalLocalPath: originalLocalPath,
                originalAssetId: originalAssetId,
                originalCapturedAt: originalCapturedAt,
                originalFormat: originalFormat,
                originalWidth: originalWidth,
                originalHeight: originalHeight,
                originalSizeBytes: originalSizeBytes,
                originalSha256: originalSha256,
                originalHashStatus: originalHashStatus,
                originalHashError: originalHashError,
                originalClearedAt: originalClearedAt,
                uploadSessionId: uploadSessionId,
                sourceImageObjectId: sourceImageObjectId,
                uploadContentType: uploadContentType,
                uploadSizeBytes: uploadSizeBytes,
                uploadSha256: uploadSha256,
                taskId: taskId,
                taskStatus: taskStatus,
                resultImageObjectId: resultImageObjectId,
                resultLocalCachePath: resultLocalCachePath,
                resultAssetId: resultAssetId,
                resultSavedAt: resultSavedAt,
                resultSizeBytes: resultSizeBytes,
                resultSha256: resultSha256,
                resultHashStatus: resultHashStatus,
                resultHashError: resultHashError,
                resultIsFavorite: resultIsFavorite,
                resultFavoritedAt: resultFavoritedAt,
                resultFavoriteFeedbackSubmittedAt:
                    resultFavoriteFeedbackSubmittedAt,
                resultNegativeFeedbackSubmittedAt:
                    resultNegativeFeedbackSubmittedAt,
                promptStyle: promptStyle,
                captureMode: captureMode,
                appInputContractId: appInputContractId,
                userInputJson: userInputJson,
                displaySnapshotJson: displaySnapshotJson,
                errorCode: errorCode,
                errorMessage: errorMessage,
                resultNotificationSeenAt: resultNotificationSeenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GenerationRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$GenerationRecordDatabase,
      $GenerationRecordsTable,
      GenerationRecord,
      $$GenerationRecordsTableFilterComposer,
      $$GenerationRecordsTableOrderingComposer,
      $$GenerationRecordsTableAnnotationComposer,
      $$GenerationRecordsTableCreateCompanionBuilder,
      $$GenerationRecordsTableUpdateCompanionBuilder,
      (
        GenerationRecord,
        BaseReferences<
          _$GenerationRecordDatabase,
          $GenerationRecordsTable,
          GenerationRecord
        >,
      ),
      GenerationRecord,
      PrefetchHooks Function()
    >;

class $GenerationRecordDatabaseManager {
  final _$GenerationRecordDatabase _db;
  $GenerationRecordDatabaseManager(this._db);
  $$GenerationRecordsTableTableManager get generationRecords =>
      $$GenerationRecordsTableTableManager(_db, _db.generationRecords);
}
