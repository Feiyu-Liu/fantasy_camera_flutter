import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_camera_flutter/auth/data/auth_gateway.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_session_snapshot.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_session_state.dart';
import 'package:fantasy_camera_flutter/auth/domain/auth_user.dart';
import 'package:fantasy_camera_flutter/auth/session/supabase_session_coordinator.dart';

void main() {
  test('restore maps existing session to signedIn', () async {
    final _FakeAuthGateway gateway = _FakeAuthGateway(
      current: _session(accessToken: 'token'),
    );
    final SupabaseSessionCoordinator coordinator = SupabaseSessionCoordinator(
      authGateway: gateway,
    );
    addTearDown(coordinator.dispose);

    await coordinator.restore();

    expect(coordinator.currentState.status, AuthSessionStatus.signedIn);
    expect(coordinator.currentState.user?.id, 'user-1');
  });

  test('restore maps confirmed missing initial session to signedOut', () async {
    final _FakeAuthGateway gateway = _FakeAuthGateway();
    final SupabaseSessionCoordinator coordinator = SupabaseSessionCoordinator(
      authGateway: gateway,
    );
    addTearDown(coordinator.dispose);

    final Future<void> restore = coordinator.restore();
    await Future<void>.delayed(Duration.zero);
    gateway.emit(
      const AuthGatewayEvent(type: AuthGatewayEventType.initialSession),
    );
    await restore;

    expect(coordinator.currentState.status, AuthSessionStatus.signedOut);
  });

  test('restore waits for delayed initial session before signedOut', () async {
    final _FakeAuthGateway gateway = _FakeAuthGateway();
    final SupabaseSessionCoordinator coordinator = SupabaseSessionCoordinator(
      authGateway: gateway,
      initialSessionFallbackTimeout: const Duration(milliseconds: 100),
    );
    addTearDown(coordinator.dispose);
    final List<AuthSessionStatus> statuses = <AuthSessionStatus>[];
    final StreamSubscription<AuthSessionState> subscription = coordinator.states
        .listen((AuthSessionState state) => statuses.add(state.status));
    addTearDown(subscription.cancel);

    final Future<void> restore = coordinator.restore();
    await Future<void>.delayed(Duration.zero);
    gateway.emit(
      AuthGatewayEvent(
        type: AuthGatewayEventType.initialSession,
        session: _session(accessToken: 'token'),
      ),
    );
    await restore;

    expect(coordinator.currentState.status, AuthSessionStatus.signedIn);
    expect(statuses, isNot(contains(AuthSessionStatus.signedOut)));
  });

  test('restore falls back to current session after missing initial event', () async {
    final _FakeAuthGateway gateway = _FakeAuthGateway();
    final SupabaseSessionCoordinator coordinator = SupabaseSessionCoordinator(
      authGateway: gateway,
      initialSessionFallbackTimeout: const Duration(milliseconds: 10),
    );
    addTearDown(coordinator.dispose);

    gateway.restoreResponses = <AuthSessionSnapshot?>[
      null,
      _session(accessToken: 'fallback-token'),
    ];

    await coordinator.restore();

    expect(coordinator.currentState.status, AuthSessionStatus.signedIn);
    expect(coordinator.currentState.user?.id, 'user-1');
    expect(gateway.restoreCalls, 2);
  });

  test('restore falls back to signedOut when no initial event or session', () async {
    final _FakeAuthGateway gateway = _FakeAuthGateway();
    final SupabaseSessionCoordinator coordinator = SupabaseSessionCoordinator(
      authGateway: gateway,
      initialSessionFallbackTimeout: Duration.zero,
    );
    addTearDown(coordinator.dispose);

    await coordinator.restore();

    expect(coordinator.currentState.status, AuthSessionStatus.signedOut);
    expect(gateway.restoreCalls, 2);
  });

  test('ensureValidAccessToken returns current valid token', () async {
    final SupabaseSessionCoordinator coordinator = SupabaseSessionCoordinator(
      authGateway: _FakeAuthGateway(
        current: _session(accessToken: 'valid-token'),
      ),
    );
    addTearDown(coordinator.dispose);

    final String? token = await coordinator.ensureValidAccessToken();

    expect(token, 'valid-token');
  });

  test('refreshAccessToken is single-flight', () async {
    final _FakeAuthGateway gateway = _FakeAuthGateway(
      current: _session(accessToken: 'expired-token', isExpired: true),
    );
    final SupabaseSessionCoordinator coordinator = SupabaseSessionCoordinator(
      authGateway: gateway,
    );
    addTearDown(coordinator.dispose);

    final List<String?> tokens = await Future.wait(<Future<String?>>[
      coordinator.refreshAccessToken(),
      coordinator.refreshAccessToken(),
      coordinator.refreshAccessToken(),
    ]);

    expect(tokens, <String?>[
      'refreshed-token',
      'refreshed-token',
      'refreshed-token',
    ]);
    expect(gateway.refreshCalls, 1);
    expect(coordinator.currentState.status, AuthSessionStatus.signedIn);
  });

  test(
    'signedOut event outside active sign out becomes sessionExpired',
    () async {
      final _FakeAuthGateway gateway = _FakeAuthGateway(
        current: _session(accessToken: 'token'),
      );
      final SupabaseSessionCoordinator coordinator = SupabaseSessionCoordinator(
        authGateway: gateway,
      );
      addTearDown(coordinator.dispose);

      gateway.emit(
        const AuthGatewayEvent(type: AuthGatewayEventType.signedOut),
      );
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.currentState.status, AuthSessionStatus.sessionExpired);
    },
  );
}

AuthSessionSnapshot _session({
  required String accessToken,
  bool isExpired = false,
}) {
  return AuthSessionSnapshot(
    user: const AuthUser(id: 'user-1', email: 'user@example.com'),
    accessToken: accessToken,
    isExpired: isExpired,
  );
}

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({this.current});

  final StreamController<AuthGatewayEvent> _events =
      StreamController<AuthGatewayEvent>.broadcast();

  AuthSessionSnapshot? current;
  List<AuthSessionSnapshot?> restoreResponses = <AuthSessionSnapshot?>[];
  int refreshCalls = 0;
  int restoreCalls = 0;

  @override
  Stream<AuthGatewayEvent> get authStateChanges => _events.stream;

  @override
  AuthSessionSnapshot? get currentSession => current;

  void emit(AuthGatewayEvent event) {
    current = event.session;
    _events.add(event);
  }

  @override
  Future<AuthSessionSnapshot?> refreshSession() async {
    refreshCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    current = _session(accessToken: 'refreshed-token');
    return current;
  }

  @override
  Future<AuthSessionSnapshot?> restoreCurrentSession() async {
    restoreCalls++;
    if (restoreResponses.isNotEmpty) {
      current = restoreResponses.removeAt(0);
    }
    return current;
  }

  @override
  Future<AuthSessionSnapshot?> signInWithApple() async => current;

  @override
  Future<AuthSessionSnapshot?> signInWithGoogle() async => current;

  @override
  Future<AuthSessionSnapshot?> signInWithPassword({
    required String email,
    required String password,
  }) async => current;

  @override
  Future<AuthSessionSnapshot?> signUpWithPassword({
    required String email,
    required String password,
  }) async => current;

  @override
  Future<void> signOut() async {
    current = null;
    emit(const AuthGatewayEvent(type: AuthGatewayEventType.signedOut));
  }
}
