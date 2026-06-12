import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInCredentialPayload {
  const GoogleSignInCredentialPayload({
    required this.idToken,
    required this.accessToken,
  });

  final String idToken;
  final String accessToken;
}

abstract interface class GoogleSignInGateway {
  Future<GoogleSignInCredentialPayload> requestCredential();
}

class NativeGoogleSignInGateway implements GoogleSignInGateway {
  NativeGoogleSignInGateway({
    required String iosClientId,
    required String webClientId,
  }) : _iosClientId = iosClientId,
       _webClientId = webClientId;

  static const List<String> _scopes = <String>['email'];

  final String _iosClientId;
  final String _webClientId;
  Future<void>? _initializeFuture;

  @override
  Future<GoogleSignInCredentialPayload> requestCredential() async {
    try {
      return await _requestCredential();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleSignInRequestCanceledException();
      }
      rethrow;
    }
  }

  Future<GoogleSignInCredentialPayload> _requestCredential() async {
    await _initialize();

    final GoogleSignInAccount account = await GoogleSignIn.instance
        .authenticate(scopeHint: _scopes);

    final String? idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const GoogleSignInMissingIdTokenException();
    }

    final GoogleSignInClientAuthorization? cachedAuthorization = await account
        .authorizationClient
        .authorizationForScopes(_scopes);
    final GoogleSignInClientAuthorization authorization =
        cachedAuthorization ??
        await account.authorizationClient.authorizeScopes(_scopes);

    final String accessToken = authorization.accessToken;
    if (accessToken.isEmpty) {
      throw const GoogleSignInMissingAccessTokenException();
    }

    return GoogleSignInCredentialPayload(
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> _initialize() {
    return _initializeFuture ??= GoogleSignIn.instance.initialize(
      clientId: _iosClientId,
      serverClientId: _webClientId,
    );
  }
}

class GoogleSignInRequestCanceledException implements Exception {
  const GoogleSignInRequestCanceledException();
}

class GoogleSignInMissingIdTokenException implements Exception {
  const GoogleSignInMissingIdTokenException();
}

class GoogleSignInMissingAccessTokenException implements Exception {
  const GoogleSignInMissingAccessTokenException();
}
