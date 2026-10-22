/// ASignUp · ASignUpError — Create account with the 18+/Terms/Privacy/AUP
/// consent the server records (`RegisterRequest.consent`).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/legal/legal_consent.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/repositories/auth_repository.dart';
import 'controllers/auth_controller.dart';
import 'widgets/auth_v2_parts.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    required this.repository,
    required this.session,
    required this.config,
    this.onSignedIn,
    super.key,
  });

  final AuthRepository repository;
  final AppSessionController session;
  final AppConfig config;
  final VoidCallback? onSignedIn;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final AuthController _controller;
  bool _consent = false;
  bool _consentError = false;
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
    final String password = _passwordController.text;
    setState(() {
      _emailError = validateEmail(l10n, _emailController.text);
      _passwordError = password.isEmpty
          ? l10n.v2PasswordRequired
          : password.length < 8
          ? l10n.v2PasswordTooShort
          : null;
      _consentError = !_consent;
    });
    if (_emailError != null || _passwordError != null || !_consent) return;

    final bool registered = await _controller.register(
      email: _emailController.text.trim(),
      password: password,
      consent: LegalConsent.current,
    );
    if (registered && mounted) {
      context.go(AppRoutes.verifyEmailLocation(sent: true));
    }
  }

  Future<void> _google() => _social(SocialAuthProvider.google);

  Future<void> _social(SocialAuthProvider provider) async {
    if (!_consent) {
      setState(() => _consentError = true);
      return;
    }
    setState(() => _showGoogleError = false);
    final bool signedIn = await _controller.signInSocial(
      provider,
      consent: LegalConsent.current,
    );
    if (!mounted) return;
    if (signedIn) {
      widget.onSignedIn?.call();
      context.go(AppRoutes.home);
      return;
    }
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
    final bool busy = _controller.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SsV2Header(onBack: _back),
        Expanded(
          child: AutofillGroup(
            child: SsV2FillScroll(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              gap: 16,
              children: <Widget>[
                SsV2TitleBlock(
                  title: l10n.v2SignUpTitle,
                  subtitle: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(text: l10n.v2SignUpSubtitleLead),
                        TextSpan(
                          text: l10n.v2SignUpSubtitleEmphasis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                        TextSpan(text: l10n.v2SignUpSubtitleTail),
                      ],
                    ),
                  ),
                ),
                if (failure != null) AuthErrorBanner(failure: failure),
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
                  errorText: _passwordError,
                  helperText: l10n.v2PasswordHelper,
                  showLabel: l10n.v2ShowPassword,
                  hideLabel: l10n.v2HidePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                  },
                ),
                ConsentCheckbox(
                  value: _consent,
                  showError: _consentError,
                  termsUrl: widget.config.termsOfUseUrl,
                  privacyUrl: widget.config.privacyPolicyUrl,
                  acceptableUseUrl: widget.config.acceptableUseUrl,
                  onChanged: (bool value) => setState(() {
                    _consent = value;
                    if (value) _consentError = false;
                  }),
                ),
                const Spacer(),
                SsV2Button(
                  label: l10n.v2CreateAccount,
                  isLoading: busy,
                  onPressed: _submit,
                ),
                SsV2Disclaimer(text: l10n.v2NotAffiliated),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
