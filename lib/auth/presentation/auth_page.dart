import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    final AuthControllerState state = ref.watch(authControllerProvider);
    final String? message = state.errorMessage ?? widget.sessionMessage;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.authEditorialBackground,
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
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onPasswordSubmitted,
    required this.onSubmit,
    required this.onToggleMode,
    required this.onAppleSignIn,
    this.message,
    this.emailError,
    this.passwordError,
  });

  final bool isSignUp;
  final AuthControllerState state;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool supportsAppleSignIn;
  final String? message;
  final String? emailError;
  final String? passwordError;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;
  final ValueChanged<String> onPasswordSubmitted;
  final VoidCallback onSubmit;
  final VoidCallback? onToggleMode;
  final VoidCallback? onAppleSignIn;

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
            style: const TextStyle(
              color: AppColors.authEditorialError,
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
          onAppleSignIn: onAppleSignIn,
        ),
      ],
    );
  }
}

class _AuthEditorialTitle extends StatelessWidget {
  const _AuthEditorialTitle();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: AppColors.black,
          fontFamily: 'Times New Roman',
          fontSize: 46,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 0.94,
        ),
        children: <InlineSpan>[
          TextSpan(
            text:
                '${l10n.authEditorialTitleLine1}\n${l10n.authEditorialTitleLine2}',
          ),
          const TextSpan(
            text: '.',
            style: TextStyle(color: AppColors.accentYellow),
          ),
        ],
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
    return CupertinoButton(
      key: const ValueKey<String>('auth_password_submit'),
      onPressed: onPressed,
      color: AppColors.black,
      disabledColor: AppColors.disabledDark,
      minimumSize: Size.zero,
      borderRadius: BorderRadius.zero,
      padding: EdgeInsets.zero,
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
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      LucideIcons.arrowRight,
                      color: AppColors.accentYellow,
                      size: 18,
                    ),
                  ],
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
    return CupertinoButton(
      onPressed: onPressed,
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      child: Text(
        label,
        style: TextStyle(
          color: onPressed == null ? AppColors.disabledText : AppColors.black,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.8,
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
    return Row(
      children: <Widget>[
        const Expanded(child: _EditorialDividerLine()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            context.l10n.authOrDividerLabel,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              height: 1,
            ),
          ),
        ),
        const Expanded(child: _EditorialDividerLine()),
      ],
    );
  }
}

class _EditorialDividerLine extends StatelessWidget {
  const _EditorialDividerLine();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 0.5,
      child: ColoredBox(color: AppColors.black),
    );
  }
}

class _AuthProviderRow extends StatelessWidget {
  const _AuthProviderRow({
    required this.state,
    required this.supportsAppleSignIn,
    required this.onAppleSignIn,
  });

  final AuthControllerState state;
  final bool supportsAppleSignIn;
  final VoidCallback? onAppleSignIn;

  @override
  Widget build(BuildContext context) {
    final bool enabled = !state.isSubmitting;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _SquareAuthIconButton(
          icon: LucideIcons.apple,
          semanticLabel: context.l10n.authContinueWithApple,
          onPressed: supportsAppleSignIn && enabled ? onAppleSignIn : null,
        ),
        const SizedBox(width: 34),
        _SquareAuthIconButton(
          icon: LucideIcons.badgeCheck,
          semanticLabel: context.l10n.authEditorialAccessBadge,
          onPressed: null,
        ),
        const SizedBox(width: 34),
        _SquareAuthIconButton(
          icon: LucideIcons.camera,
          semanticLabel: context.l10n.appName,
          onPressed: null,
        ),
      ],
    );
  }
}

class _SquareAuthIconButton extends StatelessWidget {
  const _SquareAuthIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: enabled,
      child: CupertinoButton(
        onPressed: onPressed,
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: enabled
                  ? AppColors.black
                  : AppColors.authEditorialDisabled,
              width: 0.8,
            ),
          ),
          child: SizedBox.square(
            dimension: 48,
            child: Icon(
              icon,
              color: enabled
                  ? AppColors.black
                  : AppColors.authEditorialDisabled,
              size: 22,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: AppColors.black,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
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
          placeholderStyle: const TextStyle(
            color: AppColors.authEditorialPlaceholder,
            fontFamily: 'Times New Roman',
            fontSize: 18,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          style: const TextStyle(
            color: AppColors.black,
            fontFamily: 'Times New Roman',
            fontSize: 18,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: AppColors.black,
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 13),
          decoration: const BoxDecoration(
            color: AppColors.authEditorialBackground,
            border: Border(
              bottom: BorderSide(color: AppColors.black, width: 0.8),
            ),
          ),
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              color: AppColors.authEditorialError,
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
