/// A06 — Check email after password reset request.
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

class CheckEmailScreen extends StatefulWidget {
  const CheckEmailScreen({
    required this.repository,
    required this.session,
    required this.email,
    super.key,
  });

  final AuthRepository repository;
  final AppSessionController session;
  final String email;

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openEmail() async {
    await launchUrl(
      Uri(scheme: 'mailto'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _resend() async {
    final bool sent = await _controller.forgotPassword(email: widget.email);
    if (sent && mounted) {
      SsToast.show(context, context.l10n.passwordResetEmailResentMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AuthScaffold(
      title: l10n.checkEmailTitle,
      subtitle: l10n.checkEmailBody(widget.email),
      showBackButton: true,
      onBack: () => context.go(AppRoutes.forgotPassword),
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
              const SizedBox(height: SsSpacing.sm),
              SsTextAction(
                label: l10n.resendEmailAction,
                onPressed: _controller.isLoading ? null : _resend,
              ),
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
