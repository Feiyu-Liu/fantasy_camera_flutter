import 'json_value.dart';

const String defaultPromptStyle = 'realistic';
const String defaultCaptureMode = 'auto';
const String manualCaptureMode = 'manual';

const List<PromptSwitchDefinition>
fallbackPromptSwitches = <PromptSwitchDefinition>[
  PromptSwitchDefinition(id: 'recompose', title: '重构图', defaultValue: true),
  PromptSwitchDefinition(id: 'beautifyFace', title: '人物优化', defaultValue: true),
  PromptSwitchDefinition(id: 'cleanFrame', title: '画面净化', defaultValue: true),
  PromptSwitchDefinition(
    id: 'backgroundBlur',
    title: '背景虚化',
    defaultValue: true,
  ),
];

const List<PromptStyleDefinition> fallbackPromptStyles =
    <PromptStyleDefinition>[
      PromptStyleDefinition(
        id: defaultPromptStyle,
        title: 'Realistic',
        captureModes: <PromptCaptureModeDefinition>[
          PromptCaptureModeDefinition(
            id: defaultCaptureMode,
            title: 'Auto',
            switches: <PromptSwitchDefinition>[],
          ),
          PromptCaptureModeDefinition(
            id: manualCaptureMode,
            title: 'Manual',
            switches: fallbackPromptSwitches,
          ),
        ],
      ),
    ];

class PromptStyleDefinition {
  const PromptStyleDefinition({
    required this.id,
    required this.title,
    required this.captureModes,
  });

  final String id;
  final String title;
  final List<PromptCaptureModeDefinition> captureModes;

  factory PromptStyleDefinition.fromJson(JsonObject json) {
    final Object? rawCaptureModes = json['captureModes'];
    if (rawCaptureModes is! List) {
      throw const FormatException('Expected list field "captureModes".');
    }
    final List<PromptCaptureModeDefinition> captureModes = rawCaptureModes
        .map(_tryJsonObject)
        .whereType<JsonObject>()
        .map(PromptCaptureModeDefinition.fromJson)
        .where(
          (PromptCaptureModeDefinition captureMode) =>
              captureMode.id.isNotEmpty,
        )
        .toList(growable: false);
    if (captureModes.isEmpty) {
      throw const FormatException('Expected at least one capture mode.');
    }
    return PromptStyleDefinition(
      id: _readString(json, 'id'),
      title: _readString(json, 'title'),
      captureModes: captureModes,
    );
  }
}

class PromptCaptureModeDefinition {
  const PromptCaptureModeDefinition({
    required this.id,
    required this.title,
    required this.switches,
  });

  final String id;
  final String title;
  final List<PromptSwitchDefinition> switches;

  factory PromptCaptureModeDefinition.fromJson(JsonObject json) {
    final Object? rawSwitches = json['switches'];
    final List<PromptSwitchDefinition> switches = rawSwitches is List
        ? rawSwitches
              .map(_tryJsonObject)
              .whereType<JsonObject>()
              .map(PromptSwitchDefinition.fromJson)
              .toList(growable: false)
        : const <PromptSwitchDefinition>[];
    return PromptCaptureModeDefinition(
      id: _readString(json, 'id'),
      title: _readString(json, 'title'),
      switches: switches,
    );
  }
}

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
    switches: <String, bool>{},
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

List<PromptStyleDefinition> promptStylesFromConfig(JsonObject config) {
  final Object? rawModes = config['modes'];
  if (rawModes is! List) {
    return fallbackPromptStyles;
  }

  final List<PromptStyleDefinition> styles = rawModes
      .map(_tryJsonObject)
      .whereType<JsonObject>()
      .map((JsonObject json) {
        try {
          return PromptStyleDefinition.fromJson(json);
        } on FormatException {
          return null;
        }
      })
      .whereType<PromptStyleDefinition>()
      .where((PromptStyleDefinition style) => style.id == defaultPromptStyle)
      .toList(growable: false);

  return styles.isEmpty ? fallbackPromptStyles : styles;
}

