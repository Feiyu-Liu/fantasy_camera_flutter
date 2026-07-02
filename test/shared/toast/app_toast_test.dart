import 'package:fantasy_camera_flutter/settings/application/app_settings.dart';
import 'package:fantasy_camera_flutter/shared/toast/app_toast.dart';
import 'package:fantasy_camera_flutter/theme/app_theme.dart';
import 'package:fantasy_camera_flutter/l10n/l10n.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppToastCard renders title and message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _ToastTestHost(
        child: AppToastCard(
          message: AppToastMessage(
            type: AppToastType.error,
            title: 'Upload failed',
            message: 'Please try again.',
          ),
        ),
      ),
    );

    expect(find.text('Upload failed'), findsOneWidget);
    expect(find.text('Please try again.'), findsOneWidget);
  });

  testWidgets('AppToastHost keeps child visible', (WidgetTester tester) async {
    await tester.pumpWidget(
      const _ToastTestHost(child: AppToastHost(child: Text('Camera content'))),
    );

    expect(find.text('Camera content'), findsOneWidget);
  });

  testWidgets(
    'toast service uses current context localizations after locale changes',
    (WidgetTester tester) async {
      final _RecordingAppToastPresenter presenter =
          _RecordingAppToastPresenter();
      final ValueNotifier<Locale> locale = ValueNotifier<Locale>(
        const Locale('zh'),
      );
      addTearDown(locale.dispose);

      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (BuildContext context, Locale value, Widget? child) {
            return ProviderScope(
              overrides: <Override>[
                appToastPresenterProvider.overrideWithValue(presenter),
              ],
              child: _ToastTestHost(
                locale: value,
                child: const _FavoriteFailureToastButton(),
              ),
            );
          },
        ),
      );

      await tester.tap(find.byKey(_favoriteFailureButtonKey));
      expect(presenter.messages.single.title, '无法更新系统收藏，请稍后重试。');

      presenter.messages.clear();
      locale.value = const Locale('en');
      await tester.pump();

      await tester.tap(find.byKey(_favoriteFailureButtonKey));

      expect(
        presenter.messages.single.title,
        "Couldn't save to Favorites. Try again later.",
      );
    },
  );
}

class _ToastTestHost extends StatelessWidget {
  const _ToastTestHost({required this.child, this.locale});

  final Widget child;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppThemeColorsScope(
        colors: appThemeColorsForPreference(AppThemePreference.light),
        child: CupertinoPageScaffold(child: Center(child: child)),
      ),
    );
  }
}

const ValueKey<String> _favoriteFailureButtonKey = ValueKey<String>(
  'favorite-failure-toast-button',
);

class _FavoriteFailureToastButton extends ConsumerWidget {
  const _FavoriteFailureToastButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoButton(
      key: _favoriteFailureButtonKey,
      onPressed: () {
        ref.read(appToastServiceProvider).showFavoriteFailure(context.l10n);
      },
      child: const Text('show'),
    );
  }
}

class _RecordingAppToastPresenter extends AppToastPresenter {
  final List<AppToastMessage> messages = <AppToastMessage>[];

  @override
  void show(AppToastMessage message) {
    messages.add(message);
  }
}
