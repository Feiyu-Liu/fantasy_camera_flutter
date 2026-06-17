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
      <String>['portrait'],
    );
  });

  test('parses prompt switches for the realistic portrait route', () {
    final List<PromptSwitchDefinition> switches = promptSwitchesForRoute(
      _config,
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
    expect(
      promptStyleDefinitionById(styles, 'abstract'),
      isNull,
    );
  });

  test('returns fallback switches for unsupported routes', () {
    final List<PromptSwitchDefinition> switches = promptSwitchesForRoute(
      _config,
      promptStyle: 'abstract',
      captureMode: 'general',
    );

    expect(
      switches.map((PromptSwitchDefinition switchDefinition) {
        return switchDefinition.id;
      }),
      <String>['recompose', 'beautifyFace', 'cleanFrame', 'backgroundBlur'],
    );
  });

  test('falls back when config does not contain the current route', () {
    final List<PromptSwitchDefinition> switches = promptSwitchesForRoute(
      const <String, Object?>{'modes': <Object?>[]},
    );

    expect(
      switches.map((PromptSwitchDefinition switchDefinition) {
        return switchDefinition.id;
      }),
      <String>['recompose', 'beautifyFace', 'cleanFrame', 'backgroundBlur'],
    );
  });
}

const JsonObject _config = <String, Object?>{
  'modes': <Object?>[
    <String, Object?>{
      'id': 'realistic',
      'title': 'Realistic',
      'captureModes': <Object?>[
        <String, Object?>{
          'id': 'portrait',
          'title': 'Portrait',
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
          'id': 'general',
          'title': 'General',
          'switches': <Object?>[],
        },
      ],
    },
  ],
};
