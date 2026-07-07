import 'package:fantasy_camera_flutter/auth/domain/auth_session_state.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_user.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_providers.dart';
import 'package:fantasy_camera_flutter/billing/data/billing_repositories.dart';
import 'package:fantasy_camera_flutter/billing/data/revenuecat_billing_gateway.dart';
import 'package:fantasy_camera_flutter/billing/domain/billing_product.dart';
import 'package:fantasy_camera_flutter/billing/domain/credit_product.dart';
import 'package:fantasy_camera_flutter/billing/presentation/billing_providers.dart';
import 'package:fantasy_camera_flutter/billing/presentation/credit_purchase_page.dart';
import 'package:fantasy_camera_flutter/config/app_config.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/credit_balance_cache_repository.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/credit_balance.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/credit_redemption.dart';
import 'package:fantasy_camera_flutter/features/backend_api/presentation/backend_api_providers.dart';
import 'package:fantasy_camera_flutter/l10n/l10n.dart';
import 'package:fantasy_camera_flutter/settings/application/app_settings.dart';
import 'package:fantasy_camera_flutter/shared/platform/external_link_launcher.dart';
import 'package:fantasy_camera_flutter/shared/toast/app_toast.dart';
import 'package:fantasy_camera_flutter/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not render redemption code panel', (
    WidgetTester tester,
  ) async {
    final _FakeCreditsRepository creditsRepository = _FakeCreditsRepository();
    await tester.pumpCreditPurchasePage(creditsRepository: creditsRepository);

    expect(find.text('兑换码'), findsNothing);
    expect(find.text('输入兑换码'), findsNothing);
    expect(creditsRepository.redeemedCode, isNull);
  });

  testWidgets('footer legal links open configured URLs', (
    WidgetTester tester,
  ) async {
    final _FakeCreditsRepository creditsRepository = _FakeCreditsRepository();
    final _RecordingExternalLinkLauncher externalLinkLauncher =
        _RecordingExternalLinkLauncher();
    await tester.pumpCreditPurchasePage(
      creditsRepository: creditsRepository,
      externalLinkLauncher: externalLinkLauncher,
    );

    await tester.tap(find.text('隐私政策'));
    await tester.pump();
    await tester.tap(find.text('使用条款'));
    await tester.pump();

    expect(
      externalLinkLauncher.openedUris.map((Uri uri) => uri.toString()),
      <String>[AppConfig.privacyPolicyUrl, AppConfig.termsOfUseUrl],
    );
  });

  testWidgets('product card shows display name and credits', (
    WidgetTester tester,
  ) async {
    final _FakeCreditsRepository creditsRepository = _FakeCreditsRepository();
    await tester.pumpCreditPurchasePage(
      creditsRepository: creditsRepository,
      billingGateway: _FakeBillingGateway(
        products: const <BillingProduct>[
          BillingProduct(
            productId: 'tessercam_credits_6_v2',
            credits: 0,
            displayRank: 999,
            price: r'¥6.00',
            packageIdentifier: r'$rc_custom_6',
          ),
        ],
      ),
      billingRepository: _FakeBillingRepository(
        products: const <CreditProduct>[
          CreditProduct(
            productId: 'tessercam_credits_6_v2',
            displayNameKey: 'Mini',
            credits: 6,
            displayRank: 0,
          ),
        ],
      ),
    );

    expect(find.text('Mini'), findsOneWidget);
    expect(find.text('6 积分'), findsOneWidget);
    expect(find.text('一次性积分包'), findsNothing);
  });

  testWidgets('defaults to the second product when available', (
    WidgetTester tester,
  ) async {
    final _FakeBillingGateway billingGateway = _FakeBillingGateway(
      products: const <BillingProduct>[
        BillingProduct(
          productId: 'tessercam_credits_6_v2',
          credits: 0,
          displayRank: 999,
          price: r'¥6.00',
          packageIdentifier: r'$rc_custom_6',
        ),
        BillingProduct(
          productId: 'tessercam_credits_40_v2',
          credits: 0,
          displayRank: 999,
          price: r'¥30.00',
          packageIdentifier: r'$rc_custom_40',
        ),
      ],
    );
    await tester.pumpCreditPurchasePage(
      creditsRepository: _FakeCreditsRepository(),
      billingGateway: billingGateway,
      billingRepository: _FakeBillingRepository(
        products: const <CreditProduct>[
          CreditProduct(
            productId: 'tessercam_credits_6_v2',
            displayNameKey: 'Mini',
            credits: 6,
            displayRank: 0,
          ),
          CreditProduct(
            productId: 'tessercam_credits_40_v2',
            displayNameKey: 'Standard',
            credits: 40,
            displayRank: 1,
          ),
        ],
      ),
    );

    await tester.tap(find.text('购买'));
    await tester.pump();

    expect(billingGateway.purchasedProductIds, <String>[
      'tessercam_credits_40_v2',
    ]);
  });
}

