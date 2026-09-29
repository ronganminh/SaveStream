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

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    required this.repository,
    required this.session,
    super.key,
  });

  final AuthRepository repository;
  final AppSessionController session;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  late final AuthController _controller;

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
    _codeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify(String email) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await _controller.verifyEmail(
      email: email,
      code: _codeController.text.trim(),
    );
  }

  Future<void> _resend(String email) async {
    final bool sent = await _controller.resendVerification(email: email);
    if (sent && mounted) {
      SsSnackbar.show(context, context.l10n.verificationResentMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? email = widget.session.pendingVerificationEmail;

    if (email == null) {
      return AuthScaffold(
        title: l10n.verifyEmailTitle,
        subtitle: l10n.noPendingVerificationMessage,
        showBackButton: true,
        child: SsPrimaryButton(
          label: l10n.backToSignIn,
          onPressed: () => context.go(AppRoutes.signIn),
        ),
      );
    }

    return AuthScaffold(
      title: l10n.verifyEmailTitle,
      subtitle: l10n.verifyEmailSubtitle,
      showBackButton: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SsCard(
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.mail_outline_rounded),
                      const SizedBox(width: SsSpacing.md),
                      Expanded(child: Text(email)),
                    ],
                  ),
                ),
                if (_controller.failure != null) ...<Widget>[
                  const SizedBox(height: SsSpacing.lg),
                  AuthFailureBanner(failure: _controller.failure!),
                ],
                const SizedBox(height: SsSpacing.lg),
                SsTextField(
                  label: l10n.verificationCodeLabel,
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.password_rounded,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _verify(email),
                  validator: (String? value) {
                    final String code = value?.trim() ?? '';
                    if (code.isEmpty) {
                      return l10n.verificationCodeRequiredMessage;
                    }
                    if (code.length != 6 ||
                        int.tryParse(code) == null) {
                      return l10n.verificationCodeInvalidMessage;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: SsSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: SsPrimaryButton(
                    label: l10n.verifyEmailAction,
                    isLoading: _controller.isLoading,
                    onPressed: () => _verify(email),
                  ),
                ),
                const SizedBox(height: SsSpacing.sm),
                SsTextAction(
                  label: l10n.resendVerificationAction,
                  onPressed: _controller.isLoading
                      ? null
                      : () => _resend(email),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
