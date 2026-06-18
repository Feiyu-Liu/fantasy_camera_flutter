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
import 'package:fantasy_camera_flutter/theme/app_theme.dart';
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

  testWidgets('app shell animates between light and dark themes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _AnimatedThemeProbe(preference: AppThemePreference.light),
    );
    await tester.pump();

    final Container lightContainer = tester.widget<Container>(
      find.byKey(_themeProbeKey),
    );
    expect(lightContainer.color, AppThemeColors.light.background);

    await tester.pumpWidget(
      const _AnimatedThemeProbe(preference: AppThemePreference.dark),
    );
    await tester.pump(const Duration(milliseconds: 140));

    final Container animatingContainer = tester.widget<Container>(
      find.byKey(_themeProbeKey),
    );
    expect(
      CupertinoTheme.of(tester.element(find.byKey(_themeProbeKey))).brightness,
      Brightness.dark,
    );
    expect(animatingContainer.color, isNot(AppThemeColors.light.background));
    expect(animatingContainer.color, isNot(AppThemeColors.dark.background));

    await tester.pump(const Duration(milliseconds: 200));

    final Container darkContainer = tester.widget<Container>(
      find.byKey(_themeProbeKey),
    );
    expect(darkContainer.color, AppThemeColors.dark.background);
  });
}

List<Override> _appShellTestOverrides() {
  return <Override>[
    notificationLifecycleProvider.overrideWith(_noopNotificationLifecycle),
  ];
}

void _noopNotificationLifecycle(Ref ref) {}

const ValueKey<String> _themeProbeKey = ValueKey<String>(
  'animated-theme-probe',
);

class _AnimatedThemeProbe extends StatelessWidget {
  const _AnimatedThemeProbe({required this.preference});

  final AppThemePreference preference;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(),
      child: AnimatedAppTheme(
        preference: preference,
        builder: (BuildContext context, CupertinoThemeData theme) {
          return CupertinoTheme(
            data: theme,
            child: Builder(
              builder: (BuildContext context) {
                return Container(
                  key: _themeProbeKey,
                  color: AppThemeColors.of(context).background,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
