/// A05b — Set a new password from an email link.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/repositories/auth_repository.dart';
import 'controllers/auth_controller.dart';
import 'widgets/auth_scaffold.dart';

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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  late final AuthController _controller;
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
    FocusScope.of(context).unfocus();
    if (!_hasUsableToken || !_formKey.currentState!.validate()) return;
    final bool reset = await _controller.resetPassword(
      token: widget.initialToken!.trim(),
      password: _passwordController.text,
    );
    if (reset && mounted) {
      setState(() {
        _completed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool expired =
        !_hasUsableToken || _controller.failure == AuthFailureCode.invalidToken;

    if (_completed) {
      return AuthScaffold(
        title: l10n.resetPasswordSuccessTitle,
        subtitle: l10n.resetPasswordSuccessBody,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(
              Icons.check_circle_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: SsSpacing.xl),
            SsPrimaryButton(
              label: l10n.continueAction,
              onPressed: () => context.go(AppRoutes.signIn),
            ),
          ],
        ),
      );
    }

    if (expired) {
      return AuthScaffold(
        title: l10n.resetLinkExpiredTitle,
        subtitle: l10n.resetLinkExpiredBody,
        showBackButton: true,
        onBack: () => context.go(AppRoutes.signIn),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(
              Icons.link_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: SsSpacing.xl),
            SsPrimaryButton(
              label: l10n.sendNewLinkAction,
              onPressed: () => context.go(AppRoutes.forgotPassword),
            ),
            const SizedBox(height: SsSpacing.sm),
            SsSecondaryButton(
              label: l10n.backToSignIn,
              onPressed: () => context.go(AppRoutes.signIn),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      title: l10n.resetPasswordTitle,
      subtitle: l10n.resetPasswordAccountBody,
      showBackButton: true,
      onBack: () => context.go(AppRoutes.signIn),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_controller.failure != null) ...<Widget>[
                  SsInlineAlert(
                    title: l10n.authServerErrorMessage,
                    tone: SsInlineAlertTone.error,
                  ),
                  const SizedBox(height: SsSpacing.lg),
                ],
                SsPasswordField(
                  label: l10n.newPasswordLabel,
                  controller: _passwordController,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return l10n.passwordRequiredMessage;
                    }
                    if (value.length < 8) {
                      return l10n.passwordMinLengthMessage;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: SsSpacing.sm),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _passwordController,
                  builder: (BuildContext context, TextEditingValue value, _) {
                    final bool met = value.text.length >= 8;
                    return Row(
                      children: <Widget>[
                        Icon(
                          met
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: met
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: SsSpacing.sm),
                        Expanded(child: Text(l10n.passwordRuleMin8)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: SsSpacing.md),
                SsPasswordField(
                  label: l10n.confirmNewPasswordLabel,
                  controller: _confirmController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return l10n.confirmPasswordRequiredMessage;
                    }
                    if (value != _passwordController.text) {
                      return l10n.passwordMismatchMessage;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: SsSpacing.xl),
                SsPrimaryButton(
                  label: l10n.savePasswordAction,
                  isLoading: _controller.isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
