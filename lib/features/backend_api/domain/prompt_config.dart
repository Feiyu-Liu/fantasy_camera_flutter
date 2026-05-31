import 'json_value.dart';

const String defaultPromptStyle = 'realistic';
const String defaultCaptureMode = 'portrait';

const List<PromptSwitchDefinition> fallbackPromptSwitches =
    <PromptSwitchDefinition>[
      PromptSwitchDefinition(
        id: 'recompose',
        title: '重构图',
        defaultValue: false,
      ),
      PromptSwitchDefinition(
        id: 'beautifyFace',
        title: '人物优化',
        defaultValue: false,
      ),
      PromptSwitchDefinition(
        id: 'cleanFrame',
        title: '画面净化',
        defaultValue: false,
      ),
      PromptSwitchDefinition(
        id: 'backgroundBlur',
        title: '背景虚化',
        defaultValue: false,
      ),
    ];

class PromptSwitchDefinition {
  const PromptSwitchDefinition({
    required this.id,
    required this.title,
    required this.defaultValue,
  });

  final String id;
  final String title;
  final bool defaultValue;

  factory PromptSwitchDefinition.fromJson(JsonObject json) {
    return PromptSwitchDefinition(
      id: _readString(json, 'id'),
      title: _readString(json, 'title'),
      defaultValue: _readBool(json, 'defaultValue', fallback: false),
    );
  }
}

class PromptSelectionSnapshot {
  const PromptSelectionSnapshot({
    required this.promptStyle,
    required this.captureMode,
    required this.switches,
    this.appInputContractId,
  });

  final String promptStyle;
  final String captureMode;
  final Map<String, bool> switches;
  final String? appInputContractId;

  static const PromptSelectionSnapshot fallback = PromptSelectionSnapshot(
    promptStyle: defaultPromptStyle,
    captureMode: defaultCaptureMode,
    switches: <String, bool>{
      'recompose': false,
      'beautifyFace': false,
      'cleanFrame': false,
      'backgroundBlur': false,
    },
  );

  JsonObject get userInput {
    return <String, Object?>{
      'switches': <String, Object?>{...switches},
    };
  }

  PromptSelectionSnapshot copyWith({
    String? promptStyle,
    String? captureMode,
    Map<String, bool>? switches,
    String? appInputContractId,
  }) {
    return PromptSelectionSnapshot(
      promptStyle: promptStyle ?? this.promptStyle,
      captureMode: captureMode ?? this.captureMode,
      switches: switches ?? this.switches,
      appInputContractId: appInputContractId ?? this.appInputContractId,
    );
  }
}

List<PromptSwitchDefinition> promptSwitchesForRoute(
  JsonObject config, {
  String promptStyle = defaultPromptStyle,
  String captureMode = defaultCaptureMode,
}) {
  final Object? rawModes = config['modes'];
  if (rawModes is! List) {
    return fallbackPromptSwitches;
  }

  for (final Object? rawMode in rawModes) {
    final JsonObject? mode = _tryJsonObject(rawMode);
    if (mode == null || mode['id'] != promptStyle) {
      continue;
    }
    final Object? rawCaptureModes = mode['captureModes'];
    if (rawCaptureModes is! List) {
      return fallbackPromptSwitches;
    }
    for (final Object? rawCaptureMode in rawCaptureModes) {
      final JsonObject? capture = _tryJsonObject(rawCaptureMode);
      if (capture == null || capture['id'] != captureMode) {
        continue;
      }
      final Object? rawSwitches = capture['switches'];
      if (rawSwitches is! List) {
        return fallbackPromptSwitches;
      }
      final List<PromptSwitchDefinition> switches = rawSwitches
          .map(_tryJsonObject)
          .whereType<JsonObject>()
          .map(PromptSwitchDefinition.fromJson)
          .toList(growable: false);
      return switches.isEmpty ? fallbackPromptSwitches : switches;
    }
  }

  return fallbackPromptSwitches;
}

Map<String, bool> defaultSwitchValuesFor(
  List<PromptSwitchDefinition> switches,
) {
  return <String, bool>{
    for (final PromptSwitchDefinition definition in switches)
      definition.id: definition.defaultValue,
  };
}

String _readString(JsonObject json, String key) {
  final Object? value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Expected non-empty string field "$key".');
}

bool _readBool(JsonObject json, String key, {required bool fallback}) {
  final Object? value = json[key];
  if (value is bool) {
    return value;
  }
  return fallback;
}

JsonObject? _tryJsonObject(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return null;
}
