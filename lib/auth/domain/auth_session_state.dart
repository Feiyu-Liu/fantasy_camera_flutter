import 'auth_user.dart';

enum AuthSessionStatus {
  restoring,
  signedOut,
  signingIn,
  signingUp,
  passwordRecovery,
  signedIn,
  refreshingToken,
  sessionExpired,
  signingOut,
}

enum AuthSessionNotice { accountCreatedSignIn, sessionExpired }

class AuthSessionState {
  const AuthSessionState({required this.status, this.user, this.notice});

  const AuthSessionState.restoring()
    : status = AuthSessionStatus.restoring,
      user = null,
      notice = null;

  const AuthSessionState.signedOut({this.notice})
    : status = AuthSessionStatus.signedOut,
      user = null;

  const AuthSessionState.signedIn(this.user)
    : status = AuthSessionStatus.signedIn,
      notice = null;

  const AuthSessionState.passwordRecovery(this.user)
    : status = AuthSessionStatus.passwordRecovery,
      notice = null;

  const AuthSessionState.sessionExpired({this.notice})
    : status = AuthSessionStatus.sessionExpired,
      user = null;

  final AuthSessionStatus status;
  final AuthUser? user;
  final AuthSessionNotice? notice;

  bool get isSignedIn => status == AuthSessionStatus.signedIn && user != null;
  bool get hasAuthenticatedUser => user != null;

  AuthSessionState copyWith({
    AuthSessionStatus? status,
    AuthUser? user,
    bool clearUser = false,
    AuthSessionNotice? notice,
    bool clearNotice = false,
  }) {
    return AuthSessionState(
      status: status ?? this.status,
      user: clearUser ? null : user ?? this.user,
      notice: clearNotice ? null : notice ?? this.notice,
    );
  }
}
