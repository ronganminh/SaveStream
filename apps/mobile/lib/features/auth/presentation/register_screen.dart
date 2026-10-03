/// A04 — Sign up.
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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    required this.repository,
    required this.session,
    super.key,
  });

  final AuthRepository repository;
  final AppSessionController session;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final bool registered = await _controller.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (registered && mounted) {
      context.go(AppRoutes.verifyEmail);
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
    final AppLocalizations l10n = context.l10n;

    return AuthScaffold(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      showBackButton: true,
      onBack: _back,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_controller.failure != null) ...<Widget>[
                    AuthFailureBanner(failure: _controller.failure!),
                    const SizedBox(height: SsSpacing.lg),
                  ],
                  SsTextField(
                    label: l10n.fullNameLabel,
                    hintText: l10n.fullNameHint,
                    controller: _nameController,
                    prefixIcon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.name],
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.fullNameRequiredMessage;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: SsSpacing.md),
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
                    autofillHints: const <String>[AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
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
                      final Color color = met
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant;
                      return Semantics(
                        label: l10n.passwordRuleMin8,
                        value: met
                            ? l10n.requirementMetLabel
                            : l10n.requirementNotMetLabel,
                        child: Row(
                          children: <Widget>[
                            Icon(
                              met
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 20,
                              color: color,
                            ),
                            const SizedBox(width: SsSpacing.sm),
                            Expanded(
                              child: Text(
                                l10n.passwordRuleMin8,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(color: color),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: SsSpacing.xl),
                  SsPrimaryButton(
                    label: l10n.createAccountAction,
                    isLoading: _controller.isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: SsSpacing.md),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(l10n.haveAccountPrompt),
                      SsTextAction(
                        label: l10n.signInAction,
                        onPressed: _controller.isLoading
                            ? null
                            : () => context.go(AppRoutes.signIn),
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
