/// ASignIn · ASignInError · AGoogleLoading · AGoogleError — Sign in.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_settings_controller.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/repositories/auth_repository.dart';
import 'controllers/auth_controller.dart';
import 'widgets/auth_v2_parts.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    required this.repository,
    required this.session,
    this.onSignedIn,
    this.onSignInMethod,
    super.key,
  });

  final AuthRepository repository;
  final AppSessionController session;
  final VoidCallback? onSignedIn;

  /// Remembers how this device signed in (Profile shows it).
  final ValueChanged<SignInMethod>? onSignInMethod;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final AuthController _controller;
  String? _emailError;
  String? _passwordError;
  bool _showGoogleError = false;

  @override
  void initState() {
    super.initState();
    _controller = AuthController(
      repository: widget.repository,
      session: widget.session,
    );
    final String? pending = widget.session.pendingVerificationEmail;
    if (pending != null) _emailController.text = pending;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    FocusScope.of(context).unfocus();
    setState(() {
      _emailError = validateEmail(l10n, _emailController.text);
      _passwordError = _passwordController.text.isEmpty
          ? l10n.v2PasswordRequired
          : null;
    });
    if (_emailError != null || _passwordError != null) return;
    final bool signedIn = await _controller.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (signedIn) {
      final repository = widget.repository;
      if (repository is SocialLinkFeedback &&
          (repository as SocialLinkFeedback).consumeSocialLinkFailure() &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in, but Google linking did not finish.'),
          ),
        );
      }
      widget.onSignInMethod?.call(SignInMethod.password);
      widget.onSignedIn?.call();
    } else if (mounted) {
      openAccountStatusIfBlocked(context, _controller);
    }
  }

  Future<void> _google() => _social(SocialAuthProvider.google);

  Future<void> _social(SocialAuthProvider provider) async {
    setState(() => _showGoogleError = false);
    final bool signedIn = await _controller.signInSocial(provider);
    if (!mounted) return;
    if (signedIn) {
      widget.onSignInMethod?.call(SignInMethod.google);
      widget.onSignedIn?.call();
      return;
    }
    if (openAccountStatusIfBlocked(context, _controller)) return;
    final AuthFailureCode? failure = _controller.failure;
    if (failure != null && isGoogleScreenFailure(failure)) {
      setState(() => _showGoogleError = true);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SsV2Page(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          if (_controller.socialInProgress) {
            return GoogleSignInLoadingBody(onCancel: _controller.cancelSocial);
          }
          if (_showGoogleError) {
            return GoogleSignInErrorBody(
              onRetry: _google,
              onUseEmail: () {
                _controller.clearFailure();
                setState(() => _showGoogleError = false);
              },
            );
          }
          return _buildForm(context);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final AuthFailureCode? failure = _controller.failure;
    final bool invalidCredentials =
        failure == AuthFailureCode.invalidCredentials;
    final bool busy = _controller.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SsV2Header(onBack: _back),
        Expanded(
          child: AutofillGroup(
            child: SsV2FillScroll(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              gap: 18,
              children: <Widget>[
                SsV2TitleBlock(
                  title: l10n.v2SignInTitle,
                  subtitle: Text(l10n.v2SignInSubtitle),
                ),
                if (failure != null)
                  AuthErrorBanner(
                    failure: failure,
                    actions: <Widget>[
                      if (failure == AuthFailureCode.emailNotVerified)
                        SsV2Button(
                          label: l10n.v2ResendLink,
                          size: SsV2ButtonSize.small,
                          expand: false,
                          onPressed: () {
                            widget.session.setPendingVerificationEmail(
                              _emailController.text.trim(),
                            );
                            context.push(AppRoutes.verifyEmail);
                          },
                        ),
                      if (failure == AuthFailureCode.consentRequired)
                        SsV2Button(
                          label: l10n.v2CreateAccount,
                          size: SsV2ButtonSize.small,
                          expand: false,
                          onPressed: () => context.push(AppRoutes.register),
                        ),
                    ],
                  ),
                SocialSignInButtons(enabled: !busy, onProvider: _social),
                SsV2OrDivider(label: l10n.v2Or),
                SsV2TextField(
                  label: l10n.v2EmailLabel,
                  controller: _emailController,
                  errorText: _emailError,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const <String>[AutofillHints.email],
                  onChanged: (_) {
                    if (_emailError != null) {
                      setState(() => _emailError = null);
                    }
                  },
                ),
                SsV2PasswordField(
                  label: l10n.v2PasswordLabel,
                  controller: _passwordController,
                  errorText:
                      _passwordError ??
                      (invalidCredentials ? l10n.v2IncorrectPassword : null),
                  showLabel: l10n.v2ShowPassword,
                  hideLabel: l10n.v2HidePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                    if (invalidCredentials) _controller.clearFailure();
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: SsV2Link(
                    label: l10n.v2ForgotPassword,
                    onPressed: busy
                        ? null
                        : () => context.push(AppRoutes.forgotPassword),
                  ),
                ),
                const Spacer(),
                SsV2Button(
                  label: l10n.v2SignIn,
                  isLoading: busy,
                  onPressed: _submit,
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    Text(
                      '${l10n.v2NoAccountPrompt} ',
                      style: TextStyle(fontSize: 14, color: palette.textMuted),
                    ),
                    SsV2Link(
                      label: l10n.v2CreateAnAccount,
                      onPressed: busy
                          ? null
                          : () => context.push(AppRoutes.register),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
