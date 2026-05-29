import 'json_value.dart';

enum FeedbackRating {
  positive,
  negative;

  String get wireValue {
    return switch (this) {
      FeedbackRating.positive => 'positive',
      FeedbackRating.negative => 'negative',
    };
  }

  factory FeedbackRating.fromWire(String value) {
    return switch (value) {
      'positive' => FeedbackRating.positive,
      'negative' => FeedbackRating.negative,
      _ => throw FormatException('Unknown feedback rating "$value".'),
    };
  }
}

class FeedbackInput {
  const FeedbackInput({
    required this.taskId,
    required this.rating,
    this.tags = const <String>[],
    this.note,
    this.improveOptIn = false,
    this.metadata = const <String, Object?>{},
  });

  final String taskId;
  final FeedbackRating rating;
  final List<String> tags;
  final String? note;
  final bool improveOptIn;
  final JsonObject metadata;

  JsonObject toJson() {
    return <String, Object?>{
      'taskId': taskId,
      'rating': rating.wireValue,
      if (tags.isNotEmpty) 'tags': tags,
      if (note != null) 'note': note,
      'improveOptIn': improveOptIn,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

class FeedbackSubmission {
  const FeedbackSubmission({
    required this.id,
    required this.taskId,
    required this.rating,
    required this.improveOptIn,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final FeedbackRating rating;
  final bool improveOptIn;
  final DateTime createdAt;

  factory FeedbackSubmission.fromJson(JsonObject json) {
    return FeedbackSubmission(
      id: _readString(json, 'id'),
      taskId: _readString(json, 'taskId'),
      rating: FeedbackRating.fromWire(_readString(json, 'rating')),
      improveOptIn: _readBool(json, 'improveOptIn'),
      createdAt: DateTime.parse(_readString(json, 'createdAt')),
    );
  }
}

String _readString(JsonObject json, String key) {
  final Object? value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected string field "$key".');
}

bool _readBool(JsonObject json, String key) {
  final Object? value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected boolean field "$key".');
}
