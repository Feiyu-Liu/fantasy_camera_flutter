import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleSignInCredentialPayload {
  const AppleSignInCredentialPayload({
    required this.identityToken,
    required this.rawNonce,
    this.givenName,
    this.familyName,
  });

  final String identityToken;
  final String rawNonce;
  final String? givenName;
  final String? familyName;
}

abstract interface class AppleSignInGateway {
  Future<AppleSignInCredentialPayload> requestCredential();
}

class NativeAppleSignInGateway implements AppleSignInGateway {
  const NativeAppleSignInGateway();

  @override
  Future<AppleSignInCredentialPayload> requestCredential() async {
    final String rawNonce = _generateRawNonce();
    final String hashedNonce = _sha256ofString(rawNonce);
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const AppleSignInRequestCanceledException();
      }
      rethrow;
    }

    final String? identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw const AppleSignInMissingIdentityTokenException();
    }

    return AppleSignInCredentialPayload(
      identityToken: identityToken,
      rawNonce: rawNonce,
      givenName: credential.givenName,
      familyName: credential.familyName,
    );
  }
}

class AppleSignInRequestCanceledException implements Exception {
  const AppleSignInRequestCanceledException();
}

class AppleSignInMissingIdentityTokenException implements Exception {
  const AppleSignInMissingIdentityTokenException();
}

String _generateRawNonce([int length = 32]) {
  const String charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final Random random = Random.secure();
  return List<String>.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}

String _sha256ofString(String input) {
  final List<int> bytes = utf8.encode(input);
  final Digest digest = sha256.convert(bytes);
  return digest.toString();
}
