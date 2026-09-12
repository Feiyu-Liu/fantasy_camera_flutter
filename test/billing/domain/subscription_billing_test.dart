import 'package:fantasy_camera_flutter/billing/domain/subscription_billing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes separate subscription, allowance, and capability state', () {
    final SubscriptionBillingStatus status = SubscriptionBillingStatus.fromJson(
      _statusJson(active: true, fullRemaining: 6, overflowRemaining: 20),
    );

    expect(status.subscription?.tier, SubscriptionTier.plus);
    expect(status.window?.fullUsageFraction, closeTo(28 / 34, 0.001));
    expect(status.capabilities.maxEnabled, isTrue);
    expect(status.allowanceUnitsFor('max'), 6);
    expect(
      status.plans.map((SubscriptionPlan plan) => plan.tier),
      <SubscriptionTier>[
        SubscriptionTier.mini,
        SubscriptionTier.plus,
        SubscriptionTier.pro,
      ],
    );
  });
}

Map<String, Object?> _statusJson({
  required bool active,
  required int fullRemaining,
  required int overflowRemaining,
}) {
  return <String, Object?>{
    'billingEnvironment': 'SANDBOX',
    'subscription': active
        ? <String, Object?>{
            'active': true,
            'tier': 'plus',
            'productIdentifier': 'tessercam_plus_monthly',
            'willRenew': true,
            'accessEndAt': '2026-10-10T00:00:00Z',
            'accessEndIsFinal': false,
            'syncFreshness': 'fresh',
          }
        : null,
    'window': active
        ? <String, Object?>{
            'windowStart': '2026-09-10T00:00:00Z',
            'windowEnd': '2026-09-17T00:00:00Z',
            'nextResetAt': '2026-09-17T00:00:00Z',
            'fullUsed': 34 - fullRemaining,
            'fullReserved': 0,
            'fullRemaining': fullRemaining,
            'overflowUsed': 0,
            'overflowReserved': 0,
            'overflowRemaining': overflowRemaining,
          }
        : null,
    'capabilities': <String, Object?>{
      'maxEnabled': active,
      'qualityTiers': active ? <String>['full', 'max'] : <String>['full'],
    },
    'pendingChange': null,
    'plans': <Object?>[
      _plan('mini', 'tessercam_mini_monthly', 0, 12, 8, false),
      _plan('plus', 'tessercam_plus_monthly', 1, 34, 20, true),
      _plan('pro', 'tessercam_pro_monthly', 2, 72, 40, true),
    ],
    'qualityTiers': <Object?>[
      <String, Object?>{
        'qualityTier': 'full',
        'allowanceUnits': 2,
        'revision': 1,
      },
      <String, Object?>{
        'qualityTier': 'max',
        'allowanceUnits': 6,
        'revision': 1,
      },
    ],
  };
}

Map<String, Object?> _plan(
  String tier,
  String productIdentifier,
  int displayOrder,
  int full,
  int overflow,
  bool maxEnabled,
) {
  return <String, Object?>{
    'productIdentifier': productIdentifier,
    'tier': tier,
    'displayOrder': displayOrder,
    'fullAllowanceUnits': full,
    'overflowAllowanceUnits': overflow,
    'maxEnabled': maxEnabled,
    'revision': 1,
  };
}
