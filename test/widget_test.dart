// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_camera_flutter/app/fantasy_camera_app.dart';
import 'package:fantasy_camera_flutter/features/notifications/presentation/notification_providers.dart';
import 'package:fantasy_camera_flutter/settings/application/app_settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('app shell reports missing Supabase config', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      FantasyCameraApp(
        initialSettings: const AppSettingsState(
          localePreference: AppLocalePreference.zh,
        ),
        overrides: _appShellTestOverrides(),
      ),
    );
    await tester.pump();

    expect(find.textContaining('缺少 Supabase 配置'), findsOneWidget);
  });

  testWidgets('app shell uses initial locale preference', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      FantasyCameraApp(
        initialSettings: const AppSettingsState(
          localePreference: AppLocalePreference.en,
        ),
        overrides: _appShellTestOverrides(),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('Missing Supabase configuration'),
      findsOneWidget,
    );
  });

  testWidgets('app shell uses initial light theme preference', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      FantasyCameraApp(
        initialSettings: const AppSettingsState(
          themePreference: AppThemePreference.light,
        ),
        overrides: _appShellTestOverrides(),
      ),
    );
    await tester.pump();

    final CupertinoApp app = tester.widget<CupertinoApp>(
      find.byType(CupertinoApp),
    );
    expect(app.theme?.brightness, Brightness.light);
  });

  testWidgets('app shell uses initial dark theme preference', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      FantasyCameraApp(
        initialSettings: const AppSettingsState(
          themePreference: AppThemePreference.dark,
        ),
        overrides: _appShellTestOverrides(),
      ),
    );
    await tester.pump();

    final CupertinoApp app = tester.widget<CupertinoApp>(
      find.byType(CupertinoApp),
    );
    expect(app.theme?.brightness, Brightness.dark);
  });
}

List<Override> _appShellTestOverrides() {
  return <Override>[
    notificationLifecycleProvider.overrideWith(_noopNotificationLifecycle),
  ];
}

void _noopNotificationLifecycle(Ref ref) {}
