/// AForgot — request a password reset link.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/repositories/auth_repository.dart';
import 'controllers/auth_controller.dart';
import 'widgets/auth_v2_parts.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    required this.repository,
    required this.session,
    this.initialEmail,
    super.key,
  });

  final AuthRepository repository;
  final AppSessionController session;

  /// Prefilled when a signed-in user changes the password from Profile.
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  late final AuthController _controller;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _controller = AuthController(
      repository: widget.repository,
      session: widget.session,
    );
    _emailController.text = widget.initialEmail ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _emailError = validateEmail(context.l10n, _emailController.text);
    });
    if (_emailError != null) return;
    final String email = _emailController.text.trim();
    final bool sent = await _controller.forgotPassword(email: email);
    if (sent && mounted) {
      context.go(AppRoutes.checkEmailLocation(email));
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.signIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SsV2Page(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final AuthFailureCode? failure = _controller.failure;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SsV2Header(onBack: _back),
              Expanded(
                child: SsV2FillScroll(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  gap: 20,
                  children: <Widget>[
                    SsV2TitleBlock(
                      title: l10n.v2ForgotTitle,
                      subtitle: Text(l10n.v2ForgotSubtitle),
                    ),
                    if (failure != null) AuthErrorBanner(failure: failure),
                    SsV2TextField(
                      label: l10n.v2EmailLabel,
                      controller: _emailController,
                      errorText: _emailError,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.email],
                      onSubmitted: (_) => _submit(),
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                      },
                    ),
                    const Spacer(),
                    SsV2Button(
                      label: l10n.v2SendResetLink,
                      isLoading: _controller.isLoading,
                      onPressed: _submit,
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
