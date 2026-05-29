import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ui/my_ui.dart';

import 'package:fantasy_camera_flutter/app/fantasy_camera_app.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_session_state.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_user.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_page.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_providers.dart';
import 'package:fantasy_camera_flutter/features/camera/domain/camera_choice.dart';

void main() {
  testWidgets('shows auth page when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(
      FantasyCameraApp(
        overrides: <Override>[
          hasSupabaseConfigProvider.overrideWithValue(true),
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.signedOut(),
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);
  });

  testWidgets('shows camera screen when signed in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      FantasyCameraApp(
        overrides: <Override>[
          hasSupabaseConfigProvider.overrideWithValue(true),
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.signedIn(
                AuthUser(id: 'user-1', email: 'user@example.com'),
              ),
            ),
          ),
          signedInCameraChoicesProvider.overrideWith(
            (_) async => const <CameraChoice>[],
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CameraPhotoUi), findsOneWidget);
  });

  testWidgets('shows restoring loading state', (WidgetTester tester) async {
    await tester.pumpWidget(
      FantasyCameraApp(
        overrides: <Override>[
          hasSupabaseConfigProvider.overrideWithValue(true),
          authSessionProvider.overrideWith(
            (_) => Stream<AuthSessionState>.value(
              const AuthSessionState.restoring(),
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });
}
