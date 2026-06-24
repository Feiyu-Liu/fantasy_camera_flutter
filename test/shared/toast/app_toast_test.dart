import 'package:fantasy_camera_flutter/settings/application/app_settings.dart';
import 'package:fantasy_camera_flutter/shared/toast/app_toast.dart';
import 'package:fantasy_camera_flutter/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
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
}

class _ToastTestHost extends StatelessWidget {
  const _ToastTestHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      home: AppThemeColorsScope(
        colors: appThemeColorsForPreference(AppThemePreference.light),
        child: CupertinoPageScaffold(child: Center(child: child)),
      ),
    );
  }
}
