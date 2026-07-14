import 'package:fantasy_camera_flutter/features/camera/domain/camera_capture_aspect_ratio.dart';
import 'package:fantasy_camera_flutter/settings/application/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('camera capture aspect ratio defaults to 4:3', () async {
    const SharedPreferencesAppSettingsRepository repository =
        SharedPreferencesAppSettingsRepository();

    final AppSettingsState settings = await repository.loadSettings();

    expect(
      settings.cameraCaptureAspectRatio,
      CameraCaptureAspectRatio.fourThree,
    );
  });

  test(
    'camera capture aspect ratio persists as a stable storage value',
    () async {
      const SharedPreferencesAppSettingsRepository repository =
          SharedPreferencesAppSettingsRepository();

      await repository.saveCameraCaptureAspectRatio(
        CameraCaptureAspectRatio.square,
      );
      final AppSettingsState settings = await repository.loadSettings();

      expect(
        settings.cameraCaptureAspectRatio,
        CameraCaptureAspectRatio.square,
      );
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      expect(
        preferences.getString(cameraCaptureAspectRatioPreferenceKey),
        CameraCaptureAspectRatio.square.storageValue,
      );
    },
  );
}
