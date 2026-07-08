import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../shared/core/app_logger.dart';

abstract interface class AuthDeepLinkProvider {
  Future<Uri?> getInitialLink();

  Stream<Uri> get uriLinkStream;
}

class AppLinksAuthDeepLinkProvider implements AuthDeepLinkProvider {
  AppLinksAuthDeepLinkProvider({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialLink() {
    return _appLinks.getInitialLink();
  }

  @override
  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;
}

abstract interface class AuthDeepLinkSessionExchanger {
  Future<void> exchangeSession(Uri uri);
}

class SupabaseAuthDeepLinkSessionExchanger
    implements AuthDeepLinkSessionExchanger {
  const SupabaseAuthDeepLinkSessionExchanger();

  @override
  Future<void> exchangeSession(Uri uri) async {
    await Supabase.instance.client.auth.getSessionFromUrl(uri);
  }
}

class AuthDeepLinkCoordinator {
  AuthDeepLinkCoordinator({
    AuthDeepLinkProvider? provider,
    AuthDeepLinkSessionExchanger? sessionExchanger,
  }) : _provider = provider ?? AppLinksAuthDeepLinkProvider(),
       _sessionExchanger =
           sessionExchanger ?? const SupabaseAuthDeepLinkSessionExchanger();

  final AuthDeepLinkProvider _provider;
  final AuthDeepLinkSessionExchanger _sessionExchanger;
  final Set<String> _handledLinkDigests = <String>{};
  final Set<String> _inFlightLinkDigests = <String>{};
  StreamSubscription<Uri>? _linkSubscription;

  Future<void> start() async {
    if (_linkSubscription != null) {
      return;
    }

    _linkSubscription = _provider.uriLinkStream.listen(
      (Uri uri) {
        unawaited(_handleLink(uri, source: 'stream'));
      },
      onError: (Object error, StackTrace stackTrace) {
        logAppError('auth_deep_link_stream_failed', error, stackTrace);
      },
    );

    try {
      final Uri? initialLink = await _provider.getInitialLink();
      if (initialLink != null) {
        await _handleLink(initialLink, source: 'initial');
      }
    } on Object catch (error, stackTrace) {
      logAppError('auth_deep_link_initial_failed', error, stackTrace);
    }
  }

  Future<void> dispose() async {
    await _linkSubscription?.cancel();
    _linkSubscription = null;
    _handledLinkDigests.clear();
    _inFlightLinkDigests.clear();
  }

  @visibleForTesting
  Future<void> debugHandleLink(Uri uri, {String source = 'test'}) {
    return _handleLink(uri, source: source);
  }

  Future<void> _handleLink(Uri uri, {required String source}) async {
    if (!_isKnownAuthCallback(uri)) {
      return;
    }

    final String digest = _digestFor(uri);
    if (_handledLinkDigests.contains(digest) ||
        _inFlightLinkDigests.contains(digest)) {
      appDebugLog(
        'AuthDeepLink',
        'skip duplicate source=$source ${safeAuthDeepLinkSummary(uri)}',
      );
      return;
    }

    final bool canExchange = _hasExchangePayload(uri);
    appDebugLog(
      'AuthDeepLink',
      'received source=$source canExchange=$canExchange '
          '${safeAuthDeepLinkSummary(uri)}',
    );
    if (!canExchange) {
      return;
    }
    _inFlightLinkDigests.add(digest);

    try {
      await _sessionExchanger.exchangeSession(uri);
      _handledLinkDigests.add(digest);
      appDebugLog(
        'AuthDeepLink',
        'exchanged source=$source ${safeAuthDeepLinkSummary(uri)}',
      );
    } on Object catch (error, stackTrace) {
      logAppError('auth_deep_link_exchange_failed', error, stackTrace);
    } finally {
      _inFlightLinkDigests.remove(digest);
    }
  }
}

@visibleForTesting
String safeAuthDeepLinkSummary(Uri uri) {
  final List<String> queryKeys = uri.queryParameters.keys.toList()..sort();
  return 'scheme=${uri.scheme} host=${uri.host} path=${uri.path} '
      'queryKeys=${queryKeys.join('|')} '
      'hasCode=${uri.queryParameters.containsKey('code')} '
      'hasError=${uri.queryParameters.containsKey('error_description')}';
}

bool _isKnownAuthCallback(Uri uri) {
  return uri.scheme == AppConfig.authCallbackScheme &&
      (uri.host == 'login-callback' || uri.host == 'password-reset');
}

bool _hasExchangePayload(Uri uri) {
  return uri.queryParameters.containsKey('code') ||
      uri.queryParameters.containsKey('error_description');
}

String _digestFor(Uri uri) {
  return sha256.convert(utf8.encode(uri.toString())).toString();
}
