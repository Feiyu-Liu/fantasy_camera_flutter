import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_camera_flutter/features/notifications/data/push_notification_gateway.dart';

void main() {
  group('GenerationNotificationPayload', () {
    test('parses task id and status from APNs data payload', () {
      final GenerationNotificationPayload? payload =
          GenerationNotificationPayload.tryParse(<Object?, Object?>{
            'taskId': 'task-1',
            'status': 'completed',
          });

      expect(payload?.taskId, 'task-1');
      expect(payload?.status, 'completed');
    });

    test('rejects payload without task id', () {
      expect(
        GenerationNotificationPayload.tryParse(<Object?, Object?>{
          'status': 'completed',
        }),
        isNull,
      );
    });
  });
}
