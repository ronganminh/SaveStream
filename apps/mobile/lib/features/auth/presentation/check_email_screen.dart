/// AForgotSent — reset link requested.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';

class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String trimmed = email.trim();
    return SsV2Page(
      child: SsV2StatusBody(
        glyph: SsV2IconGlyph.mail,
        tone: SsV2TileTone.brand,
        title: l10n.v2ForgotSentTitle,
        body: trimmed.isEmpty
            ? l10n.v2ForgotSentBodyGeneric
            : l10n.v2ForgotSentBody(trimmed),
        actions: <Widget>[
          SsV2Button(label: l10n.v2OpenEmailApp, onPressed: openEmailApp),
          SsV2Button(
            label: l10n.v2BackToSignIn,
            variant: SsV2ButtonVariant.text,
            onPressed: () => context.go(AppRoutes.signIn),
          ),
        ],
      ),
    );
  }
}

/// Opens the default mail app through a bare `mailto:` link.
Future<void> openEmailApp() async {
  await launchUrl(Uri(scheme: 'mailto'), mode: LaunchMode.externalApplication);
}
