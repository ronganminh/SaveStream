/// A06-verify — Verify email after email/password sign-up.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
    this.initialToken,
    super.key,
  });

  final AuthRepository repository;
  final AppSessionController session;
  final String? initialToken;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late final AuthController _controller;
  bool _checkingLink = false;
  String? _lastHandledToken;

  @override
  void initState() {
    super.initState();
    _controller = AuthController(
      repository: widget.repository,
      session: widget.session,
    );
    _scheduleTokenVerification(widget.initialToken);
  }

  @override
  void didUpdateWidget(covariant VerifyEmailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialToken != oldWidget.initialToken) {
      _scheduleTokenVerification(widget.initialToken);
    }
  }

  void _scheduleTokenVerification(String? rawToken) {
    final String token = rawToken?.trim() ?? '';
    if (token.isEmpty || token == _lastHandledToken) return;
    _lastHandledToken = token;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _verify(token);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify(String token) async {
    if (_checkingLink) return;
    setState(() {
      _checkingLink = true;
    });
    final bool verified = await _controller.verifyEmail(token: token);
    if (!mounted) return;
    setState(() {
      _checkingLink = false;
    });
    if (verified) {
      SsToast.show(context, context.l10n.emailVerifiedSignInMessage);
      // The current backend verify endpoint returns a message, not login
      // tokens. Keep auth/session truthful and sign in before onboarding.
      context.go(AppRoutes.signIn);
    }
  }

  Future<void> _openEmail() async {
    await launchUrl(
      Uri(scheme: 'mailto'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _resend(String email) async {
    final bool sent = await _controller.resendVerification(email: email);
    if (sent && mounted) {
      SsToast.show(context, context.l10n.verificationResentMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? email = widget.session.pendingVerificationEmail;

    return AuthScaffold(
      title: l10n.verifyEmailTitle,
      subtitle: email == null
          ? l10n.verifyEmailGenericBody
          : l10n.verifyEmailBody(email),
      showBackButton: true,
      onBack: () => context.go(AppRoutes.signIn),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(
                Icons.mark_email_read_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              if (_checkingLink || _controller.isLoading) ...<Widget>[
                const SizedBox(height: SsSpacing.lg),
                SsInlineAlert(
                  title: l10n.verifyingEmailMessage,
                  tone: SsInlineAlertTone.info,
                ),
              ],
              if (_controller.failure != null) ...<Widget>[
                const SizedBox(height: SsSpacing.lg),
                AuthFailureBanner(failure: _controller.failure!),
              ],
              const SizedBox(height: SsSpacing.xl),
              SsPrimaryButton(
                label: l10n.openEmailAppAction,
                icon: Icons.open_in_new_rounded,
                onPressed: _openEmail,
              ),
              if (email != null) ...<Widget>[
                const SizedBox(height: SsSpacing.sm),
                SsTextAction(
                  label: l10n.resendVerificationAction,
                  onPressed: _controller.isLoading
                      ? null
                      : () => _resend(email),
                ),
                SsTextAction(
                  label: l10n.changeEmailAction,
                  onPressed: _controller.isLoading
                      ? null
                      : () => context.go(AppRoutes.register),
                ),
              ],
              const SizedBox(height: SsSpacing.lg),
              Text(
                l10n.emailHelpSpam,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}
