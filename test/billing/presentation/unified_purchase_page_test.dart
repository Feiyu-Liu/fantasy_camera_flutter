import 'dart:async';

import 'package:fantasy_camera_flutter/auth/domain/auth_session_state.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_user.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_providers.dart';
import 'package:fantasy_camera_flutter/billing/data/billing_repositories.dart';
import 'package:fantasy_camera_flutter/billing/data/revenuecat_billing_gateway.dart';
import 'package:fantasy_camera_flutter/billing/data/subscription_billing_repository.dart';
import 'package:fantasy_camera_flutter/billing/domain/billing_product.dart';
import 'package:fantasy_camera_flutter/billing/domain/credit_product.dart';
import 'package:fantasy_camera_flutter/billing/domain/subscription_billing.dart';
import 'package:fantasy_camera_flutter/billing/presentation/billing_providers.dart';
import 'package:fantasy_camera_flutter/billing/presentation/credit_purchase_page.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/api_failure.dart';
import 'package:fantasy_camera_flutter/l10n/l10n.dart';
import 'package:fantasy_camera_flutter/shared/toast/app_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('subscription and credits share the same purchase page', (
    WidgetTester tester,
  ) async {
    final _Store store = _Store();
    await _pumpPage(tester, PurchaseMode.subscription, store);

    expect(find.text('选择你的创作方案'), findsOneWidget);
    expect(find.text('每 7 天约 17 张全画质照片'), findsOneWidget);
    expect(find.textContaining('按月自动续订'), findsOneWidget);
    expect(_modeSelected(tester, 'purchase-mode-subscription'), isTrue);
    expect(
      tester.getTopLeft(_switcher(PurchaseMode.credits)).dy,
      lessThan(tester.getTopLeft(find.text('每 7 天约 17 张全画质照片')).dy),
    );

    await tester.tap(_switcher(PurchaseMode.credits));
    await _settleSwitch(tester);
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      0,
    );

    expect(find.text('获取创作积分'), findsOneWidget);
    expect(find.text('40 积分'), findsOneWidget);
    expect(find.textContaining('按月自动续订'), findsNothing);
    expect(_modeSelected(tester, 'purchase-mode-credits'), isTrue);
    expect(store.offeringIds, containsAll(<String>['subscription', 'credits']));

    await tester.tap(_switcher(PurchaseMode.subscription));
    await _settleSwitch(tester);
    expect(find.text('选择你的创作方案'), findsOneWidget);
    expect(find.text('每 7 天约 17 张全画质照片'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching back does not reload an already loaded offering', (
    WidgetTester tester,
  ) async {
    final _Store store = _Store();
    await _pumpPage(tester, PurchaseMode.subscription, store);

    await tester.tap(_switcher(PurchaseMode.credits));
    await _settleSwitch(tester);
    await tester.tap(_switcher(PurchaseMode.subscription));
    await _settleSwitch(tester);
    await tester.tap(_switcher(PurchaseMode.credits));
    await _settleSwitch(tester);

    expect(
      store.offeringIds.where((String id) => id == 'subscription'),
      hasLength(1),
    );
    expect(
      store.offeringIds.where((String id) => id == 'credits'),
      hasLength(1),
    );
  });

  testWidgets('credit entry starts in credit mode with the switcher on top', (
    WidgetTester tester,
  ) async {
    final _Store store = _Store();
    await _pumpPage(tester, PurchaseMode.credits, store);
    expect(find.text('获取创作积分'), findsOneWidget);
    expect(find.text('40 积分'), findsOneWidget);
    expect(find.text('选择你的创作方案'), findsNothing);
    expect(_modeSelected(tester, 'purchase-mode-credits'), isTrue);
    expect(
      tester.getTopLeft(_switcher(PurchaseMode.subscription)).dy,
      lessThan(tester.getTopLeft(find.text('40 积分')).dy),
    );
    expect(find.byType(CreditPurchasePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switcher is disabled while a subscription purchase runs', (
    WidgetTester tester,
  ) async {
    final Completer<BillingPurchaseOutcome> purchase =
        Completer<BillingPurchaseOutcome>();
    final _Store store = _Store(purchaseResult: () => purchase.future);
    await _pumpPage(tester, PurchaseMode.subscription, store);

    await tester.tap(find.text('继续'));
    await tester.pump();
    await tester.tap(_switcher(PurchaseMode.credits), warnIfMissed: false);
    await _settleSwitch(tester);
    expect(_modeSelected(tester, 'purchase-mode-subscription'), isTrue);
    expect(find.text('选择你的创作方案'), findsOneWidget);

    purchase.complete(const BillingPurchaseCancelled());
    await _settleSwitch(tester);
  });

  testWidgets('subscription purchase success shows a toast with the tier', (
    WidgetTester tester,
  ) async {
    final _RecordingToastPresenter toasts = _RecordingToastPresenter();
    final _Store store = _Store(
      purchaseResult: () async => const BillingPurchaseCompleted(),
    );
    await _pumpPage(
      tester,
      PurchaseMode.subscription,
      store,
      toasts: toasts,
      subscriptionRepository: const _SubscriptionRepository(active: true),
    );

    await tester.tap(find.text('继续'));
    await _settleSwitch(tester);

    expect(toasts.titles, contains('已开通 Plus'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('subscription purchase failure uses a toast, not inline text', (
    WidgetTester tester,
  ) async {
    final _RecordingToastPresenter toasts = _RecordingToastPresenter();
    final _Store store = _Store(
      purchaseResult: () async =>
          BillingPurchaseFailed(StateError('store failed')),
    );
    await _pumpPage(tester, PurchaseMode.subscription, store, toasts: toasts);

    await tester.tap(find.text('继续'));
    await _settleSwitch(tester);

    expect(toasts.types, <AppToastType>[AppToastType.error]);
    expect(find.text(toasts.titles.single), findsNothing);
  });

  testWidgets('the active plan cannot be bought again', (
    WidgetTester tester,
  ) async {
    final _Store store = _Store(
      purchaseResult: () async => const BillingPurchaseCompleted(),
    );
    await _pumpPage(
      tester,
      PurchaseMode.subscription,
      store,
      subscriptionRepository: const _SubscriptionRepository(
        active: true,
        subscribedAtStart: true,
      ),
    );

    expect(find.text('继续'), findsNothing);
    await tester.tap(find.text('当前方案').last);
    await _settleSwitch(tester);
    expect(store.purchaseCount, 0);
  });

  testWidgets('plan cards hide the photo estimate without a Full cost', (
    WidgetTester tester,
  ) async {
    await _pumpPage(
      tester,
      PurchaseMode.subscription,
      _Store(),
      subscriptionRepository: const _SubscriptionRepository(
        withFullCost: false,
      ),
    );

    expect(find.textContaining('张全画质照片'), findsNothing);
    expect(find.text('每 7 天约 0 张全画质照片'), findsNothing);
    expect(find.text('Plus'), findsOneWidget);
  });

  testWidgets('pending subscription sync stays visible inline', (
    WidgetTester tester,
  ) async {
    final _RecordingToastPresenter toasts = _RecordingToastPresenter();
    final _Store store = _Store(
      purchaseResult: () async => const BillingPurchaseCompleted(),
    );
    await _pumpPage(
      tester,
      PurchaseMode.subscription,
      store,
      toasts: toasts,
      subscriptionRepository: const _SubscriptionRepository(syncPending: true),
    );

    await tester.tap(find.text('继续'));
    await _settleSwitch(tester);

    expect(find.text('购买已完成，订阅权益仍在同步，请勿重复购买。'), findsOneWidget);
    expect(toasts.titles, isEmpty);
  });
}

Finder _switcher(PurchaseMode mode) => find.byKey(
  ValueKey<String>(
    mode == PurchaseMode.subscription
        ? 'purchase-mode-subscription'
        : 'purchase-mode-credits',
  ),
);

bool _modeSelected(WidgetTester tester, String identifier) {
  final Semantics semantics = tester.widget<Semantics>(
    find.byWidgetPredicate(
      (Widget widget) =>
          widget is Semantics && widget.properties.identifier == identifier,
    ),
  );
  return semantics.properties.selected ?? false;
}

Future<void> _settleSwitch(WidgetTester tester) async {
  for (int i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpPage(
  WidgetTester tester,
  PurchaseMode mode,
  _Store store, {
  _RecordingToastPresenter? toasts,
  _SubscriptionRepository subscriptionRepository =
      const _SubscriptionRepository(),
}) async {
  await tester.binding.setSurfaceSize(const Size(393, 852));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppToastHost(
      child: ProviderScope(
        overrides: <Override>[
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.signedIn(
                AuthUser(id: 'user-1', email: 'test@example.com'),
              ),
            ),
          ),
          billingGatewayProvider.overrideWithValue(store),
          billingRepositoryProvider.overrideWithValue(
            const _CreditRepository(),
          ),
          subscriptionBillingRepositoryProvider.overrideWithValue(
            subscriptionRepository,
          ),
          billingCatalogDelayProvider.overrideWithValue((_) async {}),
          appToastPresenterProvider.overrideWithValue(
            toasts ?? _RecordingToastPresenter(),
          ),
        ],
        child: CupertinoApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CreditPurchasePage(initialMode: mode),
        ),
      ),
    ),
  );
  for (int i = 0; i < 12; i++) {
    await tester.pump();
  }
}

class _Store implements BillingGateway, SubscriptionStoreGateway {
  _Store({this.purchaseResult});

  final Future<BillingPurchaseOutcome> Function()? purchaseResult;
  final List<String> offeringIds = <String>[];
  int purchaseCount = 0;

  @override
  bool get isPurchaseAvailable => true;

  @override
  Future<void> logIn(String appUserId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<List<BillingProduct>> fetchProducts() =>
      fetchProductsForOffering('credits');

  @override
  Future<List<BillingProduct>> fetchProductsForOffering(
    String offeringId,
  ) async {
    offeringIds.add(offeringId);
    return <BillingProduct>[
      BillingProduct(
        productId: offeringId == 'subscription'
            ? 'tessercam_plus_monthly'
            : 'tessercam_credits_40_v2',
        credits: 0,
        displayRank: 0,
        price: r'$9.99',
        packageIdentifier: offeringId,
        offeringIdentifier: offeringId,
      ),
    ];
  }

  @override
  Future<BillingPurchaseOutcome> purchaseProduct(BillingProduct product) {
    purchaseCount += 1;
    return purchaseResult?.call() ??
        Future.value(const BillingPurchaseCancelled());
  }

  @override
  Future<void> restorePurchases() async {}
}

class _CreditRepository implements BillingRepository {
  const _CreditRepository();

  @override
  Future<List<CreditProduct>> fetchProducts() async => const <CreditProduct>[
    CreditProduct(
      productId: 'tessercam_credits_40_v2',
      displayNameKey: 'Standard',
      credits: 40,
      displayRank: 0,
    ),
  ];

  @override
  Future<CreditPurchaseSyncResult> syncRevenueCatPurchases() async =>
      const CreditPurchaseSyncResult(
        grantedCredits: 0,
        processedPurchases: 0,
        balance: 0,
        products: <CreditProduct>[],
      );
}

const SubscriptionAccess _activePlus = SubscriptionAccess(
  active: true,
  tier: SubscriptionTier.plus,
  productIdentifier: 'tessercam_plus_monthly',
  willRenew: true,
  accessEndIsFinal: false,
  syncFreshness: 'fresh',
);

class _SubscriptionRepository implements SubscriptionBillingRepository {
  const _SubscriptionRepository({
    this.active = false,
    this.syncPending = false,
    this.subscribedAtStart = false,
    this.withFullCost = true,
  });

  final bool active;
  final bool syncPending;
  final bool subscribedAtStart;
  final bool withFullCost;

  @override
  Future<SubscriptionBillingStatus> fetchStatus() async =>
      _status(subscribedAtStart);

  @override
  Future<SubscriptionBillingStatus> syncRevenueCatPurchases() async {
    if (syncPending) {
      throw const BackendApiFailure(
        code: 'billing_sync_pending',
        message: 'pending',
      );
    }
    return _status(active);
  }

  SubscriptionBillingStatus _status(bool subscribed) =>
      SubscriptionBillingStatus(
        subscription: subscribed ? _activePlus : null,
        billingEnvironment: 'SANDBOX',
        capabilities: BillingCapabilities(
          maxEnabled: false,
          qualityTiers: <String>{'full'},
        ),
        plans: <SubscriptionPlan>[
          SubscriptionPlan(
            productIdentifier: 'tessercam_plus_monthly',
            tier: SubscriptionTier.plus,
            displayOrder: 1,
            fullAllowanceUnits: 34,
            overflowAllowanceUnits: 20,
            maxEnabled: true,
            revision: 1,
          ),
        ],
        qualityTiers: <QualityTierCost>[
          if (withFullCost)
            QualityTierCost(
              qualityTier: 'full',
              allowanceUnits: 2,
              revision: 1,
            ),
        ],
      );
}

class _RecordingToastPresenter extends AppToastPresenter {
  final List<AppToastMessage> messages = <AppToastMessage>[];

  List<String> get titles =>
      messages.map((AppToastMessage message) => message.title).toList();

  List<AppToastType> get types =>
      messages.map((AppToastMessage message) => message.type).toList();

  @override
  void show(AppToastMessage message) {
    messages.add(message);
  }
}
