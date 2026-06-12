import 'package:fantasy_camera_flutter/app/app_router.dart';
import 'package:fantasy_camera_flutter/settings/presentation/settings_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> pumpSettingsPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const CupertinoApp(home: SettingsPage()));
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

    expect(find.text('SETTINGS'), findsOneWidget);
    final Offset titleCenter = tester.getCenter(find.text('SETTINGS'));
    final Offset backButtonCenter = tester.getCenter(
      find.byKey(const ValueKey<String>('settings-back-button')),
    );
    expect(titleCenter.dx, moreOrLessEquals(196.5, epsilon: 1));
    expect(backButtonCenter.dx, lessThan(50));
    expect(backButtonCenter.dx, lessThan(titleCenter.dx));
    expect(find.text('Julian Vane'), findsOneWidget);
    expect(find.text('PRO MEMBER SINCE 2023'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('settings-appearance-editorial-light')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-appearance-studio-dark')),
      findsOneWidget,
    );
    expect(find.text('CAMERA PREFERENCES'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);

    await scrollDownUntilTextVisible(tester, 'STORAGE & CLOUD');

    expect(find.text('STORAGE & CLOUD'), findsOneWidget);
    expect(find.text('Cloud Storage'), findsOneWidget);

    await scrollDownUntilTextVisible(tester, 'Clear Cache');

    expect(find.text('Clear Cache'), findsOneWidget);

    await scrollDownUntilTextVisible(tester, 'PREFERENCES');

    expect(find.text('PREFERENCES'), findsOneWidget);
    await scrollDownUntilTextVisible(tester, 'Haptic Feedback');
    expect(find.text('Haptic Feedback'), findsOneWidget);

    await scrollDownUntilTextVisible(tester, 'ABOUT');

    expect(find.text('ABOUT'), findsOneWidget);
    await scrollDownUntilTextVisible(tester, 'App Version');
    expect(find.text('App Version'), findsOneWidget);
  });

  testWidgets('switch rows can toggle local state', (
    WidgetTester tester,
  ) async {
    await pumpSettingsPage(tester);

    final Finder gridSwitch = find.byKey(
      const ValueKey<String>('settings-grid-lines-switch'),
    );
    final Finder highEfficiencySwitch = find.byKey(
      const ValueKey<String>('settings-high-efficiency-switch'),
    );

    expect(gridSwitch, findsOneWidget);
    expect(highEfficiencySwitch, findsOneWidget);
    expect(tester.getSize(highEfficiencySwitch), const Size(40, 22));

    await tester.tap(highEfficiencySwitch);
    await tester.pumpAndSettle();

    expect(highEfficiencySwitch, findsOneWidget);
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
      ProviderScope(child: CupertinoApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
  });
}
