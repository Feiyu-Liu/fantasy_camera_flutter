import 'auth_user.dart';

enum AuthSessionStatus {
  restoring,
  signedOut,
  signingIn,
  signingUp,
  signedIn,
  refreshingToken,
  sessionExpired,
  signingOut,
}

class AuthSessionState {
  const AuthSessionState({required this.status, this.user, this.message});

  const AuthSessionState.restoring()
    : status = AuthSessionStatus.restoring,
      user = null,
      message = null;

  const AuthSessionState.signedOut({this.message})
    : status = AuthSessionStatus.signedOut,
      user = null;

  const AuthSessionState.signedIn(this.user)
    : status = AuthSessionStatus.signedIn,
      message = null;

  const AuthSessionState.sessionExpired({this.message})
    : status = AuthSessionStatus.sessionExpired,
      user = null;

  final AuthSessionStatus status;
  final AuthUser? user;
  final String? message;

  bool get isSignedIn => status == AuthSessionStatus.signedIn && user != null;
  bool get hasAuthenticatedUser => user != null;

  AuthSessionState copyWith({
    AuthSessionStatus? status,
    AuthUser? user,
    bool clearUser = false,
    String? message,
    bool clearMessage = false,
  }) {
    return AuthSessionState(
      status: status ?? this.status,
      user: clearUser ? null : user ?? this.user,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}
