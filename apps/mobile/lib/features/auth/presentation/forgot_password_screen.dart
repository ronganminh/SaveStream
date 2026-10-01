import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/repositories/auth_repository.dart';
import 'auth_validation.dart';
import 'controllers/auth_controller.dart';
import 'widgets/auth_failure_banner.dart';
import 'widgets/auth_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    required this.repository,
    required this.session,
    super.key,
  });

  final AuthRepository repository;
  final AppSessionController session;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  late final AuthController _controller;
  bool _sent = false;

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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final bool sent = await _controller.forgotPassword(
      email: _emailController.text.trim(),
    );
    if (sent && mounted) {
      setState(() {
        _sent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    if (_sent) {
      return AuthScaffold(
        title: l10n.passwordResetSentTitle,
        subtitle: l10n.passwordResetSentBody,
        showBackButton: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(
              Icons.mark_email_read_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: SsSpacing.xl),
            SsPrimaryButton(
              label: l10n.backToSignIn,
              onPressed: () => context.go(AppRoutes.signIn),
            ),
            const SizedBox(height: SsSpacing.sm),
            SsTextAction(
              label: l10n.enterResetTokenAction,
              onPressed: () => context.go(AppRoutes.resetPassword),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      title: l10n.forgotPasswordTitle,
      subtitle: l10n.forgotPasswordSubtitle,
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
                  label: l10n.emailLabel,
                  hintText: l10n.emailHint,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline_rounded,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.emailRequiredMessage;
                    }
                    if (!AuthValidation.isEmail(value)) {
                      return l10n.emailInvalidMessage;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: SsSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: SsPrimaryButton(
                    label: l10n.sendResetLinkAction,
                    isLoading: _controller.isLoading,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
