import 'package:fantasy_camera_flutter/auth/domain/auth_session_state.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_user.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_providers.dart';
import 'package:fantasy_camera_flutter/billing/data/billing_repositories.dart';
import 'package:fantasy_camera_flutter/billing/data/revenuecat_billing_gateway.dart';
import 'package:fantasy_camera_flutter/billing/domain/billing_product.dart';
import 'package:fantasy_camera_flutter/billing/domain/credit_product.dart';
import 'package:fantasy_camera_flutter/billing/presentation/billing_providers.dart';
import 'package:fantasy_camera_flutter/billing/presentation/credit_purchase_page.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/credit_balance_cache_repository.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/credit_balance.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/credit_redemption.dart';
import 'package:fantasy_camera_flutter/features/backend_api/presentation/backend_api_providers.dart';
import 'package:fantasy_camera_flutter/l10n/l10n.dart';
import 'package:fantasy_camera_flutter/settings/application/app_settings.dart';
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
}

extension on WidgetTester {
  Future<void> pumpCreditPurchasePage({
    required _FakeCreditsRepository creditsRepository,
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
            billingGatewayProvider.overrideWithValue(_FakeBillingGateway()),
            billingRepositoryProvider.overrideWithValue(
              _FakeBillingRepository(),
            ),
            creditsRepositoryProvider.overrideWithValue(creditsRepository),
            creditBalanceCacheRepositoryProvider.overrideWithValue(
              _FakeCreditBalanceCacheRepository(),
            ),
            appToastPresenterProvider.overrideWithValue(
              _NoopAppToastPresenter(),
            ),
          ],
          child: CupertinoApp(
            locale: const Locale('zh'),
            theme: appCupertinoThemeForPreference(AppThemePreference.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (BuildContext context, Widget? child) {
              return ProviderScope(
                overrides: <Override>[
                  appLocalizationsProvider.overrideWithValue(context.l10n),
                ],
                child: AppThemeColorsScope(
                  colors: appThemeColorsForPreference(AppThemePreference.light),
                  child: child ?? const SizedBox.shrink(),
                ),
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
  @override
  bool get isPurchaseAvailable => true;

  @override
  Future<List<BillingProduct>> fetchProducts() async {
    return const <BillingProduct>[];
  }

  @override
  Future<void> logIn(String appUserId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<BillingPurchaseOutcome> purchaseProduct(BillingProduct product) async {
    return const BillingPurchaseCompleted();
  }

  @override
  Future<void> restorePurchases() async {}
}

class _FakeBillingRepository implements BillingRepository {
  @override
  Future<List<CreditProduct>> fetchProducts() async {
    return const <CreditProduct>[];
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
}

class _NoopAppToastPresenter extends AppToastPresenter {
  @override
  void show(AppToastMessage message) {}
}
