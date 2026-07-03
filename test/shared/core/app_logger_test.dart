import 'package:fantasy_camera_flutter/shared/core/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizeLogMessage redacts signed URLs and local paths', () {
    const String message =
        'url=https://example.r2.cloudflarestorage.com/bucket/object'
        '?X-Amz-Signature=abc&X-Amz-Credential=key '
        'path=/private/var/mobile/Containers/Data/Application/app/tmp/photo.jpg '
        'token=secret-token';

    final String sanitized = sanitizeLogMessage(message);

    expect(
      sanitized,
      contains(
        'url=https://example.r2.cloudflarestorage.com/bucket/object?[redacted]',
      ),
    );
    expect(sanitized, contains('path=[local-path]'));
    expect(sanitized, contains('token=[redacted]'));
    expect(sanitized, isNot(contains('X-Amz-Signature=abc')));
    expect(sanitized, isNot(contains('secret-token')));
    expect(sanitized, isNot(contains('/private/var/mobile/Containers')));
  });

  test('sanitizeLogMessage redacts long base64-like payloads', () {
    final String payload = 'body=${'A' * 200}';

    expect(sanitizeLogMessage(payload), 'body=[base64-redacted]');
  });
}
