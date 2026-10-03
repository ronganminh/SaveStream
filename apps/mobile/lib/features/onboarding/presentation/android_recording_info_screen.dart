/// A10 — Android recording permission/battery rationale.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';
import 'widgets/onboarding_step_scaffold.dart';

class AndroidRecordingInfoScreen extends StatelessWidget {
  const AndroidRecordingInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    void next() => context.go(AppRoutes.onboardingAddCreator);

    return OnboardingStepScaffold(
      title: l10n.androidRecordingInfoTitle,
      body: l10n.androidRecordingInfoBody,
      icon: Icons.phone_android_rounded,
      primaryLabel: l10n.disableBatteryOptimizationAction,
      // Track A owns the rationale UI. Track C will replace this mock handoff
      // with the Android battery-optimization intent.
      onPrimary: next,
      secondaryLabel: l10n.laterAction,
      onSecondary: next,
      child: Column(
        children: <Widget>[
          SsCard(
            child: Row(
              children: <Widget>[
                const SsLogoMark(size: 36),
                const SizedBox(width: SsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.nativeRecordingNotificationTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(l10n.androidRecordingNotificationPreview),
                    ],
                  ),
                ),
                SsLocationChip(engine: Engine.local, label: l10n.localLabel),
              ],
            ),
          ),
          const SizedBox(height: SsSpacing.md),
          SsInlineAlert(
            title: l10n.androidBatteryWarningTitle,
            message: l10n.androidBatteryWarningBody,
            tone: SsInlineAlertTone.warning,
          ),
        ],
      ),
    );
  }
}
