import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/camera/presentation/camera_providers.dart';
import '../../features/camera/presentation/camera_screen.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../domain/auth_session_state.dart';
import 'auth_page.dart';
import 'auth_providers.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasSupabaseConfigProvider)) {
      return const _ConfigErrorPage();
    }

    final AsyncValue<AuthSessionState> authState = ref.watch(
      authSessionProvider,
    );
    return authState.when(
      data: (AuthSessionState state) {
        if (state.isSignedIn) {
          return const _SignedInCameraEntry();
        }
        if (state.status == AuthSessionStatus.restoring) {
          return const _AuthLoadingPage();
        }
        return AuthPage(sessionMessage: state.message);
      },
      loading: () => const _AuthLoadingPage(),
      error: (_, _) =>
          AuthPage(sessionMessage: context.l10n.authSessionRestoreFailed),
    );
  }
}

class _SignedInCameraEntry extends ConsumerWidget {
  const _SignedInCameraEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choices = ref.watch(signedInCameraChoicesProvider);
    return choices.when(
      data: (cameraChoices) {
        return ProviderScope(
          overrides: <Override>[
            cameraChoicesProvider.overrideWithValue(cameraChoices),
          ],
          child: const CameraScreen(),
        );
      },
      loading: () => const _AuthLoadingPage(),
      error: (_, _) =>
          AuthPage(sessionMessage: context.l10n.authCameraDevicesLoadFailed),
    );
  }
}

class _AuthLoadingPage extends StatelessWidget {
  const _AuthLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      backgroundColor: AppColors.black,
      child: Center(
        child: SizedBox.square(
          dimension: 24,
          child: CupertinoActivityIndicator(color: AppColors.white),
        ),
      ),
    );
  }
}

class _ConfigErrorPage extends StatelessWidget {
  const _ConfigErrorPage();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              context.l10n.authMissingSupabaseConfig,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
