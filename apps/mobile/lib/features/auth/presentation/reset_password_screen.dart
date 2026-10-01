import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/repositories/auth_repository.dart';
import 'controllers/auth_controller.dart';
import 'widgets/auth_failure_banner.dart';
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
  late final TextEditingController _tokenController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  late final AuthController _controller;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.initialToken ?? '');
    _controller = AuthController(
      repository: widget.repository,
      session: widget.session,
    );
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final bool reset = await _controller.resetPassword(
      token: _tokenController.text.trim(),
      password: _passwordController.text,
    );
    if (reset && mounted) {
      SsSnackbar.show(context, context.l10n.passwordResetCompletedMessage);
      context.go(AppRoutes.signIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AuthScaffold(
      title: l10n.resetPasswordTitle,
      subtitle: l10n.resetPasswordSubtitle,
      showBackButton: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_controller.failure != null) ...<Widget>[
                  AuthFailureBanner(failure: _controller.failure!),
                  const SizedBox(height: SsSpacing.lg),
                ],
                SsTextField(
                  label: l10n.resetTokenLabel,
                  hintText: l10n.resetTokenHint,
                  controller: _tokenController,
                  prefixIcon: Icons.key_rounded,
                  textInputAction: TextInputAction.next,
                  validator: (String? value) {
                    final String token = value?.trim() ?? '';
                    if (token.isEmpty) return l10n.resetTokenRequiredMessage;
                    if (token.length < 16) return l10n.resetTokenInvalidMessage;
                    return null;
                  },
                ),
                const SizedBox(height: SsSpacing.md),
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
                const SizedBox(height: SsSpacing.md),
                SsPasswordField(
                  label: l10n.confirmPasswordLabel,
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
                const SizedBox(height: SsSpacing.lg),
                SsPrimaryButton(
                  label: l10n.resetPasswordAction,
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
