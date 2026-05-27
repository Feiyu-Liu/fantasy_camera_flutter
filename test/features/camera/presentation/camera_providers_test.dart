import 'package:fantasy_camera_flutter/features/camera/presentation/camera_message.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_providers.dart';
import 'package:fantasy_camera_flutter/l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('openDefaultCamera reports no camera when choices are empty', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[cameraChoicesProvider.overrideWithValue(const [])],
    );
    addTearDown(container.dispose);

    await container.read(cameraStateProvider.notifier).openDefaultCamera();

    final CameraMessage? message = container.read(cameraStateProvider).message;
    expect(message, isA<CameraNoCameraFoundMessage>());
    expect(
      message?.localize(appLocalizationsFor(defaultAppLocale)),
      appLocalizationsFor(defaultAppLocale).cameraNoCameraFound,
    );
  });
}
