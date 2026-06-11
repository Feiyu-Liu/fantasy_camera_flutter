import 'dart:async';

import '../../l10n/l10n.dart';
import '../../shared/core/app_logger.dart';
import '../data/auth_gateway.dart';
import '../domain/access_token_provider.dart';
import '../domain/auth_session_snapshot.dart';
import '../domain/auth_session_state.dart';

class SupabaseSessionCoordinator
    implements AccessTokenProvider, AppLocalizationsAware {
  SupabaseSessionCoordinator({required AuthGateway authGateway})
    : _authGateway = authGateway {
    _authSubscription = _authGateway.authStateChanges.listen(
      _handleAuthEvent,
      onError: (Object error, StackTrace stackTrace) {
        logAppError('auth_state_change_error', error, stackTrace);
      },
    );
  }

  final AuthGateway _authGateway;
  final StreamController<AuthSessionState> _stateController =
      StreamController<AuthSessionState>.broadcast();

  StreamSubscription<AuthGatewayEvent>? _authSubscription;
  AuthSessionState _state = const AuthSessionState.restoring();
  AppLocalizations _localizations = appLocalizationsFor(defaultAppLocale);
  Future<AuthSessionSnapshot?>? _refreshFuture;
  bool _signingOut = false;

  AuthSessionState get currentState => _state;

  Stream<AuthSessionState> get states async* {
    yield _state;
    yield* _stateController.stream;
  }

  @override
  void bindLocalizations(AppLocalizations localizations) {
    _localizations = localizations;
  }

  Future<void> restore() async {
    _setState(const AuthSessionState.restoring());
    try {
      final AuthSessionSnapshot? session = await _authGateway
          .restoreCurrentSession();
      if (session == null) {
        _setState(const AuthSessionState.signedOut());
        return;
      }
      _setState(AuthSessionState.signedIn(session.user));
    } on Object catch (error, stackTrace) {
      logAppError('auth_restore_failed', error, stackTrace);
      _setState(const AuthSessionState.signedOut());
    }
  }

  Future<void> markSigningIn(Future<AuthSessionSnapshot?> Function() action) {
    return _runAuthAction(AuthSessionStatus.signingIn, action);
  }

  Future<void> markSigningUp(Future<AuthSessionSnapshot?> Function() action) {
    return _runAuthAction(AuthSessionStatus.signingUp, action);
  }

  Future<void> signOut() async {
    if (_signingOut) {
      return;
    }
    _signingOut = true;
    _setState(_state.copyWith(status: AuthSessionStatus.signingOut));
    try {
      await _authGateway.signOut();
      _setState(const AuthSessionState.signedOut());
    } finally {
      _signingOut = false;
    }
  }

  @override
  Future<String?> ensureValidAccessToken() async {
    final AuthSessionSnapshot? session = _authGateway.currentSession;
    if (session == null) {
      return null;
    }
    if (!session.isExpired) {
      return session.accessToken;
    }
    return refreshAccessToken();
  }

  @override
  Future<String?> refreshAccessToken() async {
    final Future<AuthSessionSnapshot?> refreshFuture = _refreshFuture ??=
        _refreshSession();
    try {
      final AuthSessionSnapshot? session = await refreshFuture;
      return session?.accessToken;
    } finally {
      if (identical(_refreshFuture, refreshFuture)) {
        _refreshFuture = null;
      }
    }
  }

  Future<AuthSessionSnapshot?> _refreshSession() async {
    _setState(_state.copyWith(status: AuthSessionStatus.refreshingToken));
    try {
      final AuthSessionSnapshot? session = await _authGateway.refreshSession();
      if (session == null) {
        _setState(
          AuthSessionState.sessionExpired(
            message: _localizations.authSessionExpired,
          ),
        );
        return null;
      }
      _setState(AuthSessionState.signedIn(session.user));
      return session;
    } on Object catch (error, stackTrace) {
      logAppError('auth_refresh_failed', error, stackTrace);
      _setState(
        AuthSessionState.sessionExpired(
          message: _localizations.authSessionExpired,
        ),
      );
      return null;
    }
  }

  Future<void> _runAuthAction(
    AuthSessionStatus status,
    Future<AuthSessionSnapshot?> Function() action,
  ) async {
    _setState(_state.copyWith(status: status, clearMessage: true));
    final AuthSessionSnapshot? session = await action();
    if (session == null) {
      _setState(
        AuthSessionState.signedOut(
          message: _localizations.authAccountCreatedSignIn,
        ),
      );
      return;
    }
    _setState(AuthSessionState.signedIn(session.user));
  }

  void _handleAuthEvent(AuthGatewayEvent event) {
    switch (event.type) {
      case AuthGatewayEventType.signedIn:
      case AuthGatewayEventType.tokenRefreshed:
      case AuthGatewayEventType.userUpdated:
        final AuthSessionSnapshot? session = event.session;
        if (session != null) {
          _setState(AuthSessionState.signedIn(session.user));
        }
      case AuthGatewayEventType.signedOut:
        if (_signingOut) {
          _setState(const AuthSessionState.signedOut());
        } else {
          _setState(
            AuthSessionState.sessionExpired(
              message: _localizations.authSessionExpired,
            ),
          );
        }
    }
  }

  void _setState(AuthSessionState state) {
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _stateController.close();
  }
}
