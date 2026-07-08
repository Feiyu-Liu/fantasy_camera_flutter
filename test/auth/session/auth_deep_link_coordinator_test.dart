import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_camera_flutter/auth/session/auth_deep_link_coordinator.dart';

void main() {
  test('exchanges password reset links that carry a PKCE code', () async {
    final _FakeAuthDeepLinkSessionExchanger exchanger =
        _FakeAuthDeepLinkSessionExchanger();
    final AuthDeepLinkCoordinator coordinator = AuthDeepLinkCoordinator(
      provider: _FakeAuthDeepLinkProvider(),
      sessionExchanger: exchanger,
    );

    final Uri uri = Uri.parse(
      'host.eunoia.tessercam://password-reset/?code=recovery-code',
    );

    await coordinator.debugHandleLink(uri);

    expect(exchanger.exchangedUris, <Uri>[uri]);
  });

  test('exchanges login callback links that carry a PKCE code', () async {
    final _FakeAuthDeepLinkSessionExchanger exchanger =
        _FakeAuthDeepLinkSessionExchanger();
    final AuthDeepLinkCoordinator coordinator = AuthDeepLinkCoordinator(
      provider: _FakeAuthDeepLinkProvider(),
      sessionExchanger: exchanger,
    );

    final Uri uri = Uri.parse(
      'host.eunoia.tessercam://login-callback/?code=login-code',
    );

    await coordinator.debugHandleLink(uri);

    expect(exchanger.exchangedUris, <Uri>[uri]);
  });

  test('ignores unknown schemes and hosts', () async {
    final _FakeAuthDeepLinkSessionExchanger exchanger =
        _FakeAuthDeepLinkSessionExchanger();
    final AuthDeepLinkCoordinator coordinator = AuthDeepLinkCoordinator(
      provider: _FakeAuthDeepLinkProvider(),
      sessionExchanger: exchanger,
    );

    await coordinator.debugHandleLink(
      Uri.parse('https://tessercam.flyingfish.cc/auth/callback?code=web'),
    );
    await coordinator.debugHandleLink(
      Uri.parse('host.eunoia.tessercam://unknown/?code=unknown'),
    );

    expect(exchanger.exchangedUris, isEmpty);
  });

  test('ignores auth callbacks without exchange payload', () async {
    final _FakeAuthDeepLinkSessionExchanger exchanger =
        _FakeAuthDeepLinkSessionExchanger();
    final AuthDeepLinkCoordinator coordinator = AuthDeepLinkCoordinator(
      provider: _FakeAuthDeepLinkProvider(),
      sessionExchanger: exchanger,
    );

    await coordinator.debugHandleLink(
      Uri.parse('host.eunoia.tessercam://password-reset/'),
    );
    await coordinator.debugHandleLink(
      Uri.parse('host.eunoia.tessercam://password-reset/?code=recovery-code'),
    );

    expect(exchanger.exchangedUris, <Uri>[
      Uri.parse('host.eunoia.tessercam://password-reset/?code=recovery-code'),
    ]);
  });

  test('deduplicates repeated links', () async {
    final _FakeAuthDeepLinkSessionExchanger exchanger =
        _FakeAuthDeepLinkSessionExchanger();
    final AuthDeepLinkCoordinator coordinator = AuthDeepLinkCoordinator(
      provider: _FakeAuthDeepLinkProvider(),
      sessionExchanger: exchanger,
    );

    final Uri uri = Uri.parse(
      'host.eunoia.tessercam://password-reset/?code=recovery-code',
    );

    await coordinator.debugHandleLink(uri);
    await coordinator.debugHandleLink(uri);

    expect(exchanger.exchangedUris, <Uri>[uri]);
  });

  test('allows retrying the same link after exchange failure', () async {
    final _FakeAuthDeepLinkSessionExchanger exchanger =
        _FakeAuthDeepLinkSessionExchanger(failNextExchange: true);
    final AuthDeepLinkCoordinator coordinator = AuthDeepLinkCoordinator(
      provider: _FakeAuthDeepLinkProvider(),
      sessionExchanger: exchanger,
    );

    final Uri uri = Uri.parse(
      'host.eunoia.tessercam://password-reset/?code=recovery-code',
    );

    await coordinator.debugHandleLink(uri);
    await coordinator.debugHandleLink(uri);

    expect(exchanger.exchangedUris, <Uri>[uri, uri]);
    expect(exchanger.failures, 1);
  });

  test('start handles stream links and initial link once each', () async {
    final Uri initialUri = Uri.parse(
      'host.eunoia.tessercam://password-reset/?code=initial-code',
    );
    final Uri streamUri = Uri.parse(
      'host.eunoia.tessercam://login-callback/?code=stream-code',
    );
    final _FakeAuthDeepLinkProvider provider = _FakeAuthDeepLinkProvider(
      initialLink: initialUri,
    );
    final _FakeAuthDeepLinkSessionExchanger exchanger =
        _FakeAuthDeepLinkSessionExchanger();
    final AuthDeepLinkCoordinator coordinator = AuthDeepLinkCoordinator(
      provider: provider,
      sessionExchanger: exchanger,
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();
    provider.emit(streamUri);
    await Future<void>.delayed(Duration.zero);

    expect(exchanger.exchangedUris, <Uri>[initialUri, streamUri]);
  });

  test('safe summary redacts values and only exposes query keys', () {
    final String summary = safeAuthDeepLinkSummary(
      Uri.parse(
        'host.eunoia.tessercam://password-reset/'
        '?code=secret-code&token=secret-token&error_description=secret-error',
      ),
    );

    expect(summary, contains('scheme=host.eunoia.tessercam'));
    expect(summary, contains('host=password-reset'));
    expect(summary, contains('queryKeys=code|error_description|token'));
    expect(summary, contains('hasCode=true'));
    expect(summary, contains('hasError=true'));
    expect(summary, isNot(contains('secret-code')));
    expect(summary, isNot(contains('secret-token')));
    expect(summary, isNot(contains('secret-error')));
  });
}

class _FakeAuthDeepLinkProvider implements AuthDeepLinkProvider {
  _FakeAuthDeepLinkProvider({this.initialLink});

  final Uri? initialLink;
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async => initialLink;

  @override
  Stream<Uri> get uriLinkStream => _controller.stream;

  void emit(Uri uri) {
    _controller.add(uri);
  }
}

class _FakeAuthDeepLinkSessionExchanger
    implements AuthDeepLinkSessionExchanger {
  _FakeAuthDeepLinkSessionExchanger({this.failNextExchange = false});

  bool failNextExchange;
  int failures = 0;
  final List<Uri> exchangedUris = <Uri>[];

  @override
  Future<void> exchangeSession(Uri uri) async {
    exchangedUris.add(uri);
    if (failNextExchange) {
      failNextExchange = false;
      failures++;
      throw StateError('exchange failed');
    }
  }
}
