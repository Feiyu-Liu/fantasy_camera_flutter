import 'package:fantasy_camera_flutter/auth/presentation/auth_page.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_providers.dart';
import 'package:fantasy_camera_flutter/l10n/l10n.dart';
import 'package:fantasy_camera_flutter/settings/application/app_settings.dart';
import 'package:fantasy_camera_flutter/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('authControllerErrorCodeFor', () {
    test('maps known Supabase auth error codes', () {
      expect(
        authControllerErrorCodeFor(
          const AuthException(
            'Invalid login credentials',
            code: 'invalid_credentials',
          ),
        ),
        AuthControllerErrorCode.invalidCredentials,
      );
      expect(
        authControllerErrorCodeFor(
          const AuthException(
            'Email not confirmed',
            code: 'email_not_confirmed',
          ),
        ),
        AuthControllerErrorCode.emailNotConfirmed,
      );
      expect(
        authControllerErrorCodeFor(
          const AuthException(
            'User already registered',
            code: 'user_already_exists',
          ),
        ),
        AuthControllerErrorCode.accountAlreadyExists,
      );
      expect(
        authControllerErrorCodeFor(
          const AuthException('Password is weak', code: 'weak_password'),
        ),
        AuthControllerErrorCode.weakPassword,
      );
      expect(
        authControllerErrorCodeFor(
          const AuthException(
            'Too many requests',
            code: 'over_request_rate_limit',
          ),
        ),
        AuthControllerErrorCode.rateLimited,
      );
      expect(
        authControllerErrorCodeFor(
          const AuthException('Signups disabled', code: 'signup_disabled'),
        ),
        AuthControllerErrorCode.signupDisabled,
      );
    });

    test('maps unknown errors to generic authentication failure', () {
      expect(
        authControllerErrorCodeFor(
          const AuthException('Backend raw message', code: 'unexpected_error'),
        ),
        AuthControllerErrorCode.authenticationFailed,
      );
      expect(
        authControllerErrorCodeFor(Exception('network')),
        AuthControllerErrorCode.authenticationFailed,
      );
    });
  });

  group('AuthPage error messages', () {
    testWidgets('localizes auth errors instead of showing backend raw text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _AuthPageHarness(
          localePreference: AppLocalePreference.zh,
          errorCode: AuthControllerErrorCode.emailNotConfirmed,
        ),
      );

      expect(find.text('邮箱尚未确认，请先查看邮箱并完成确认。'), findsOneWidget);
      expect(find.text('Email not confirmed'), findsNothing);
    });

    testWidgets('uses selected locale for mapped auth errors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _AuthPageHarness(
          localePreference: AppLocalePreference.en,
          errorCode: AuthControllerErrorCode.accountAlreadyExists,
        ),
      );

      expect(
        find.text('This email is already registered. Sign in instead.'),
        findsOneWidget,
      );
    });
  });
}

class _AuthPageHarness extends StatelessWidget {
  const _AuthPageHarness({
    required this.localePreference,
    required this.errorCode,
  });

  final AppLocalePreference localePreference;
  final AuthControllerErrorCode errorCode;

  @override
  Widget build(BuildContext context) {
    final Locale? locale = localeForPreference(localePreference);
    final AppThemePreference themePreference = AppThemePreference.light;
    return ProviderScope(
      overrides: <Override>[
        authControllerProvider.overrideWith(
          () => _FixedAuthController(AuthControllerState(errorCode: errorCode)),
        ),
      ],
      child: AppThemeColorsScope(
        colors: appThemeColorsForPreference(themePreference),
        child: CupertinoApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: appCupertinoThemeForPreference(themePreference),
          home: const AuthPage(),
        ),
      ),
    );
  }
}

class _FixedAuthController extends AuthController {
  _FixedAuthController(this.initialState);

  final AuthControllerState initialState;

  @override
  AuthControllerState build() {
    return initialState;
  }
}