extension on WidgetTester {
  Future<void> pumpCreditPurchasePage({
    required _FakeCreditsRepository creditsRepository,
    _FakeBillingGateway? billingGateway,
    _FakeBillingRepository? billingRepository,
    _RecordingExternalLinkLauncher? externalLinkLauncher,
  }) async {
    await binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => binding.setSurfaceSize(null));
    await pumpWidget(
      AppToastHost(
        child: ProviderScope(
          overrides: <Override>[
            authSessionProvider.overrideWith(
              (_) => Stream<AuthSessionState>.value(
                const AuthSessionState.signedIn(
                  AuthUser(id: 'user-1', email: 'alex@example.com'),
                ),
              ),
            ),
            billingGatewayProvider.overrideWithValue(
              billingGateway ?? _FakeBillingGateway(),
            ),
            billingRepositoryProvider.overrideWithValue(
              billingRepository ?? _FakeBillingRepository(),
            ),
            creditsRepositoryProvider.overrideWithValue(creditsRepository),
            creditBalanceCacheRepositoryProvider.overrideWithValue(
              _FakeCreditBalanceCacheRepository(),
            ),
            appToastPresenterProvider.overrideWithValue(
              _NoopAppToastPresenter(),
            ),
            if (externalLinkLauncher != null)
              externalLinkLauncherProvider.overrideWithValue(
                externalLinkLauncher.call,
              ),
          ],
          child: CupertinoApp(
            locale: const Locale('zh'),
            theme: appCupertinoThemeForPreference(AppThemePreference.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (BuildContext context, Widget? child) {
              return AppThemeColorsScope(
                colors: appThemeColorsForPreference(AppThemePreference.light),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const CreditPurchasePage(),
          ),
        ),
      ),
    );
    await pump();
    await pump();
  }
}

class _FakeBillingGateway implements BillingGateway {
  _FakeBillingGateway({this.products = const <BillingProduct>[]});

  final List<BillingProduct> products;
  final List<String> purchasedProductIds = <String>[];

  @override
  bool get isPurchaseAvailable => true;

  @override
  Future<List<BillingProduct>> fetchProducts() async {
    return products;
  }

  @override
  Future<void> logIn(String appUserId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<BillingPurchaseOutcome> purchaseProduct(BillingProduct product) async {
    purchasedProductIds.add(product.productId);
    return const BillingPurchaseCompleted();
  }

  @override
  Future<void> restorePurchases() async {}
}

class _FakeBillingRepository implements BillingRepository {
  _FakeBillingRepository({this.products = const <CreditProduct>[]});

  final List<CreditProduct> products;

  @override
  Future<List<CreditProduct>> fetchProducts() async {
    return products;
  }

  @override
  Future<CreditPurchaseSyncResult> syncRevenueCatPurchases() async {
    return const CreditPurchaseSyncResult(
      grantedCredits: 0,
      processedPurchases: 0,
      balance: null,
      products: <CreditProduct>[],
    );
  }
}

class _FakeCreditsRepository implements CreditsRepository {
  String? redeemedCode;

  @override
  Future<CreditBalance> fetchBalance() async {
    return CreditBalance(
      balance: 178,
      reservedBalance: 0,
      lifetimeEarned: 178,
      lifetimeSpent: 0,
      updatedAt: DateTime.utc(2026, 6, 27),
    );
  }

  @override
  Future<CreditRedemptionResult> redeemCode(String code) async {
    redeemedCode = code;
    return const CreditRedemptionResult(
      grantedCredits: 50,
      balance: 178,
      reservedBalance: 0,
      campaignId: 'campaign-1',
      codeId: 'code-1',
    );
  }
}

class _FakeCreditBalanceCacheRepository
    implements CreditBalanceCacheRepository {
  @override
  Future<CreditBalance?> loadBalance(String userId) async {
    return null;
  }

  @override
  Future<void> saveBalance(String userId, CreditBalance balance) async {}

  @override
  Future<void> clearBalance(String userId) async {}
}

class _NoopAppToastPresenter extends AppToastPresenter {
  @override
  void show(AppToastMessage message) {}
}

class _RecordingExternalLinkLauncher {
  final List<Uri> openedUris = <Uri>[];

  Future<bool> call(Uri uri) async {
    openedUris.add(uri);
    return true;
  }
}
