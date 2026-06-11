import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
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
    final AppLocalizations l10n = context.l10n;
    final AuthControllerState state = ref.watch(authControllerProvider);
    final String? message = state.errorMessage ?? widget.sessionMessage;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.black,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.appName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp
                        ? l10n.authCreateAccountSubtitle
                        : l10n.authSignInSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _CupertinoAuthTextField(
                    key: const ValueKey<String>('auth_email_field'),
                    controller: _emailController,
                    enabled: !state.isSubmitting,
                    placeholder: l10n.authEmailPlaceholder,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.email],
                    errorText: _emailError,
                    onChanged: (_) => _clearFieldErrors(),
                  ),
                  const SizedBox(height: 14),
                  _CupertinoAuthTextField(
                    key: const ValueKey<String>('auth_password_field'),
                    controller: _passwordController,
                    enabled: !state.isSubmitting,
                    placeholder: l10n.authPasswordPlaceholder,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.password],
                    onSubmitted: (_) => _submitPassword(state),
                    errorText: _passwordError,
                    onChanged: (_) => _clearFieldErrors(),
                  ),
                  if (message != null && message.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.authError,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  CupertinoButton(
                    key: const ValueKey<String>('auth_password_submit'),
                    onPressed: state.isSubmitting
                        ? null
                        : () => _submitPassword(state),
                    color: AppColors.white,
                    disabledColor: AppColors.disabledDark,
                    minimumSize: const Size.fromHeight(52),
                    borderRadius: BorderRadius.circular(8),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: state.isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CupertinoActivityIndicator(
                              color: AppColors.black,
                            ),
                          )
                        : Text(
                            _isSignUp
                                ? l10n.authCreateAccountButton
                                : l10n.authSignInButton,
                            style: const TextStyle(
                              color: AppColors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  CupertinoButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _isSignUp = !_isSignUp;
                              _emailError = null;
                              _passwordError = null;
                            });
                          },
                    child: Text(
                      _isSignUp
                          ? l10n.authAlreadyHaveAccountSignIn
                          : l10n.authNewHereCreateAccount,
                      style: TextStyle(
                        color: state.isSubmitting
                            ? AppColors.disabledText
                            : AppColors.link,
                      ),
                    ),
                  ),
                  if (_supportsAppleSignIn) ...<Widget>[
                    const SizedBox(height: 12),
                    CupertinoButton(
                      key: const ValueKey<String>('auth_apple_submit'),
                      onPressed: state.isSubmitting
                          ? null
                          : ref
                                .read(authControllerProvider.notifier)
                                .signInWithApple,
                      minimumSize: const Size.fromHeight(52),
                      borderRadius: BorderRadius.circular(8),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      color: AppColors.darkSurface,
                      disabledColor: AppColors.disabledSurfaceDark,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.disabledDark),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SizedBox(
                          height: 52,
                          child: Center(
                            child: Text(
                              l10n.authContinueWithApple,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
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

class _CupertinoAuthTextField extends StatelessWidget {
  const _CupertinoAuthTextField({
    required this.controller,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
          placeholderStyle: const TextStyle(color: AppColors.textSecondary),
          style: const TextStyle(color: AppColors.white),
          cursorColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.authInputBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasError ? AppColors.authError : AppColors.authInputBorder,
            ),
          ),
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(color: AppColors.authError, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
