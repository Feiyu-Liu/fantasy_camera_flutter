import 'dart:io';

import 'package:fantasy_camera_flutter/auth/presentation/auth_page.dart';
import 'package:fantasy_camera_flutter/auth/presentation/auth_providers.dart';
import 'package:fantasy_camera_flutter/config/app_config.dart';
import 'package:fantasy_camera_flutter/l10n/l10n.dart';
import 'package:fantasy_camera_flutter/settings/application/app_settings.dart';
import 'package:fantasy_camera_flutter/theme/app_colors.dart';
import 'package:fantasy_camera_flutter/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('auth callback configuration', () {
    test('uses an iOS registered URL scheme for email confirmation', () {
      final Uri redirectUri = Uri.parse(AppConfig.authEmailRedirectUrl);
      final String infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(redirectUri.scheme, AppConfig.authCallbackScheme);
      expect(redirectUri.host, 'login-callback');
      expect(
        infoPlist,
        contains('<string>${AppConfig.authCallbackScheme}</string>'),
      );
    });
  });

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

    testWidgets('shows account-created notice as success text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const _AuthPageHarness(
          localePreference: AppLocalePreference.zh,
          sessionMessage: '账号已创建，请查看邮箱并完成验证后登录。',
          sessionMessageTone: AuthPageMessageTone.success,
        ),
      );

      final Finder notice = find.text('账号已创建，请查看邮箱并完成验证后登录。');

      expect(notice, findsOneWidget);
      expect(tester.widget<Text>(notice).style?.color, AppColors.success);
    });
  });
}

class _AuthPageHarness extends StatelessWidget {
  const _AuthPageHarness({
    required this.localePreference,
    this.errorCode,
    this.sessionMessage,
    this.sessionMessageTone = AuthPageMessageTone.error,
  });

  final AppLocalePreference localePreference;
  final AuthControllerErrorCode? errorCode;
  final String? sessionMessage;
  final AuthPageMessageTone sessionMessageTone;

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
          home: AuthPage(
            sessionMessage: sessionMessage,
            sessionMessageTone: sessionMessageTone,
          ),
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
