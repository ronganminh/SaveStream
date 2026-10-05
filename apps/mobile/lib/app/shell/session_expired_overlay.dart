import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/savestream_widgets.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../l10n/l10n.dart';
import '../session/app_session_controller.dart';
import '../theme/ss_tokens.dart';

class SessionExpiredOverlay extends ConsumerStatefulWidget {
  const SessionExpiredOverlay({
    required this.session,
    required this.localRecordingActive,
    super.key,
  });

  final AppSessionController session;
  final bool localRecordingActive;

  @override
  ConsumerState<SessionExpiredOverlay> createState() =>
      _SessionExpiredOverlayState();
}

class _SessionExpiredOverlayState extends ConsumerState<SessionExpiredOverlay> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _busy = false;
  bool _dismissed = false;
  bool _failed = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      widget.session.markAuthenticated();
    } on AuthException {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return Positioned(
        left: SsSpacing.md,
        right: SsSpacing.md,
        top: SsSpacing.md,
        child: SafeArea(
          child: SsInlineAlert(
            title: context.l10n.sessionExpiredTitle,
            message: widget.localRecordingActive
                ? context.l10n.sessionExpiredRecordingBody
                : context.l10n.sessionExpiredBody,
            tone: SsInlineAlertTone.warning,
          ),
        ),
      );
    }

    return Positioned.fill(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.72),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(SsSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SsCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Icon(
                        Icons.lock_clock_rounded,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: SsSpacing.md),
                      Text(
                        context.l10n.sessionExpiredTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: SsSpacing.sm),
                      Text(
                        widget.localRecordingActive
                            ? context.l10n.sessionExpiredRecordingBody
                            : context.l10n.sessionExpiredBody,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: SsSpacing.lg),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const <String>[AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: context.l10n.emailLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: SsSpacing.sm),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: const <String>[AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: context.l10n.passwordLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      if (_failed) ...<Widget>[
                        const SizedBox(height: SsSpacing.sm),
                        Text(
                          context.l10n.sessionExpiredReloginFailed,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: SsSpacing.lg),
                      SsPrimaryButton(
                        label: _busy
                            ? context.l10n.processingLabel
                            : context.l10n.signInAgainAction,
                        onPressed: _busy ? null : _signIn,
                      ),
                      if (widget.localRecordingActive) ...<Widget>[
                        const SizedBox(height: SsSpacing.sm),
                        SsSecondaryButton(
                          label: context.l10n.laterAction,
                          onPressed: () => setState(() => _dismissed = true),
                        ),
                        const SizedBox(height: SsSpacing.sm),
                        Text(
                          context.l10n.sessionExpiredRecordingSafeBody,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
