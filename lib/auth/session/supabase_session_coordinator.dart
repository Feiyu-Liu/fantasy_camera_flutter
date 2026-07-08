import 'dart:async';

import '../../shared/core/app_logger.dart';
import '../data/auth_gateway.dart';
import '../domain/access_token_provider.dart';
import '../domain/auth_session_snapshot.dart';
import '../domain/auth_session_state.dart';

class SupabaseSessionCoordinator implements AccessTokenProvider {
  SupabaseSessionCoordinator({
    required AuthGateway authGateway,
    Duration initialSessionFallbackTimeout = const Duration(seconds: 3),
  }) : _initialSessionFallbackTimeout = initialSessionFallbackTimeout,
       _authGateway = authGateway {
    _authSubscription = _authGateway.authStateChanges.listen(
      _handleAuthEvent,
      onError: (Object error, StackTrace stackTrace) {
        logAppError('auth_state_change_error', error, stackTrace);
      },
    );
  }

  final AuthGateway _authGateway;
  final Duration _initialSessionFallbackTimeout;
  final StreamController<AuthSessionState> _stateController =
      StreamController<AuthSessionState>.broadcast();

  StreamSubscription<AuthGatewayEvent>? _authSubscription;
  Completer<AuthGatewayEvent?>? _initialSessionEventCompleter;
  AuthGatewayEvent? _lastInitialSessionEvent;
  AuthSessionState _state = const AuthSessionState.restoring();
  Future<AuthSessionSnapshot?>? _refreshFuture;
  bool _signingOut = false;

  AuthSessionState get currentState => _state;

  Stream<AuthSessionState> get states async* {
    yield _state;
    yield* _stateController.stream;
  }

  Future<void> restore() async {
    if (_isPasswordRecovery) {
      return;
    }
    _setState(const AuthSessionState.restoring());
    try {
      final AuthSessionSnapshot? session = await _authGateway
          .restoreCurrentSession();
      if (_isPasswordRecovery) {
        return;
      }
      if (session == null) {
        final AuthGatewayEvent? initialEvent =
            await _waitForInitialSessionEvent();
        if (_state.isSignedIn || _isPasswordRecovery) {
          return;
        }
        if (initialEvent?.session case final AuthSessionSnapshot session) {
          _setState(AuthSessionState.signedIn(session.user));
          return;
        }
        if (initialEvent?.type == AuthGatewayEventType.initialSession) {
          _setState(const AuthSessionState.signedOut());
          return;
        }
        final AuthSessionSnapshot? fallbackSession = await _authGateway
            .restoreCurrentSession();
        if (_isPasswordRecovery) {
          return;
        }
        if (fallbackSession != null) {
          _setState(AuthSessionState.signedIn(fallbackSession.user));
          return;
        }
        _setState(const AuthSessionState.signedOut());
        return;
      }
      _setState(AuthSessionState.signedIn(session.user));
    } on Object catch (error, stackTrace) {
      logAppError('auth_restore_failed', error, stackTrace);
      if (_isPasswordRecovery) {
        return;
      }
      _setState(const AuthSessionState.signedOut());
    }
  }

  Future<void> markSigningIn(Future<AuthSessionSnapshot?> Function() action) {
    return _runAuthAction(AuthSessionStatus.signingIn, action);
  }

  Future<void> markSigningUp(Future<AuthSessionSnapshot?> Function() action) {
    return _runAuthAction(AuthSessionStatus.signingUp, action);
  }

  Future<void> completePasswordRecovery(
    Future<AuthSessionSnapshot?> Function() action,
  ) async {
    final AuthSessionSnapshot? session = await action();
    if (session == null) {
      _setState(
        AuthSessionState.sessionExpired(
          notice: AuthSessionNotice.sessionExpired,
        ),
      );
      return;
    }
    _setState(AuthSessionState.signedIn(session.user));
  }

  Future<void> signOut() async {
    if (_signingOut) {
      return;
    }
    _signingOut = true;
    _setState(
      _state.copyWith(status: AuthSessionStatus.signingOut, clearUser: true),
    );
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
            notice: AuthSessionNotice.sessionExpired,
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
          notice: AuthSessionNotice.sessionExpired,
        ),
      );
      return null;
    }
  }

  Future<void> _runAuthAction(
    AuthSessionStatus status,
    Future<AuthSessionSnapshot?> Function() action,
  ) async {
    _setState(_state.copyWith(status: status, clearNotice: true));
    final AuthSessionSnapshot? session = await action();
    if (session == null) {
      _setState(
        AuthSessionState.signedOut(
          notice: AuthSessionNotice.accountCreatedSignIn,
        ),
      );
      return;
    }
    _setState(AuthSessionState.signedIn(session.user));
  }

  void _handleAuthEvent(AuthGatewayEvent event) {
    if (event.type == AuthGatewayEventType.initialSession) {
      _lastInitialSessionEvent = event;
      if (_initialSessionEventCompleter
          case final Completer<AuthGatewayEvent?> completer
          when !completer.isCompleted) {
        completer.complete(event);
      }
    }
    switch (event.type) {
      case AuthGatewayEventType.initialSession:
        if (_isPasswordRecovery) {
          return;
        }
        final AuthSessionSnapshot? session = event.session;
        if (session != null) {
          _setState(AuthSessionState.signedIn(session.user));
        } else if (_state.status == AuthSessionStatus.restoring) {
          _setState(const AuthSessionState.signedOut());
        }
      case AuthGatewayEventType.passwordRecovery:
        final AuthSessionSnapshot? session = event.session;
        if (session != null) {
          _setState(AuthSessionState.passwordRecovery(session.user));
        } else {
          _setState(
            AuthSessionState.sessionExpired(
              notice: AuthSessionNotice.sessionExpired,
            ),
          );
        }
      case AuthGatewayEventType.signedIn:
      case AuthGatewayEventType.tokenRefreshed:
      case AuthGatewayEventType.userUpdated:
        final AuthSessionSnapshot? session = event.session;
        if (session != null &&
            _state.status != AuthSessionStatus.passwordRecovery) {
          _setState(AuthSessionState.signedIn(session.user));
        }
      case AuthGatewayEventType.signedOut:
        if (_signingOut) {
          _setState(const AuthSessionState.signedOut());
        } else {
          _setState(
            AuthSessionState.sessionExpired(
              notice: AuthSessionNotice.sessionExpired,
            ),
          );
        }
    }
  }

  Future<AuthGatewayEvent?> _waitForInitialSessionEvent() {
    if (_lastInitialSessionEvent case final AuthGatewayEvent event) {
      return Future<AuthGatewayEvent?>.value(event);
    }
    if (_initialSessionFallbackTimeout <= Duration.zero) {
      return Future<AuthGatewayEvent?>.value();
    }
    final Completer<AuthGatewayEvent?> completer =
        _initialSessionEventCompleter ??= Completer<AuthGatewayEvent?>();
    return completer.future.timeout(
      _initialSessionFallbackTimeout,
      onTimeout: () => null,
    );
  }

  bool get _isPasswordRecovery =>
      _state.status == AuthSessionStatus.passwordRecovery;

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
