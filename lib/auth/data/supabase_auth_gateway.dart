import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../shared/core/app_logger.dart';
import '../domain/auth_session_snapshot.dart';
import '../domain/auth_user.dart';
import 'apple_sign_in_gateway.dart';
import 'auth_gateway.dart';

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway({
    required SupabaseClient client,
    required AppleSignInGateway appleSignInGateway,
  }) : _client = client,
       _appleSignInGateway = appleSignInGateway;

  final SupabaseClient _client;
  final AppleSignInGateway _appleSignInGateway;

  @override
  AuthSessionSnapshot? get currentSession =>
      _snapshotFromSession(_client.auth.currentSession);

  @override
  Stream<AuthGatewayEvent> get authStateChanges {
    return _client.auth.onAuthStateChange.map((AuthState state) {
      return AuthGatewayEvent(
        type: _eventTypeFor(state.event),
        session: _snapshotFromSession(state.session),
      );
    });
  }

  @override
  Future<AuthSessionSnapshot?> restoreCurrentSession() async {
    return currentSession;
  }

  @override
  Future<AuthSessionSnapshot?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final AuthResponse response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return _snapshotFromSession(response.session);
  }

  @override
  Future<AuthSessionSnapshot?> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    final AuthResponse response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    return _snapshotFromSession(response.session);
  }

  @override
  Future<AuthSessionSnapshot?> signInWithApple() async {
    final AppleSignInCredentialPayload credential;
    try {
      credential = await _appleSignInGateway.requestCredential();
    } on AppleSignInRequestCanceledException {
      throw const AppleSignInCanceledException();
    }

    final AuthResponse response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: credential.identityToken,
      nonce: credential.rawNonce,
    );
    await _persistAppleNameIfAvailable(credential);
    return _snapshotFromSession(response.session);
  }

  @override
  Future<AuthSessionSnapshot?> refreshSession() async {
    final AuthResponse response = await _client.auth.refreshSession();
    return _snapshotFromSession(response.session);
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }

  Future<void> _persistAppleNameIfAvailable(
    AppleSignInCredentialPayload credential,
  ) async {
    final List<String> nameParts = <String>[
      if (credential.givenName?.trim().isNotEmpty ?? false)
        credential.givenName!.trim(),
      if (credential.familyName?.trim().isNotEmpty ?? false)
        credential.familyName!.trim(),
    ];
    if (nameParts.isEmpty) {
      return;
    }

    try {
      await _client.auth.updateUser(
        UserAttributes(
          data: <String, dynamic>{
            'full_name': nameParts.join(' '),
            if (credential.givenName != null)
              'given_name': credential.givenName,
            if (credential.familyName != null)
              'family_name': credential.familyName,
          },
        ),
      );
    } on Object catch (error, stackTrace) {
      logAppError('apple_name_persist_failed', error, stackTrace);
    }
  }
}

AuthGatewayEventType _eventTypeFor(AuthChangeEvent event) {
  return switch (event) {
    AuthChangeEvent.signedIn => AuthGatewayEventType.signedIn,
    AuthChangeEvent.signedOut => AuthGatewayEventType.signedOut,
    AuthChangeEvent.tokenRefreshed => AuthGatewayEventType.tokenRefreshed,
    AuthChangeEvent.userUpdated => AuthGatewayEventType.userUpdated,
    _ => AuthGatewayEventType.userUpdated,
  };
}

AuthSessionSnapshot? _snapshotFromSession(Session? session) {
  if (session == null) {
    return null;
  }

  final User user = session.user;
  return AuthSessionSnapshot(
    user: AuthUser(
      id: user.id,
      email: user.email ?? '',
      isAnonymous: user.isAnonymous,
    ),
    accessToken: session.accessToken,
    isExpired: session.isExpired,
  );
}
