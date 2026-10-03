/// A05 — Forgot password.
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
    if (!_formKey.currentState!.validate()) return;
    final String email = _emailController.text.trim();
    final bool sent = await _controller.forgotPassword(email: email);
    if (sent && mounted) {
      context.go(AppRoutes.checkEmailLocation(email));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AuthScaffold(
      title: l10n.forgotPasswordTitle,
      subtitle: l10n.forgotPasswordSubtitle,
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
                const SizedBox(height: SsSpacing.xl),
                SsPrimaryButton(
                  label: l10n.sendResetLinkAction,
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
