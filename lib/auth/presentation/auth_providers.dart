import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../features/camera/domain/camera_choice.dart';
import '../../features/camera/presentation/camera_providers.dart';
import '../../shared/core/app_logger.dart';
import '../data/apple_sign_in_gateway.dart';
import '../data/auth_gateway.dart';
import '../data/google_sign_in_gateway.dart';
import '../data/supabase_auth_gateway.dart';
import '../domain/access_token_provider.dart';
import '../domain/auth_session_state.dart';
import '../session/supabase_session_coordinator.dart';

final hasSupabaseConfigProvider = Provider<bool>((Ref ref) {
  return AppConfig.hasSupabaseConfig;
});

final supabaseClientProvider = Provider<SupabaseClient>((Ref ref) {
  return Supabase.instance.client;
});

final appleSignInGatewayProvider = Provider<AppleSignInGateway>((Ref ref) {
  return const NativeAppleSignInGateway();
});

final googleSignInGatewayProvider = Provider<GoogleSignInGateway>((Ref ref) {
  return NativeGoogleSignInGateway(
    iosClientId: AppConfig.googleIosClientId,
    webClientId: AppConfig.googleWebClientId,
  );
});

final authGatewayProvider = Provider<AuthGateway>((Ref ref) {
  return SupabaseAuthGateway(
    client: ref.watch(supabaseClientProvider),
    appleSignInGateway: ref.watch(appleSignInGatewayProvider),
    googleSignInGateway: ref.watch(googleSignInGatewayProvider),
  );
});

final sessionCoordinatorProvider = Provider<SupabaseSessionCoordinator>((
  Ref ref,
) {
  final SupabaseSessionCoordinator coordinator = SupabaseSessionCoordinator(
    authGateway: ref.watch(authGatewayProvider),
  );
  unawaited(coordinator.restore());
  ref.onDispose(() {
    unawaited(coordinator.dispose());
  });
  return coordinator;
});

final accessTokenProvider = Provider<AccessTokenProvider>((Ref ref) {
  return ref.watch(sessionCoordinatorProvider);
}, dependencies: <ProviderOrFamily>[sessionCoordinatorProvider]);

final authSessionProvider = StreamProvider<AuthSessionState>((Ref ref) {
  return ref.watch(sessionCoordinatorProvider).states;
}, dependencies: <ProviderOrFamily>[sessionCoordinatorProvider]);

final authControllerProvider =
    NotifierProvider<AuthController, AuthControllerState>(
      AuthController.new,
      dependencies: <ProviderOrFamily>[sessionCoordinatorProvider],
    );

enum AuthControllerErrorCode {
  appleSignInFailed,
  googleSignInFailed,
  invalidCredentials,
  authenticationFailed,
}

class AuthControllerState {
  const AuthControllerState({
    this.isSubmitting = false,
    this.errorCode,
    this.rawErrorMessage,
  });

  final bool isSubmitting;
  final AuthControllerErrorCode? errorCode;
  final String? rawErrorMessage;

  AuthControllerState copyWith({
    bool? isSubmitting,
    AuthControllerErrorCode? errorCode,
    String? rawErrorMessage,
    bool clearError = false,
  }) {
    return AuthControllerState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
      rawErrorMessage: clearError
          ? null
          : rawErrorMessage ?? this.rawErrorMessage,
    );
  }
}

class AuthController extends Notifier<AuthControllerState> {
  @override
  AuthControllerState build() {
    return const AuthControllerState();
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (state.isSubmitting) {
      return;
    }
    await _submit(() {
      return ref.read(sessionCoordinatorProvider).markSigningIn(() {
        return ref
            .read(authGatewayProvider)
            .signInWithPassword(email: email, password: password);
      });
    });
  }

  Future<void> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    if (state.isSubmitting) {
      return;
    }
    await _submit(() {
      return ref.read(sessionCoordinatorProvider).markSigningUp(() {
        return ref
            .read(authGatewayProvider)
            .signUpWithPassword(email: email, password: password);
      });
    });
  }

  Future<void> signInWithApple() async {
    if (state.isSubmitting) {
      return;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await ref.read(sessionCoordinatorProvider).markSigningIn(() {
        return ref.read(authGatewayProvider).signInWithApple();
      });
    } on AppleSignInCanceledException {
      state = state.copyWith(isSubmitting: false, clearError: true);
      return;
    } on Object catch (error, stackTrace) {
      logAppError('apple_sign_in_failed', error, stackTrace);
      state = state.copyWith(
        isSubmitting: false,
        errorCode: AuthControllerErrorCode.appleSignInFailed,
      );
      return;
    }
    state = state.copyWith(isSubmitting: false, clearError: true);
  }

  Future<void> signInWithGoogle() async {
    if (state.isSubmitting) {
      return;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await ref.read(sessionCoordinatorProvider).markSigningIn(() {
        return ref.read(authGatewayProvider).signInWithGoogle();
      });
    } on GoogleSignInCanceledException {
      state = state.copyWith(isSubmitting: false, clearError: true);
      return;
    } on Object catch (error, stackTrace) {
      logAppError('google_sign_in_failed', error, stackTrace);
      state = state.copyWith(
        isSubmitting: false,
        errorCode: AuthControllerErrorCode.googleSignInFailed,
      );
      return;
    }
    state = state.copyWith(isSubmitting: false, clearError: true);
  }

  Future<void> signOut() async {
    await _submit(() => ref.read(sessionCoordinatorProvider).signOut());
  }

  Future<void> _submit(Future<void> Function() action) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await action();
      state = state.copyWith(isSubmitting: false, clearError: true);
    } on Object catch (error, stackTrace) {
      logAppError('auth_action_failed', error, stackTrace);
      state = state.copyWith(
        isSubmitting: false,
        errorCode: _errorCodeFor(error),
        rawErrorMessage: _rawMessageFor(error),
      );
    }
  }

  AuthControllerErrorCode _errorCodeFor(Object error) {
    if (error is AuthException) {
      if (error.code == 'invalid_credentials') {
        return AuthControllerErrorCode.invalidCredentials;
      }
      return AuthControllerErrorCode.authenticationFailed;
    }
    return AuthControllerErrorCode.authenticationFailed;
  }

  String? _rawMessageFor(Object error) {
    if (error is AuthException && error.code != 'invalid_credentials') {
      return error.message;
    }
    return null;
  }
}

final signedInCameraChoicesProvider = FutureProvider<List<CameraChoice>>((
  Ref ref,
) async {
  return ref.watch(cameraDeviceRepositoryProvider).loadCameraChoices();
});
