import 'package:fantasy_camera_flutter/features/generation_submission/data/generation_image_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('result EXIF keeps source metadata but drops orientation', () {
    final Map<String, Object> resultExif =
        sanitizeResultExifForWrite(const <String, Object>{
          'Orientation': 6,
          'DateTimeOriginal': '2026:05:29 00:00:00',
          'Make': 'Apple',
          'Model': 'iPhone',
          'GPSLatitude': '31/1, 13/1, 0/1',
        });

    expect(resultExif, isNot(contains('Orientation')));
    expect(resultExif['DateTimeOriginal'], '2026:05:29 00:00:00');
    expect(resultExif['Make'], 'Apple');
    expect(resultExif['Model'], 'iPhone');
    expect(resultExif['GPSLatitude'], '31/1, 13/1, 0/1');
  });
}
