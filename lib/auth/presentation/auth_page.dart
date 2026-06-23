import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../config/app_config.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_corners.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'auth_providers.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({this.sessionMessage, super.key});

  final String? sessionMessage;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSignUp = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthControllerState state = ref.watch(authControllerProvider);
    final String? message = state.errorMessage ?? widget.sessionMessage;
    final AppThemeColors colors = AppThemeColors.of(context);
    return CupertinoPageScaffold(
      backgroundColor: colors.background,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final MediaQueryData mediaQuery = MediaQuery.of(context);
          final EdgeInsets pagePadding = EdgeInsets.fromLTRB(
            18,
            mediaQuery.viewPadding.top + 24,
            18,
            mediaQuery.viewPadding.bottom + 24,
          );
          final double minContentHeight =
              constraints.maxHeight - pagePadding.vertical;
          return SingleChildScrollView(
            padding: pagePadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: minContentHeight.isFinite
                    ? minContentHeight.clamp(0, double.infinity)
                    : 0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: _EditorialAuthForm(
                    isSignUp: _isSignUp,
                    state: state,
                    message: message,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    emailError: _emailError,
                    passwordError: _passwordError,
                    supportsAppleSignIn: _supportsAppleSignIn,
                    supportsGoogleSignIn: AppConfig.hasGoogleSignInConfig,
                    onEmailChanged: (_) => _clearFieldErrors(),
                    onPasswordChanged: (_) => _clearFieldErrors(),
                    onPasswordSubmitted: (_) => _submitPassword(state),
                    onSubmit: () => _submitPassword(state),
                    onToggleMode: state.isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _isSignUp = !_isSignUp;
                              _emailError = null;
                              _passwordError = null;
                            });
                          },
                    onAppleSignIn: state.isSubmitting || !_supportsAppleSignIn
                        ? null
                        : ref
                              .read(authControllerProvider.notifier)
                              .signInWithApple,
                    onGoogleSignIn:
                        state.isSubmitting || !AppConfig.hasGoogleSignInConfig
                        ? null
                        : ref
                              .read(authControllerProvider.notifier)
                              .signInWithGoogle,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool get _supportsAppleSignIn {
    if (kIsWeb) {
      return false;
    }
    return Platform.isIOS || Platform.isMacOS;
  }

  void _clearFieldErrors() {
    if (_emailError == null && _passwordError == null) {
      return;
    }
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
  }

  Future<void> _submitPassword(AuthControllerState state) async {
    if (state.isSubmitting || !_validatePasswordForm()) {
      return;
    }
    final AuthController controller = ref.read(authControllerProvider.notifier);
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    if (_isSignUp) {
      await controller.signUpWithPassword(email: email, password: password);
    } else {
      await controller.signInWithPassword(email: email, password: password);
    }
  }

  bool _validatePasswordForm() {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    String? emailError;
    String? passwordError;

    if (email.isEmpty) {
      emailError = context.l10n.authEmailRequired;
    } else if (!email.contains('@')) {
      emailError = context.l10n.authEmailInvalid;
    }

    if (password.length < 6) {
      passwordError = context.l10n.authPasswordMinLength;
    }

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    return emailError == null && passwordError == null;
  }
}

class _EditorialAuthForm extends StatelessWidget {
  const _EditorialAuthForm({
    required this.isSignUp,
    required this.state,
    required this.emailController,
    required this.passwordController,
    required this.supportsAppleSignIn,
    required this.supportsGoogleSignIn,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onPasswordSubmitted,
    required this.onSubmit,
    required this.onToggleMode,
    required this.onAppleSignIn,
    required this.onGoogleSignIn,
    this.message,
    this.emailError,
    this.passwordError,
  });

