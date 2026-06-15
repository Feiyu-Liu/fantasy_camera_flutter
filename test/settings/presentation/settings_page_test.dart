import 'dart:async';

import 'package:fantasy_camera_flutter/app/app_router.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_session_state.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_user.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_providers.dart';
import 'package:fantasy_camera_flutter/features/backend_api/data/backend_repositories.dart';
import 'package:fantasy_camera_flutter/features/backend_api/domain/credit_balance.dart';
import 'package:fantasy_camera_flutter/features/backend_api/presentation/backend_api_providers.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/application/generation_original_cache_cleaner.dart';
import 'package:fantasy_camera_flutter/features/generation_submission/presentation/generation_submission_providers.dart';
import 'package:fantasy_camera_flutter/l10n/l10n.dart';
import 'package:fantasy_camera_flutter/settings/application/app_settings.dart';
import 'package:fantasy_camera_flutter/settings/presentation/settings_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> pumpSettingsPage(
    WidgetTester tester, {
    _FakeAppSettingsRepository? appSettingsRepository,
    _FakeGenerationOriginalCacheCleaner? originalCacheCleaner,
    _FakeGenerationOriginalCacheStatsRepository? originalCacheStatsRepository,
  }) async {
    final _FakeAppSettingsRepository settingsRepository =
        appSettingsRepository ?? _FakeAppSettingsRepository();
    final _FakeGenerationOriginalCacheCleaner cacheCleaner =
        originalCacheCleaner ?? _FakeGenerationOriginalCacheCleaner();
    final _FakeGenerationOriginalCacheStatsRepository statsRepository =
        originalCacheStatsRepository ??
        _FakeGenerationOriginalCacheStatsRepository();
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
          appSettingsRepositoryProvider.overrideWithValue(settingsRepository),
          generationOriginalCacheCleanerProvider.overrideWithValue(
            cacheCleaner,
          ),
          generationOriginalCacheStatsRepositoryProvider.overrideWithValue(
            statsRepository,
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
    final _FakeAppSettingsRepository appSettingsRepository =
        _FakeAppSettingsRepository();
    await pumpSettingsPage(
      tester,
      appSettingsRepository: appSettingsRepository,
    );

    final Finder confirmSwitch = find.byKey(
      const ValueKey<String>('settings-confirm-before-generation-switch'),
    );

    expect(confirmSwitch, findsOneWidget);
    expect(tester.getSize(confirmSwitch), const Size(40, 22));

    await tester.tap(confirmSwitch);
    await tester.pumpAndSettle();

    expect(confirmSwitch, findsOneWidget);
    expect(appSettingsRepository.confirmBeforeGenerationEnabled, isFalse);
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

  testWidgets('clear original cache action runs cleaner and shows result', (
    WidgetTester tester,
  ) async {
    final _FakeGenerationOriginalCacheCleaner cacheCleaner =
        _FakeGenerationOriginalCacheCleaner(clearedCount: 3);
    await pumpSettingsPage(tester, originalCacheCleaner: cacheCleaner);

    await scrollDownUntilTextVisible(tester, '清除原图缓存');

    await tester.tap(find.text('清除原图缓存'));
    await tester.pumpAndSettle();

    expect(cacheCleaner.clearCallCount, 1);
    expect(cacheCleaner.statsCallCount, 2);
    expect(find.text('清理完成'), findsOneWidget);
    expect(find.text('已清除 3 张相机原图。'), findsOneWidget);
  });

  testWidgets('clear original cache row shows cached then latest size', (
    WidgetTester tester,
  ) async {
    final _FakeGenerationOriginalCacheStatsRepository statsRepository =
        _FakeGenerationOriginalCacheStatsRepository(
          cachedStats: GenerationOriginalCacheStats(
            fileCount: 1,
            totalBytes: 1024 * 1024,
            missingFileCount: 0,
            calculatedAt: DateTime.utc(2026, 6, 14),
          ),
        );
    final _FakeGenerationOriginalCacheCleaner cacheCleaner =
        _FakeGenerationOriginalCacheCleaner(
          stats: GenerationOriginalCacheStats(
            fileCount: 2,
            totalBytes: 2 * 1024 * 1024,
            missingFileCount: 0,
            calculatedAt: DateTime.utc(2026, 6, 15),
          ),
        );
    await pumpSettingsPage(
      tester,
      originalCacheCleaner: cacheCleaner,
      originalCacheStatsRepository: statsRepository,
    );

    await scrollDownUntilTextVisible(tester, '清除原图缓存');

    await statsRepository.waitForSave();
    for (
      int index = 0;
      index < 10 &&
          find
              .textContaining('2.00 MB', skipOffstage: false)
              .evaluate()
              .isEmpty;
      index++
    ) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(find.textContaining('2.00 MB', skipOffstage: false), findsOneWidget);
    expect(cacheCleaner.statsCallCount, 1);
    expect(statsRepository.savedStats?.totalBytes, 2 * 1024 * 1024);
  });

  testWidgets('clear original cache row keeps cached size while calculating', (
    WidgetTester tester,
  ) async {
    final Completer<void> statsCompleter = Completer<void>();
    final _FakeGenerationOriginalCacheStatsRepository statsRepository =
        _FakeGenerationOriginalCacheStatsRepository(
          cachedStats: GenerationOriginalCacheStats(
            fileCount: 1,
            totalBytes: 1024 * 1024,
            missingFileCount: 0,
            calculatedAt: DateTime.utc(2026, 6, 14),
          ),
        );
    final _FakeGenerationOriginalCacheCleaner cacheCleaner =
        _FakeGenerationOriginalCacheCleaner(
          statsDelay: statsCompleter.future,
          stats: GenerationOriginalCacheStats(
            fileCount: 2,
            totalBytes: 2 * 1024 * 1024,
            missingFileCount: 0,
            calculatedAt: DateTime.utc(2026, 6, 15),
          ),
        );
    await pumpSettingsPage(
      tester,
      originalCacheCleaner: cacheCleaner,
      originalCacheStatsRepository: statsRepository,
    );

    await scrollDownUntilTextVisible(tester, '清除原图缓存');

    expect(find.textContaining('1.00 MB'), findsOneWidget);

    statsCompleter.complete();
    await statsRepository.waitForSave();
    for (
      int index = 0;
      index < 10 &&
          find
              .textContaining('2.00 MB', skipOffstage: false)
              .evaluate()
              .isEmpty;
      index++
    ) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(find.textContaining('2.00 MB', skipOffstage: false), findsOneWidget);
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
          appSettingsRepositoryProvider.overrideWithValue(
            _FakeAppSettingsRepository(),
          ),
          generationOriginalCacheCleanerProvider.overrideWithValue(
            _FakeGenerationOriginalCacheCleaner(),
          ),
          generationOriginalCacheStatsRepositoryProvider.overrideWithValue(
            _FakeGenerationOriginalCacheStatsRepository(),
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

class _FakeAppSettingsRepository implements AppSettingsRepository {
  bool confirmBeforeGenerationEnabled = true;

  @override
  Future<bool> loadConfirmBeforeGenerationEnabled() async {
    return confirmBeforeGenerationEnabled;
  }

  @override
  Future<void> saveConfirmBeforeGenerationEnabled(bool value) async {
    confirmBeforeGenerationEnabled = value;
  }
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

class _FakeGenerationOriginalCacheCleaner
    implements GenerationOriginalCacheCleaner {
  _FakeGenerationOriginalCacheCleaner({
    this.clearedCount = 0,
    this.statsDelay,
    GenerationOriginalCacheStats? stats,
  }) : stats =
           stats ??
           GenerationOriginalCacheStats(
             fileCount: 0,
             totalBytes: 0,
             missingFileCount: 0,
             calculatedAt: DateTime.utc(2026, 6, 15),
           );

  final int clearedCount;
  final Future<void>? statsDelay;
  final GenerationOriginalCacheStats stats;
  int clearCallCount = 0;
  int statsCallCount = 0;

  @override
  Future<GenerationOriginalCacheStats>
  calculateClearableCameraOriginalCacheStats({
    bool Function()? shouldCancel,
  }) async {
    statsCallCount += 1;
    await statsDelay;
    return stats;
  }

  @override
  Future<GenerationOriginalCacheClearResult> clearCameraOriginalCache() async {
    clearCallCount += 1;
    return GenerationOriginalCacheClearResult(
      clearedCount: clearedCount,
      failedCount: 0,
    );
  }
}

class _FakeGenerationOriginalCacheStatsRepository
    implements GenerationOriginalCacheStatsRepository {
  _FakeGenerationOriginalCacheStatsRepository({this.cachedStats});

  GenerationOriginalCacheStats? cachedStats;
  GenerationOriginalCacheStats? savedStats;
  final Completer<void> _saveCompleter = Completer<void>();

  Future<void> waitForSave() {
    return _saveCompleter.future;
  }

  @override
  Future<GenerationOriginalCacheStats?> loadStats() async {
    return savedStats ?? cachedStats;
  }

  @override
  Future<void> saveStats(GenerationOriginalCacheStats stats) async {
    savedStats = stats;
    if (!_saveCompleter.isCompleted) {
      _saveCompleter.complete();
    }
  }
}
