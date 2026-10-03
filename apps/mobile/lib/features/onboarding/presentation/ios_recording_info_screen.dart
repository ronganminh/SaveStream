/// A11 — iOS local-recording limitation intro.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import 'widgets/onboarding_step_scaffold.dart';

class IosRecordingInfoScreen extends StatelessWidget {
  const IosRecordingInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return OnboardingStepScaffold(
      title: l10n.iosRecordingInfoTitle,
      body: l10n.iosRecordingInfoBody,
      icon: Icons.phone_iphone_rounded,
      primaryLabel: l10n.gotItAction,
      onPrimary: () => context.go(AppRoutes.onboardingAddCreator),
      child: Column(
        children: <Widget>[
          _InfoRow(
            icon: Icons.phone_iphone_rounded,
            text: l10n.iosRecordingBackgroundBody,
          ),
          const SizedBox(height: SsSpacing.md),
          _InfoRow(
            icon: Icons.restore_rounded,
            text: l10n.iosRecordingRecoveryBody,
          ),
          const SizedBox(height: SsSpacing.md),
          SsInlineAlert(
            title: l10n.iosRecordingCloudTitle,
            message: l10n.iosRecordingCloudBody,
            tone: SsInlineAlertTone.info,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SsCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: SsSpacing.md),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