List<PromptSwitchDefinition> promptSwitchesForRoute(
  JsonObject config, {
  String promptStyle = defaultPromptStyle,
  String captureMode = defaultCaptureMode,
}) {
  return promptSwitchesForDefinitions(
    promptStylesFromConfig(config),
    promptStyle: promptStyle,
    captureMode: captureMode,
  );
}

List<PromptSwitchDefinition> promptSwitchesForDefinitions(
  List<PromptStyleDefinition> styles, {
  required String promptStyle,
  required String captureMode,
}) {
  final PromptStyleDefinition? style = promptStyleDefinitionById(
    styles,
    promptStyle,
  );
  final PromptCaptureModeDefinition? mode = style == null
      ? null
      : promptCaptureModeDefinitionById(style, captureMode);
  return mode?.switches ?? fallbackPromptSwitches;
}

PromptStyleDefinition? promptStyleDefinitionById(
  List<PromptStyleDefinition> styles,
  String styleId,
) {
  for (final PromptStyleDefinition style in styles) {
    if (style.id == styleId) {
      return style;
    }
  }
  return null;
}

PromptCaptureModeDefinition? promptCaptureModeDefinitionById(
  PromptStyleDefinition style,
  String captureModeId,
) {
  for (final PromptCaptureModeDefinition captureMode in style.captureModes) {
    if (captureMode.id == captureModeId) {
      return captureMode;
    }
  }
  return null;
}

PromptStyleDefinition defaultPromptStyleDefinition(
  List<PromptStyleDefinition> styles,
) {
  return promptStyleDefinitionById(styles, defaultPromptStyle) ?? styles.first;
}

PromptCaptureModeDefinition defaultPromptCaptureModeDefinition(
  PromptStyleDefinition style,
) {
  return promptCaptureModeDefinitionById(style, defaultCaptureMode) ??
      style.captureModes.first;
}

@Deprecated('Use promptStylesFromConfig and promptSwitchesForDefinitions.')
List<PromptSwitchDefinition> legacyPromptSwitchesForRoute(
  JsonObject config, {
  String promptStyle = defaultPromptStyle,
  String captureMode = defaultCaptureMode,
}) {
  final List<PromptSwitchDefinition> switches = promptSwitchesForRoute(
    config,
    promptStyle: promptStyle,
    captureMode: captureMode,
  );
  if (switches.isEmpty) {
    return fallbackPromptSwitches;
  }
  return switches;
}

Map<String, bool> defaultSwitchValuesFor(
  List<PromptSwitchDefinition> switches,
) {
  return <String, bool>{
    for (final PromptSwitchDefinition definition in switches)
      definition.id: definition.defaultValue,
  };
}

List<PromptStyleDefinition> localizedPromptStyles(
  List<PromptStyleDefinition> styles, {
  required String Function(String id, String fallback) styleTitle,
  required String Function(String id, String fallback) captureModeTitle,
  required String Function(String id, String fallback) switchTitle,
}) {
  return <PromptStyleDefinition>[
    for (final PromptStyleDefinition style in styles)
      PromptStyleDefinition(
        id: style.id,
        title: styleTitle(style.id, style.title),
        captureModes: <PromptCaptureModeDefinition>[
          for (final PromptCaptureModeDefinition captureMode
              in style.captureModes)
            PromptCaptureModeDefinition(
              id: captureMode.id,
              title: captureModeTitle(captureMode.id, captureMode.title),
              switches: <PromptSwitchDefinition>[
                for (final PromptSwitchDefinition promptSwitch
                    in captureMode.switches)
                  PromptSwitchDefinition(
                    id: promptSwitch.id,
                    title: switchTitle(promptSwitch.id, promptSwitch.title),
                    defaultValue: promptSwitch.defaultValue,
                  ),
              ],
            ),
        ],
      ),
  ];
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
