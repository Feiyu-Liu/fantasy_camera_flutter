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

  test('restore maps missing session to signedOut', () async {
    final SupabaseSessionCoordinator coordinator = SupabaseSessionCoordinator(
      authGateway: _FakeAuthGateway(),
    );
    addTearDown(coordinator.dispose);

    await coordinator.restore();

    expect(coordinator.currentState.status, AuthSessionStatus.signedOut);
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
  int refreshCalls = 0;

  @override
  Stream<AuthGatewayEvent> get authStateChanges => _events.stream;

  @override
  AuthSessionSnapshot? get currentSession => current;

  void emit(AuthGatewayEvent event) {
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
  Future<AuthSessionSnapshot?> restoreCurrentSession() async => current;

  @override
  Future<AuthSessionSnapshot?> signInWithApple() async => current;

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
