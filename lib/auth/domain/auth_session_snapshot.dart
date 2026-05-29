import 'auth_user.dart';

class AuthSessionSnapshot {
  const AuthSessionSnapshot({
    required this.user,
    required this.accessToken,
    required this.isExpired,
  });

  final AuthUser user;
  final String accessToken;
  final bool isExpired;
}
