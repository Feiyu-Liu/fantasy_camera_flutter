import 'dart:async';

import 'package:camera_avfoundation/camera_avfoundation.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ui/my_ui.dart';

import 'package:fantasy_camera_flutter/app/fantasy_camera_app.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_session_state.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_user.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_page.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_providers.dart';
import 'package:fantasy_camera_flutter/features/camera/data/camera_device_repository.dart';
import 'package:fantasy_camera_flutter/features/camera/domain/camera_choice.dart';
import 'package:fantasy_camera_flutter/features/camera/presentation/camera_providers.dart';

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

  testWidgets('camera trailing button opens generation debug modal', (
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

    await tester.tap(find.bySemanticsLabel('Switch UI'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>('generation-submission-gallery-picker'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('waits for camera choices before mounting camera screen', (
    WidgetTester tester,
  ) async {
    final Completer<List<CameraChoice>> cameraChoicesCompleter =
        Completer<List<CameraChoice>>();

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
            (_) => cameraChoicesCompleter.future,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.byType(CameraPhotoUi), findsNothing);
    expect(find.text('No camera found.'), findsNothing);
  });

  testWidgets('mounts camera screen after camera choices load', (
    WidgetTester tester,
  ) async {
    final Completer<List<CameraChoice>> cameraChoicesCompleter =
        Completer<List<CameraChoice>>();

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
            (_) => cameraChoicesCompleter.future,
          ),
        ],
      ),
    );
    await tester.pump();

    cameraChoicesCompleter.complete(const <CameraChoice>[]);
    await tester.pump();

    expect(find.byType(CameraPhotoUi), findsOneWidget);
  });

  testWidgets('loads camera choices after auth restores to signed in', (
    WidgetTester tester,
  ) async {
    final StreamController<AuthSessionState> authStates =
        StreamController<AuthSessionState>();
    addTearDown(authStates.close);
    final _FakeCameraDeviceRepository cameraDeviceRepository =
        _FakeCameraDeviceRepository();

    await tester.pumpWidget(
      FantasyCameraApp(
        overrides: <Override>[
          hasSupabaseConfigProvider.overrideWithValue(true),
          authSessionProvider.overrideWith((_) => authStates.stream),
          cameraDeviceRepositoryProvider.overrideWithValue(
            cameraDeviceRepository,
          ),
        ],
      ),
    );

    authStates.add(const AuthSessionState.restoring());
    await tester.pump();
    authStates.add(
      const AuthSessionState.signedIn(
        AuthUser(id: 'user-1', email: 'user@example.com'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(cameraDeviceRepository.loadCount, 1);
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

class _FakeCameraDeviceRepository extends CameraDeviceRepository {
  _FakeCameraDeviceRepository();

  int loadCount = 0;

  @override
  Future<List<CameraChoice>> loadCameraChoices() async {
    loadCount += 1;
    return const <CameraChoice>[
      CameraChoice(
        description: CameraDescription(
          name: 'back-camera',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
          lensType: CameraLensType.wide,
        ),
        label: 'wide',
        isVirtualDevice: false,
        deviceType: AVFoundationCaptureDeviceType.builtInWideAngleCamera,
      ),
    ];
  }
}