  final bool isSignUp;
  final AuthControllerState state;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool supportsAppleSignIn;
  final bool supportsGoogleSignIn;
  final String? message;
  final String? emailError;
  final String? passwordError;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;
  final ValueChanged<String> onPasswordSubmitted;
  final VoidCallback onSubmit;
  final VoidCallback? onToggleMode;
  final VoidCallback? onAppleSignIn;
  final VoidCallback? onGoogleSignIn;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _AuthEditorialTitle(),
        const SizedBox(height: 44),
        _EditorialAuthTextField(
          key: const ValueKey<String>('auth_email_field'),
          controller: emailController,
          enabled: !state.isSubmitting,
          label: l10n.authEmailLabel.toUpperCase(),
          placeholder: l10n.authEmailPlaceholder,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.email],
          errorText: emailError,
          onChanged: onEmailChanged,
        ),
        const SizedBox(height: 24),
        _EditorialAuthTextField(
          key: const ValueKey<String>('auth_password_field'),
          controller: passwordController,
          enabled: !state.isSubmitting,
          label: l10n.authPasswordLabel.toUpperCase(),
          placeholder: l10n.authSecretKeyPlaceholder,
          obscureText: true,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.password],
          onSubmitted: onPasswordSubmitted,
          errorText: passwordError,
          onChanged: onPasswordChanged,
        ),
        if (message != null && message!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          Text(
            message!,
            style: TextStyle(
              color: AppColors.danger,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 34),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _EditorialTextAction(
              label: l10n.authForgotKeyButton.toUpperCase(),
              onPressed: state.isSubmitting ? null : () {},
            ),
            _EditorialTextAction(
              label:
                  (isSignUp
                          ? l10n.authAlreadyHaveAccountSignIn
                          : l10n.authCreateAccountButton)
                      .toUpperCase(),
              onPressed: onToggleMode,
            ),
          ],
        ),
        const SizedBox(height: 22),
        _EditorialSubmitButton(
          isSignUp: isSignUp,
          isSubmitting: state.isSubmitting,
          onPressed: state.isSubmitting ? null : onSubmit,
        ),
        const SizedBox(height: 24),
        const _EditorialOrDivider(),
        const SizedBox(height: 24),
        _AuthProviderRow(
          state: state,
          supportsAppleSignIn: supportsAppleSignIn,
          supportsGoogleSignIn: supportsGoogleSignIn,
          onAppleSignIn: onAppleSignIn,
          onGoogleSignIn: onGoogleSignIn,
        ),
      ],
    );
  }
}

class _AuthEditorialTitle extends StatelessWidget {
  const _AuthEditorialTitle();

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return Center(
      child: Text(
        'TesserCam',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.textPrimary,
          fontFamily: 'Avenir Next',
          fontSize: 40,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1,
        ),
      ),
    );
  }
}

class _EditorialSubmitButton extends StatelessWidget {
  const _EditorialSubmitButton({
    required this.isSignUp,
    required this.isSubmitting,
    required this.onPressed,
  });

  final bool isSignUp;
  final bool isSubmitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Color accentYellow = AppThemeColors.of(context).accentYellow;
    final AppThemeColors colors = AppThemeColors.of(context);
    return CupertinoButton(
      key: const ValueKey<String>('auth_password_submit'),
      onPressed: onPressed,
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: AppCorners.controlDecoration(
          color: onPressed == null
              ? colors.controlFillDisabled
              : colors.textPrimary,
        ),
        child: SizedBox(
          height: 52,
          child: Center(
            child: isSubmitting
                ? const CupertinoActivityIndicator(color: AppColors.white)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        (isSignUp
                                ? l10n.authCreateAccountButton
                                : l10n.authSignInButton)
                            .toUpperCase(),
                        style: TextStyle(
                          color: colors.inverseText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        LucideIcons.arrowRight,
                        color: accentYellow,
                        size: 18,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _EditorialTextAction extends StatelessWidget {
  const _EditorialTextAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return CupertinoButton(
      onPressed: onPressed,
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      child: Text(
        label,
        style: TextStyle(
          color: onPressed == null ? colors.textMuted : colors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          height: 1,
        ),
      ),
    );
  }
}

class _EditorialOrDivider extends StatelessWidget {
  const _EditorialOrDivider();

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return Row(
      children: <Widget>[
        Expanded(child: _EditorialDividerLine(color: colors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            context.l10n.authOrDividerLabel,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              height: 1,
            ),
          ),
        ),
        Expanded(child: _EditorialDividerLine(color: colors.border)),
      ],
    );
  }
}

class _EditorialDividerLine extends StatelessWidget {
  const _EditorialDividerLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 0.5, child: ColoredBox(color: color));
  }
}

