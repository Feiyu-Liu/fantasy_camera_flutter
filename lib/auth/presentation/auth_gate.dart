import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/camera/presentation/camera_providers.dart';
import '../../features/camera/presentation/camera_screen.dart';
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
      error: (_, _) => const AuthPage(
        sessionMessage: 'Session could not be restored. Please sign in.',
      ),
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
          const AuthPage(sessionMessage: 'Camera devices could not be loaded.'),
    );
  }
}

class _AuthLoadingPage extends StatelessWidget {
  const _AuthLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Center(
        child: SizedBox.square(
          dimension: 24,
          child: CupertinoActivityIndicator(color: CupertinoColors.white),
        ),
      ),
    );
  }
}

class _ConfigErrorPage extends StatelessWidget {
  const _ConfigErrorPage();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Missing Supabase configuration. Start with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY dart-defines.',
              textAlign: TextAlign.center,
              style: TextStyle(color: CupertinoColors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
