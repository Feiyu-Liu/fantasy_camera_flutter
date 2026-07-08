import '../domain/auth_session_snapshot.dart';

enum AuthGatewayEventType {
  initialSession,
  passwordRecovery,
  signedIn,
  signedOut,
  tokenRefreshed,
  userUpdated,
}

class AuthGatewayEvent {
  const AuthGatewayEvent({required this.type, this.session});

  final AuthGatewayEventType type;
  final AuthSessionSnapshot? session;
}

abstract interface class AuthGateway {
  AuthSessionSnapshot? get currentSession;

  Stream<AuthGatewayEvent> get authStateChanges;

  Future<AuthSessionSnapshot?> restoreCurrentSession();

  Future<AuthSessionSnapshot?> signInWithPassword({
    required String email,
    required String password,
  });

  Future<AuthSessionSnapshot?> signUpWithPassword({
    required String email,
    required String password,
  });

  Future<void> requestPasswordReset({required String email});

  Future<AuthSessionSnapshot?> updatePassword({required String password});

  Future<AuthSessionSnapshot?> signInWithApple();

  Future<AuthSessionSnapshot?> signInWithGoogle();

  Future<AuthSessionSnapshot?> refreshSession();

  Future<void> signOut();
}

class AppleSignInCanceledException implements Exception {
  const AppleSignInCanceledException();
}

class GoogleSignInCanceledException implements Exception {
  const GoogleSignInCanceledException();
}
