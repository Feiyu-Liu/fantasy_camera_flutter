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

enum AuthPageMessageTone { error, success }

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({
    this.sessionMessage,
    this.sessionMessageTone = AuthPageMessageTone.error,
    super.key,
  });

  final String? sessionMessage;
  final AuthPageMessageTone sessionMessageTone;

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
    final String? controllerMessage = _authControllerMessage(context, state);
    final String? message = controllerMessage ?? widget.sessionMessage;
    final AuthPageMessageTone messageTone = controllerMessage == null
        ? widget.sessionMessageTone
        : AuthPageMessageTone.error;
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
                    messageTone: messageTone,
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
                    onForgotPassword: state.isSubmitting
                        ? null
                        : _showForgotPasswordDialog,
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

  Future<void> _showForgotPasswordDialog() async {
    final String? email = await showCupertinoDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _ForgotPasswordDialog(
          initialEmail: _emailController.text.trim(),
        );
      },
    );
    if (!mounted || email == null) {
      return;
    }

    final bool sent = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(email: email);
    if (!mounted || !sent) {
      return;
    }

    await showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return CupertinoAlertDialog(
          title: Text(context.l10n.authForgotPasswordEmailTitle),
          content: Text(context.l10n.authForgotPasswordEmailSent),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.commonOK),
            ),
          ],
        );
      },
    );
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

String? _authControllerMessage(
  BuildContext context,
  AuthControllerState state,
) {
  return switch (state.errorCode) {
    AuthControllerErrorCode.appleSignInFailed =>
      context.l10n.authAppleSignInFailed,
    AuthControllerErrorCode.googleSignInFailed =>
      context.l10n.authGoogleSignInFailed,
    AuthControllerErrorCode.invalidCredentials =>
      context.l10n.authInvalidCredentials,
    AuthControllerErrorCode.emailNotConfirmed =>
      context.l10n.authEmailNotConfirmed,
    AuthControllerErrorCode.accountAlreadyExists =>
      context.l10n.authAccountAlreadyExists,
    AuthControllerErrorCode.weakPassword => context.l10n.authWeakPassword,
    AuthControllerErrorCode.rateLimited => context.l10n.authRateLimited,
    AuthControllerErrorCode.signupDisabled => context.l10n.authSignupDisabled,
    AuthControllerErrorCode.passwordResetFailed =>
      context.l10n.authPasswordResetFailed,
    AuthControllerErrorCode.authenticationFailed =>
      context.l10n.authAuthenticationFailed,
    null => null,
  };
}

class AuthPasswordResetPage extends ConsumerStatefulWidget {
  const AuthPasswordResetPage({super.key});

  @override
  ConsumerState<AuthPasswordResetPage> createState() =>
      _AuthPasswordResetPageState();
}

