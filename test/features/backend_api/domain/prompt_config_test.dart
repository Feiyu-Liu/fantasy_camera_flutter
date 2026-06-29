import 'package:fantasy_camera_flutter/features/backend_api/domain/json_value.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/prompt_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses prompt styles and capture modes', () {
    final List<PromptStyleDefinition> styles = promptStylesFromConfig(_config);

    expect(styles.map((PromptStyleDefinition style) => style.id), <String>[
      'realistic',
    ]);
    expect(styles.first.title, 'Realistic');
    expect(
      styles.first.captureModes.map(
        (PromptCaptureModeDefinition captureMode) => captureMode.id,
      ),
      <String>['auto', 'manual'],
    );
  });

  test('parses prompt switches for the realistic auto route', () {
    final List<PromptSwitchDefinition> switches = promptSwitchesForRoute(
      _config,
    );

    expect(switches, isEmpty);
  });

  test('parses prompt switches for the realistic manual route', () {
    final List<PromptSwitchDefinition> switches = promptSwitchesForRoute(
      _config,
      captureMode: manualCaptureMode,
    );

    expect(
      switches.map((PromptSwitchDefinition switchDefinition) {
        return switchDefinition.id;
      }),
      <String>['recompose', 'beautifyFace'],
    );
    expect(switches.first.title, '重构图');
    expect(switches.first.defaultValue, isTrue);
  });

  test('filters out non-realistic modes from remote config', () {
    final List<PromptStyleDefinition> styles = promptStylesFromConfig(_config);
    expect(promptStyleDefinitionById(styles, 'abstract'), isNull);
  });

  test('returns fallback switches for unsupported routes', () {
    final List<PromptSwitchDefinition> switches = promptSwitchesForRoute(
      _config,
      promptStyle: 'abstract',
      captureMode: defaultCaptureMode,
    );

    expect(
      switches.map((PromptSwitchDefinition switchDefinition) {
        return switchDefinition.id;
      }),
      <String>['recompose', 'beautifyFace', 'cleanFrame', 'backgroundBlur'],
    );
    expect(
      switches.map((PromptSwitchDefinition switchDefinition) {
        return switchDefinition.defaultValue;
      }),
      <bool>[true, true, true, true],
    );
  });

  test('falls back when config does not contain the current route', () {
    final List<PromptSwitchDefinition> switches = promptSwitchesForRoute(
      const <String, Object?>{'modes': <Object?>[]},
    );

    expect(switches, isEmpty);
    expect(defaultSwitchValuesFor(switches), <String, bool>{});
    expect(PromptSelectionSnapshot.fallback.switches, <String, bool>{});
  });
}

const JsonObject _config = <String, Object?>{
  'modes': <Object?>[
    <String, Object?>{
      'id': 'realistic',
      'title': 'Realistic',
      'captureModes': <Object?>[
        <String, Object?>{
          'id': 'auto',
          'title': 'Auto',
          'switches': <Object?>[],
        },
        <String, Object?>{
          'id': 'manual',
          'title': 'Manual',
          'switches': <Object?>[
            <String, Object?>{
              'id': 'recompose',
              'title': '重构图',
              'defaultValue': true,
            },
            <String, Object?>{
              'id': 'beautifyFace',
              'title': '人物优化',
              'defaultValue': false,
            },
          ],
        },
      ],
    },
    <String, Object?>{
      'id': 'abstract',
      'title': 'Abstract',
      'captureModes': <Object?>[
        <String, Object?>{
          'id': 'auto',
          'title': 'General',
          'switches': <Object?>[],
        },
      ],
    },
  ],
};
