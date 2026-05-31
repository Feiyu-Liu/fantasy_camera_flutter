import 'package:fantasy_camera_flutter/features/backend_api/domain/json_value.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/prompt_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  ],
};
