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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  late final AuthController _controller;
  bool _acceptedTerms = false;
  bool _showTermsError = false;

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
    _confirmController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final bool formValid = _formKey.currentState!.validate();
    setState(() {
      _showTermsError = !_acceptedTerms;
    });
    if (!formValid || !_acceptedTerms) {
      return;
    }

    final bool registered = await _controller.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (registered && mounted) {
      context.go(AppRoutes.verifyEmail);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AuthScaffold(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      showBackButton: true,
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
                    textInputAction: TextInputAction.next,
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return l10n.passwordRequiredMessage;
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
                  const SizedBox(height: SsSpacing.md),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _acceptedTerms,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.termsAcceptanceLabel),
                    onChanged: _controller.isLoading
                        ? null
                        : (bool? value) {
                            setState(() {
                              _acceptedTerms = value ?? false;
                              if (_acceptedTerms) {
                                _showTermsError = false;
                              }
                            });
                          },
                  ),
                  if (_showTermsError)
                    Padding(
                      padding: const EdgeInsets.only(left: SsSpacing.md),
                      child: Text(
                        l10n.termsRequiredMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: SsSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: SsPrimaryButton(
                      label: l10n.createAccountAction,
                      isLoading: _controller.isLoading,
                      onPressed: _submit,
                    ),
                  ),
                  const SizedBox(height: SsSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Flexible(child: Text(l10n.haveAccountPrompt)),
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
