import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:fantasy_camera_flutter/features/camera/data/captured_photo_processor.dart';
import 'package:fantasy_camera_flutter/features/camera/domain/camera_capture_aspect_ratio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'fantasy_camera/captured_photo_processing',
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('4:3 returns the source without invoking native processing', () async {
    int nativeCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          nativeCalls += 1;
          return null;
        });
    const MethodChannelCapturedPhotoProcessor processor =
        MethodChannelCapturedPhotoProcessor();

    final PreparedCapturedPhoto result = await processor
        .prepareCanonicalOriginal(
          source: XFile('/tmp/source.heic'),
          aspectRatio: CameraCaptureAspectRatio.fourThree,
        );

    expect(result.file.path, '/tmp/source.heic');
    expect(result.temporaryPathToDelete, isNull);
    expect(nativeCalls, 0);
  });

  test('square validates and returns the native crop output', () async {
    final Directory temporaryDirectory = await Directory.systemTemp.createTemp(
      'captured_photo_processor_test_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final File sourceFile = File('${temporaryDirectory.path}/source.heic');
    await sourceFile.writeAsBytes(<int>[1, 2, 3]);
    String? outputPath;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          expect(call.method, 'cropSquare');
          final Map<Object?, Object?> arguments =
              call.arguments! as Map<Object?, Object?>;
          expect(arguments['sourcePath'], sourceFile.path);
          outputPath = arguments['outputPath']! as String;
          await File(outputPath!).writeAsBytes(<int>[4, 5, 6]);
          return <String, Object>{
            'path': outputPath!,
            'width': 3024,
            'height': 3024,
          };
        });
    final MethodChannelCapturedPhotoProcessor processor =
        MethodChannelCapturedPhotoProcessor(
          temporaryDirectoryProvider: () async => temporaryDirectory,
        );

    final PreparedCapturedPhoto result = await processor
        .prepareCanonicalOriginal(
          source: XFile(sourceFile.path),
          aspectRatio: CameraCaptureAspectRatio.square,
        );

    expect(result.file.path, outputPath);
    expect(result.temporaryPathToDelete, outputPath);
    expect(await result.file.length(), 3);
  });
}
