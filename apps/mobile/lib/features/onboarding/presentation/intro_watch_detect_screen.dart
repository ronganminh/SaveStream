/// A07 — Intro · Watch & Detect · step 1/3.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import 'widgets/onboarding_step_scaffold.dart';

class IntroWatchDetectScreen extends StatelessWidget {
  const IntroWatchDetectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return OnboardingStepScaffold(
      stepLabel: l10n.onboardingStepLabel(1, 3),
      title: l10n.introWatchTitle,
      body: l10n.introWatchBody,
      icon: Icons.visibility_outlined,
      skipLabel: l10n.onboardingSkipAction,
      onSkip: () => context.go(AppRoutes.onboardingNotifications),
      primaryLabel: l10n.continueAction,
      onPrimary: () => context.go(AppRoutes.introLocalCloud),
      child: Column(
        children: <Widget>[
          SsCreatorTile(
            name: l10n.onboardingSampleCreatorOneName,
            handle: l10n.onboardingSampleCreatorOneHandle,
            isLive: true,
            trailing: SsStatusChip(
              label: l10n.liveStatus,
              tone: SsStatusTone.recording,
            ),
          ),
          const SizedBox(height: SsSpacing.sm),
          SsCreatorTile(
            name: l10n.onboardingSampleCreatorTwoName,
            handle: l10n.onboardingSampleCreatorTwoHandle,
            trailing: SsStatusChip(label: l10n.offlineStatus),
          ),
          const SizedBox(height: SsSpacing.md),
          SsInlineAlert(
            title: l10n.introWatchMockNotificationTitle,
            message: l10n.introWatchMockNotificationBody,
            tone: SsInlineAlertTone.info,
          ),
        ],
      ),
    );
  }
}
