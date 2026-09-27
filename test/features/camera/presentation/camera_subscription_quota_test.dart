import 'package:fantasy_camera_flutter/billing/domain/subscription_billing.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('camera quota presentation distinguishes near, overflow, exhausted', () {
    expect(
      cameraQuotaPresentationFor(_status(fullUsed: 28, fullRemaining: 6)),
      CameraQuotaPresentation.nearLimit,
    );
    expect(
      cameraQuotaPresentationFor(_status(fullUsed: 34, fullRemaining: 0)),
      CameraQuotaPresentation.overflow,
    );
    expect(
      cameraQuotaPresentationFor(
        _status(fullUsed: 34, fullRemaining: 0, overflowRemaining: 0),
      ),
      CameraQuotaPresentation.exhausted,
    );
  });
}

SubscriptionBillingStatus _status({
  required int fullUsed,
  required int fullRemaining,
  int overflowRemaining = 20,
}) {
  return SubscriptionBillingStatus(
    billingEnvironment: 'SANDBOX',
    subscription: const SubscriptionAccess(
      active: true,
      tier: SubscriptionTier.plus,
      productIdentifier: 'tessercam_plus_monthly',
      willRenew: true,
      accessEndIsFinal: false,
      syncFreshness: SubscriptionSyncFreshness.fresh,
    ),
    window: AllowanceWindow(
      windowStart: DateTime.utc(2026, 9, 10),
      windowEnd: DateTime.utc(2026, 9, 17),
      nextResetAt: DateTime.utc(2026, 9, 17),
      fullUsed: fullUsed,
      fullReserved: 0,
      fullRemaining: fullRemaining,
      overflowUsed: 0,
      overflowReserved: 0,
      overflowRemaining: overflowRemaining,
    ),
    capabilities: const BillingCapabilities(
      maxEnabled: true,
      qualityTiers: <String>{'full', 'max'},
    ),
    plans: const <SubscriptionPlan>[],
    qualityTiers: const <QualityTierCost>[],
  );
}
