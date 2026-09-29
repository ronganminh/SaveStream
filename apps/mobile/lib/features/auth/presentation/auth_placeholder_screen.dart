import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

enum AuthPlaceholderKind { signIn, register, verifyEmail, forgotPassword }

class AuthPlaceholderScreen extends StatelessWidget {
  const AuthPlaceholderScreen({
    required this.kind,
    required this.session,
    super.key,
  });

  final AuthPlaceholderKind kind;
  final AppSessionController session;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String title = switch (kind) {
      AuthPlaceholderKind.signIn => l10n.signInTitle,
      AuthPlaceholderKind.register => l10n.registerTitle,
      AuthPlaceholderKind.verifyEmail => l10n.verifyEmailTitle,
      AuthPlaceholderKind.forgotPassword => l10n.forgotPasswordTitle,
    };

    return Scaffold(
      appBar: kind == AuthPlaceholderKind.signIn
          ? null
          : AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SsSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SsLogoMark(size: 64),
                  const SizedBox(height: SsSpacing.xl),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SsSpacing.md),
                  Text(
                    kind == AuthPlaceholderKind.signIn
                        ? l10n.signInPreviewBody
                        : l10n.authPlaceholderBody,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SsSpacing.xl),
                  if (kind == AuthPlaceholderKind.signIn) ...<Widget>[
                    SsPrimaryButton(
                      label: l10n.previewSignInAction,
                      onPressed: session.signInForPreview,
                    ),
                    const SizedBox(height: SsSpacing.sm),
                    SsTextAction(
                      label: l10n.registerTitle,
                      onPressed: () => context.push(AppRoutes.register),
                    ),
                  ] else
                    SsSecondaryButton(
                      label: l10n.backToSignIn,
                      onPressed: () => context.go(AppRoutes.signIn),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
