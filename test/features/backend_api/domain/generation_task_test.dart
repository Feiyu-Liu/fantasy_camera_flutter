import 'package:fantasy_camera_flutter/features/backend_api/domain/generation_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v2 generation input persists and sends MAX quality', () {
    const CreateGenerationTaskInput input = CreateGenerationTaskInput(
      uploadSessionId: 'upload-1',
      promptStyle: 'realistic',
      captureMode: 'auto',
      qualityTier: GenerationQualityTier.max,
      userInput: <String, Object?>{'requestedQualityTier': 'max'},
    );

    final Map<String, Object?> json = input.toJson();

    expect(json['qualityTier'], 'max');
    expect(
      (json['userInput']! as Map<String, Object?>)['requestedQualityTier'],
      'max',
    );
  });

  test('subscription task accepts nullable credit reservation', () {
    final CreatedGenerationTask task =
        CreatedGenerationTask.fromJson(<String, Object?>{
          'taskId': 'task-1',
          'status': 'pending',
          'creditReservationId': null,
          'allowanceReservationId': 'allowance-1',
          'billingSource': 'allowance_full',
          'chargedUnits': 6,
          'qualityTier': 'max',
          'costCredits': 6,
        });

    expect(task.creditReservationId, isNull);
    expect(task.allowanceReservationId, 'allowance-1');
    expect(task.qualityTier, GenerationQualityTier.max);
  });
}
