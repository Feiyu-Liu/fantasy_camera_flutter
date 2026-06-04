import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_image_processor.dart';
import 'package:native_exif/native_exif.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  const bool runDeviceImagePipeline = bool.fromEnvironment(
    'RUN_DEVICE_IMAGE_PIPELINE',
  );

  testWidgets(
    'device converts generated PNG result and writes source EXIF',
    (WidgetTester tester) async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final Directory tempDirectory = await getTemporaryDirectory();
      final File rawFile = await _copyAssetToFile(
        'test/fixtures/image_pipeline/raw.HEIC',
        '${tempDirectory.path}/device-pipeline-raw.HEIC',
      );
      final File resultPngFile = await _copyAssetToFile(
        'test/fixtures/image_pipeline/res.png',
        '${tempDirectory.path}/device-pipeline-result.png',
      );

      final Map<String, Object> rawExif = await _readExif(rawFile.path);
      expect(rawExif, isNotEmpty);
      debugPrint(
        '[DeviceImagePipelineTest] raw path=${rawFile.path} bytes=${await rawFile.length()} exifKeys=${rawExif.length}',
      );
      debugPrint(
        '[DeviceImagePipelineTest] result png path=${resultPngFile.path} bytes=${await resultPngFile.length()}',
      );

      final String heicPath =
          '${tempDirectory.path}/device-pipeline-result.heic';
      await _deleteIfExists(heicPath);
      final XFile? heicResult = await FlutterImageCompress.compressAndGetFile(
        resultPngFile.path,
        heicPath,
        quality: 90,
        format: CompressFormat.heic,
        keepExif: false,
      );
      final bool heicExists = await File(heicPath).exists();
      final int heicBytes = heicExists ? await File(heicPath).length() : -1;
      debugPrint(
        '[DeviceImagePipelineTest] heic returned=${heicResult?.path} exists=$heicExists bytes=$heicBytes',
      );

      final String jpegPath =
          '${tempDirectory.path}/device-pipeline-result-fallback.jpg';
      await _deleteIfExists(jpegPath);
      final XFile? jpegResult = await FlutterImageCompress.compressAndGetFile(
        resultPngFile.path,
        jpegPath,
        quality: 90,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      expect(jpegResult, isNotNull);
      expect(await File(jpegPath).exists(), isTrue);
      expect(await File(jpegPath).length(), greaterThan(0));
      debugPrint(
        '[DeviceImagePipelineTest] jpeg returned=${jpegResult?.path} bytes=${await File(jpegPath).length()}',
      );

      final Map<String, Object> resultExifForWrite = sanitizeResultExifForWrite(
        rawExif,
      );
      await _writeExif(jpegPath, resultExifForWrite);
      final Map<String, Object> jpegExif = await _readExif(jpegPath);
      debugPrint(
        '[DeviceImagePipelineTest] jpeg exif after write keys=${jpegExif.length} DateTimeOriginal=${jpegExif['DateTimeOriginal']} Make=${jpegExif['Make']} Model=${jpegExif['Model']} Orientation=${jpegExif['Orientation']}',
      );
      expect(jpegExif['DateTimeOriginal'], rawExif['DateTimeOriginal']);
      expect(jpegExif['Make'], rawExif['Make']);
      expect(jpegExif['Model'], rawExif['Model']);
      expect(jpegExif['Orientation'], isNot(rawExif['Orientation']));

      expect(
        heicExists && heicBytes > 0,
        isTrue,
        reason:
            'HEIC conversion returned ${heicResult?.path}, but output exists=$heicExists bytes=$heicBytes.',
      );
    },
    // Run with:
    // flutter test -d 00008120-001268460C72201E \
    //   --dart-define=RUN_DEVICE_IMAGE_PIPELINE=true \
    //   test/features/generation_submission/data/image_pipeline_device_test.dart
    skip: !runDeviceImagePipeline,
  );
}

Future<File> _copyAssetToFile(String assetPath, String outputPath) async {
  final ByteData byteData = await rootBundle.load(assetPath);
  final File outputFile = File(outputPath);
  await outputFile.writeAsBytes(
    byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    flush: true,
  );
  return outputFile;
}

Future<void> _deleteIfExists(String path) async {
  final File file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

Future<Map<String, Object>> _readExif(String path) async {
  final Exif exif = await Exif.fromPath(path);
  try {
    return await exif.getAttributes() ?? const <String, Object>{};
  } finally {
    await exif.close();
  }
}

Future<void> _writeExif(String path, Map<String, Object> attributes) async {
  final Exif exif = await Exif.fromPath(path);
  try {
    await exif.writeAttributes(attributes);
  } finally {
    await exif.close();
  }
}