class _AuthPasswordResetPageState extends ConsumerState<AuthPasswordResetPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthControllerState state = ref.watch(authControllerProvider);
    final String? message = _authControllerMessage(context, state);
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _AuthEditorialTitle(),
                      const SizedBox(height: 44),
                      Text(
                        context.l10n.authResetPasswordTitle.toUpperCase(),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _EditorialAuthTextField(
                        key: const ValueKey<String>(
                          'auth_reset_password_field',
                        ),
                        controller: _passwordController,
                        enabled: !state.isSubmitting,
                        label: context.l10n.authPasswordLabel.toUpperCase(),
                        placeholder: '',
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[
                          AutofillHints.newPassword,
                        ],
                        errorText: _passwordError,
                        onChanged: (_) => _clearFieldErrors(),
                      ),
                      const SizedBox(height: 24),
                      _EditorialAuthTextField(
                        key: const ValueKey<String>(
                          'auth_reset_password_confirm_field',
                        ),
                        controller: _confirmPasswordController,
                        enabled: !state.isSubmitting,
                        label: context.l10n.authResetPasswordConfirmLabel
                            .toUpperCase(),
                        placeholder: '',
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const <String>[
                          AutofillHints.newPassword,
                        ],
                        onSubmitted: (_) => _submit(state),
                        errorText: _confirmPasswordError,
                        onChanged: (_) => _clearFieldErrors(),
                      ),
                      if (message != null && message.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 18),
                        Text(
                          message,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 34),
                      _EditorialPasswordResetSubmitButton(
                        isSubmitting: state.isSubmitting,
                        onPressed: state.isSubmitting
                            ? null
                            : () => _submit(state),
                      ),
                      const SizedBox(height: 18),
                      _EditorialTextAction(
                        label: context.l10n.authPasswordResetCancelButton,
                        textAlign: TextAlign.center,
                        onPressed: state.isSubmitting
                            ? null
                            : ref.read(authControllerProvider.notifier).signOut,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _clearFieldErrors() {
    if (_passwordError == null && _confirmPasswordError == null) {
      return;
    }
    setState(() {
      _passwordError = null;
      _confirmPasswordError = null;
    });
  }

  Future<void> _submit(AuthControllerState state) async {
    if (state.isSubmitting || !_validate()) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .updatePassword(password: _passwordController.text);
  }

  bool _validate() {
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;
    String? passwordError;
    String? confirmPasswordError;
    if (password.length < 6) {
      passwordError = context.l10n.authPasswordMinLength;
    }
    if (confirmPassword != password) {
      confirmPasswordError = context.l10n.authResetPasswordMismatch;
    }
    setState(() {
      _passwordError = passwordError;
      _confirmPasswordError = confirmPasswordError;
    });
    return passwordError == null && confirmPasswordError == null;
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialEmail,
  );
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(context.l10n.authForgotPasswordEmailTitle),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: <Widget>[
            Text(context.l10n.authForgotPasswordEmailMessage),
            const SizedBox(height: 14),
            CupertinoTextField(
              key: const ValueKey<String>('auth_forgot_password_email_field'),
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.email],
              placeholder: context.l10n.authEmailLabel,
              onSubmitted: (_) => _submit(),
            ),
            if (_errorText != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        CupertinoDialogAction(
          onPressed: _submit,
          child: Text(context.l10n.commonOK),
        ),
      ],
    );
  }

  void _submit() {
    final String email = _controller.text.trim();
    String? errorText;
    if (email.isEmpty) {
      errorText = context.l10n.authEmailRequired;
    } else if (!email.contains('@')) {
      errorText = context.l10n.authEmailInvalid;
    }
    if (errorText != null) {
      setState(() {
        _errorText = errorText;
      });
      return;
    }
    Navigator.of(context).pop(email);
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
    required this.onForgotPassword,
    required this.onToggleMode,
    required this.onAppleSignIn,
    required this.onGoogleSignIn,
    this.message,
    this.messageTone = AuthPageMessageTone.error,
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
  final AuthPageMessageTone messageTone;
  final String? emailError;
  final String? passwordError;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPasswordChanged;
  final ValueChanged<String> onPasswordSubmitted;
  final VoidCallback onSubmit;
  final VoidCallback? onForgotPassword;
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
          placeholder: '',
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
          placeholder: '',
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
              color: messageTone == AuthPageMessageTone.success
                  ? AppColors.success
                  : AppColors.danger,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 34),
        _EditorialAuthActionRow(
          forgotLabel: l10n.authForgotKeyButton,
          toggleLabel: isSignUp
              ? l10n.authAlreadyHaveAccountSignIn
              : l10n.authCreateAccountButton,
          onForgotPressed: onForgotPassword,
          onToggleMode: onToggleMode,
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
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              'TesserCam',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontFamily: 'Snell Roundhand',
                fontSize: 40,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                height: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 3, bottom: 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.accentYellow,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 7, height: 7),
              ),
            ),
          ],
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
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              (isSignUp
                                      ? l10n.authCreateAccountButton
                                      : l10n.authSignInButton)
                                  .toUpperCase(),
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: colors.inverseText,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                                height: 1,
                              ),
                            ),
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
      ),
    );
  }
}

class _EditorialPasswordResetSubmitButton extends StatelessWidget {
  const _EditorialPasswordResetSubmitButton({
    required this.isSubmitting,
    required this.onPressed,
  });

  final bool isSubmitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return CupertinoButton(
      key: const ValueKey<String>('auth_reset_password_submit'),
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
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      context.l10n.authResetPasswordSubmitButton.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.inverseText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        height: 1,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _EditorialAuthActionRow extends StatelessWidget {
  const _EditorialAuthActionRow({
    required this.forgotLabel,
    required this.toggleLabel,
    required this.onForgotPressed,
    required this.onToggleMode,
  });

  final String forgotLabel;
  final String toggleLabel;
  final VoidCallback? onForgotPressed;
  final VoidCallback? onToggleMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _EditorialTextAction(
            label: forgotLabel,
            textAlign: TextAlign.left,
            onPressed: onForgotPressed,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _EditorialTextAction(
            label: toggleLabel,
            textAlign: TextAlign.right,
            onPressed: onToggleMode,
          ),
        ),
      ],
    );
  }
}

class _EditorialTextAction extends StatelessWidget {
  const _EditorialTextAction({
    required this.label,
    required this.textAlign,
    required this.onPressed,
  });

  final String label;
  final TextAlign textAlign;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return CupertinoButton(
      onPressed: onPressed,
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      child: Align(
        alignment: textAlign == TextAlign.right
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: TextStyle(
            color: onPressed == null ? colors.textMuted : colors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            height: 1.2,
          ),
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
