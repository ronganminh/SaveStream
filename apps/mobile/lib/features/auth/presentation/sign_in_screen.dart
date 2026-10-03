/// A03 · A03-error — Sign in.
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

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    required this.repository,
    required this.session,
    super.key,
  });

  final AuthRepository repository;
  final AppSessionController session;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
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
    _passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await _controller.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
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
    final AppLocalizations l10n = context.l10n;

    return AuthScaffold(
      title: l10n.signInTitle,
      showBackButton: true,
      onBack: _back,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final AuthFailureCode? failure = _controller.failure;
          final bool invalidCredentials =
              failure == AuthFailureCode.invalidCredentials;

          return AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (failure != null && !invalidCredentials) ...<Widget>[
                    AuthFailureBanner(
                      failure: failure,
                      actionLabel: failure == AuthFailureCode.emailNotVerified
                          ? l10n.verifyEmailAction
                          : null,
                      onAction: failure == AuthFailureCode.emailNotVerified
                          ? () => context.go(AppRoutes.verifyEmail)
                          : null,
                    ),
                    const SizedBox(height: SsSpacing.lg),
                  ],
                  SsTextField(
                    label: l10n.emailLabel,
                    hintText: l10n.emailHint,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.mail_outline_rounded,
                    autofillHints: const <String>[AutofillHints.email],
                    textInputAction: TextInputAction.next,
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
                  const SizedBox(height: SsSpacing.md),
                  SsPasswordField(
                    label: l10n.passwordLabel,
                    controller: _passwordController,
                    autofillHints: const <String>[AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return l10n.passwordRequiredMessage;
                      }
                      return null;
                    },
                  ),
                  if (invalidCredentials) ...<Widget>[
                    const SizedBox(height: SsSpacing.xs),
                    Text(
                      l10n.invalidCredentialsMessage,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: SsTextAction(
                      label: l10n.forgotPasswordAction,
                      onPressed: _controller.isLoading
                          ? null
                          : () => context.push(AppRoutes.forgotPassword),
                    ),
                  ),
                  const SizedBox(height: SsSpacing.sm),
                  SsPrimaryButton(
                    label: l10n.signInAction,
                    isLoading: _controller.isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: SsSpacing.md),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(l10n.noAccountPrompt),
                      SsTextAction(
                        label: l10n.createAccountAction,
                        onPressed: _controller.isLoading
                            ? null
                            : () => context.push(AppRoutes.register),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
