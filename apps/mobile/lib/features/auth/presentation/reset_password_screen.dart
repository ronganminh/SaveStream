/// AReset · AResetDone — choose a new password from the emailed link.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/repositories/auth_repository.dart';
import 'controllers/auth_controller.dart';
import 'widgets/auth_v2_parts.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    required this.repository,
    required this.session,
    this.initialToken,
    super.key,
  });

  final AuthRepository repository;
  final AppSessionController session;
  final String? initialToken;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  late final AuthController _controller;
  String? _passwordError;
  String? _confirmError;
  bool _completed = false;

  bool get _hasUsableToken => (widget.initialToken ?? '').trim().isNotEmpty;

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
    _passwordController.dispose();
    _confirmController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    FocusScope.of(context).unfocus();
    final String password = _passwordController.text;
    setState(() {
      _passwordError = password.isEmpty
          ? l10n.v2PasswordRequired
          : password.length < 8
          ? l10n.v2PasswordTooShort
          : null;
      _confirmError = _confirmController.text != password
          ? l10n.v2PasswordsDontMatch
          : null;
    });
    if (!_hasUsableToken || _passwordError != null || _confirmError != null) {
      return;
    }
    final bool reset = await _controller.resetPassword(
      token: widget.initialToken!.trim(),
      password: password,
    );
    if (reset && mounted) {
      setState(() => _completed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (_completed) {
      return SsV2Page(
        child: SsV2StatusBody(
          glyph: SsV2IconGlyph.lock,
          tone: SsV2TileTone.success,
          title: l10n.v2ResetDoneTitle,
          body: l10n.v2ResetDoneBody,
          actions: <Widget>[
            SsV2Button(
              label: l10n.v2SignIn,
              onPressed: () => context.go(AppRoutes.signIn),
            ),
          ],
        ),
      );
    }

    return SsV2Page(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final AuthFailureCode? failure = _controller.failure;
          final bool badLink =
              !_hasUsableToken || failure == AuthFailureCode.invalidToken;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SsV2Header(title: l10n.v2ResetTitle),
              Expanded(
                child: SsV2FillScroll(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                  gap: 20,
                  children: <Widget>[
                    if (badLink)
                      SsV2Banner(
                        tone: SsV2Tone.error,
                        actions: <Widget>[
                          SsV2Button(
                            label: l10n.v2RequestNewLink,
                            size: SsV2ButtonSize.small,
                            expand: false,
                            onPressed: () =>
                                context.go(AppRoutes.forgotPassword),
                          ),
                        ],
                        child: Text(l10n.v2ResetLinkInvalid),
                      )
                    else if (failure != null)
                      AuthErrorBanner(failure: failure),
                    SsV2PasswordField(
                      label: l10n.v2NewPassword,
                      controller: _passwordController,
                      errorText: _passwordError,
                      helperText: l10n.v2PasswordHelper,
                      showLabel: l10n.v2ShowPassword,
                      hideLabel: l10n.v2HidePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[AutofillHints.newPassword],
                      onChanged: (_) {
                        if (_passwordError != null) {
                          setState(() => _passwordError = null);
                        }
                      },
                    ),
                    SsV2PasswordField(
                      label: l10n.v2ConfirmPassword,
                      controller: _confirmController,
                      errorText: _confirmError,
                      showLabel: l10n.v2ShowPassword,
                      hideLabel: l10n.v2HidePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.newPassword],
                      onSubmitted: (_) => _submit(),
                      onChanged: (_) {
                        if (_confirmError != null) {
                          setState(() => _confirmError = null);
                        }
                      },
                    ),
                    const Spacer(),
                    SsV2Button(
                      label: l10n.v2SavePassword,
                      isLoading: _controller.isLoading,
                      onPressed: badLink ? null : _submit,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
