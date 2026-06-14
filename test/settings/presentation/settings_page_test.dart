import 'package:fantasy_camera_flutter/app/app_router.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_session_state.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_user.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_providers.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/credit_balance.dart';
import 'package:fantasy_camera_flutter/features/backend_api/presentation/backend_api_providers.dart';
import 'package:fantasy_camera_flutter/l10n/l10n.dart';
import 'package:fantasy_camera_flutter/settings/presentation/settings_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> pumpSettingsPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.signedIn(
                AuthUser(id: 'user-1', email: 'alex@example.com'),
              ),
            ),
          ),
          creditsRepositoryProvider.overrideWithValue(
            const _FakeCreditsRepository(),
          ),
        ],
        child: CupertinoApp(
          locale: defaultAppLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (BuildContext context, Widget? child) {
            return ProviderScope(
              overrides: <Override>[
                appLocalizationsProvider.overrideWithValue(context.l10n),
              ],
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> scrollDownUntilTextVisible(
    WidgetTester tester,
    String text,
  ) async {
    final Finder scrollable = find.byType(Scrollable);
    for (
      int index = 0;
      index < 8 && find.text(text).evaluate().isEmpty;
      index++
    ) {
      await tester.drag(scrollable, const Offset(0, -260));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('renders settings sections and profile header', (
    WidgetTester tester,
  ) async {
    await pumpSettingsPage(tester);

    expect(find.text('设置'), findsOneWidget);
    final Offset titleCenter = tester.getCenter(find.text('设置'));
    final Offset backButtonCenter = tester.getCenter(
      find.byKey(const ValueKey<String>('settings-back-button')),
    );
    expect(titleCenter.dx, moreOrLessEquals(196.5, epsilon: 1));
    expect(backButtonCenter.dx, lessThan(50));
    expect(backButtonCenter.dx, lessThan(titleCenter.dx));
    expect(find.text('alex'), findsOneWidget);
    expect(find.text('128 积分'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('settings-appearance-editorial-light')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-appearance-studio-dark')),
      findsOneWidget,
    );
    expect(find.text('拍摄'), findsOneWidget);
    expect(find.text('拍摄后图片生成确认'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);

    await scrollDownUntilTextVisible(tester, '通用');

    expect(find.text('通用'), findsOneWidget);
    expect(find.text('语言切换'), findsOneWidget);
    expect(find.text('清除原图缓存'), findsOneWidget);
    expect(find.text('购买积分'), findsOneWidget);

    await scrollDownUntilTextVisible(tester, '信息');

    expect(find.text('信息'), findsOneWidget);
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('使用条款'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    await scrollDownUntilTextVisible(tester, '联系开发者');
    expect(find.text('联系开发者'), findsOneWidget);

    await scrollDownUntilTextVisible(tester, '账号');

    expect(find.text('账号'), findsOneWidget);
    expect(find.text('注销账号'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
    expect(find.text('Grid Lines'), findsNothing);
    expect(find.text('Cloud Storage'), findsNothing);
  });

  testWidgets('switch rows can toggle local state', (
    WidgetTester tester,
  ) async {
    await pumpSettingsPage(tester);

    final Finder confirmSwitch = find.byKey(
      const ValueKey<String>('settings-confirm-before-generation-switch'),
    );

    expect(confirmSwitch, findsOneWidget);
    expect(tester.getSize(confirmSwitch), const Size(40, 22));

    await tester.tap(confirmSwitch);
    await tester.pumpAndSettle();

    expect(confirmSwitch, findsOneWidget);
  });

  testWidgets('appearance cards can switch selected mode', (
    WidgetTester tester,
  ) async {
    await pumpSettingsPage(tester);

    final Finder studioDark = find.byKey(
      const ValueKey<String>('settings-appearance-studio-dark'),
    );
    final Finder editorialLight = find.byKey(
      const ValueKey<String>('settings-appearance-editorial-light'),
    );

    expect(editorialLight, findsOneWidget);
    expect(studioDark, findsOneWidget);

    await tester.tap(studioDark);
    await tester.pumpAndSettle();

    expect(studioDark, findsOneWidget);
  });

  testWidgets('settings route builds page', (WidgetTester tester) async {
    final GoRouter router = createAppRouter();
    router.go(settingsRoute);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.signedIn(
                AuthUser(id: 'user-1', email: 'alex@example.com'),
              ),
            ),
          ),
          creditsRepositoryProvider.overrideWithValue(
            const _FakeCreditsRepository(),
          ),
        ],
        child: CupertinoApp.router(
          locale: defaultAppLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (BuildContext context, Widget? child) {
            return ProviderScope(
              overrides: <Override>[
                appLocalizationsProvider.overrideWithValue(context.l10n),
              ],
              child: child ?? const SizedBox.shrink(),
            );
          },
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}

class _FakeCreditsRepository implements CreditsRepository {
  const _FakeCreditsRepository();

  @override
  Future<CreditBalance> fetchBalance() async {
    return CreditBalance(
      balance: 128,
      reservedBalance: 0,
      lifetimeEarned: 128,
      lifetimeSpent: 0,
      updatedAt: DateTime.utc(2026, 6, 12),
    );
  }
}