class _AuthProviderRow extends StatelessWidget {
  const _AuthProviderRow({
    required this.state,
    required this.supportsAppleSignIn,
    required this.supportsGoogleSignIn,
    required this.onAppleSignIn,
    required this.onGoogleSignIn,
  });

  final AuthControllerState state;
  final bool supportsAppleSignIn;
  final bool supportsGoogleSignIn;
  final VoidCallback? onAppleSignIn;
  final VoidCallback? onGoogleSignIn;

  @override
  Widget build(BuildContext context) {
    final bool enabled = !state.isSubmitting;
    return Row(
      children: <Widget>[
        Expanded(
          child: _AppleAuthButton(
            key: const ValueKey<String>('auth_apple_button'),
            label: context.l10n.authContinueWithApple,
            onPressed: supportsAppleSignIn && enabled ? onAppleSignIn : null,
          ),
        ),
        if (supportsGoogleSignIn) ...<Widget>[
          const SizedBox(width: 12),
          Expanded(
            child: _GoogleAuthButton(
              key: const ValueKey<String>('auth_google_button'),
              label: context.l10n.authContinueWithGoogle,
              onPressed: enabled ? onGoogleSignIn : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _AppleAuthButton extends StatelessWidget {
  const _AppleAuthButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Color background = enabled
        ? AppColors.black
        : AppColors.black.withValues(alpha: 0.34);
    final Color foreground = enabled
        ? AppColors.white
        : AppColors.white.withValues(alpha: 0.62);
    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: CupertinoButton(
        onPressed: onPressed,
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        child: DecoratedBox(
          decoration: AppCorners.controlDecoration(color: background),
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: SizedBox(
                    width: 17.8,
                    height: 22,
                    child: CustomPaint(
                      painter: AppleLogoPainter(color: foreground),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleAuthButton extends StatelessWidget {
  const _GoogleAuthButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  static const String _logoAsset = 'assets/auth/ios_neutral_sq_na.png';

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Color foreground = enabled
        ? AppColors.black
        : AppColors.black.withValues(alpha: 0.42);
    final Color border = enabled
        ? AppColors.black
        : AppColors.black.withValues(alpha: 0.18);
    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: CupertinoButton(
        onPressed: onPressed,
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        child: DecoratedBox(
          decoration: AppCorners.controlDecoration(
            color: AppColors.white,
            side: BorderSide(color: border, width: 0.8),
          ),
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Opacity(
                  opacity: enabled ? 1 : 0.42,
                  child: Image.asset(
                    _logoAsset,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorialAuthTextField extends StatelessWidget {
  const _EditorialAuthTextField({
    required this.controller,
    required this.label,
    required this.placeholder,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String placeholder;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null;
    final AppThemeColors colors = AppThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            height: 1,
          ),
        ),
        const SizedBox(height: 14),
        CupertinoTextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          placeholder: placeholder,
          placeholderStyle: TextStyle(
            color: colors.textMuted,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            height: 1.25,
          ),
          cursorColor: colors.textPrimary,
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 13),
          decoration: BoxDecoration(
            color: colors.background,
            border: Border(
              bottom: BorderSide(color: colors.border, width: 0.8),
            ),
          ),
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: TextStyle(
              color: AppColors.danger,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}
