import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/contracts/local_recorder.dart';
import '../../entitlement/domain/models/entitlement.dart';

class HomeLocalRecordingCard extends StatelessWidget {
  const HomeLocalRecordingCard({
    required this.creatorName,
    required this.watchId,
    required this.state,
    required this.remainingSeconds,
    required this.unlimited,
    super.key,
  });

  final String creatorName;
  final String watchId;
  final LocalRecorderState state;
  final int remainingSeconds;
  final bool unlimited;

  @override
  Widget build(BuildContext context) {
    final String quota = unlimited
        ? context.l10n.proManualRecordLocalUnlimitedBody
        : context.l10n.homeRecordingRemaining(
            formatDurationHms(Duration(seconds: remainingSeconds)),
          );

    return SsCard(
      child: InkWell(
        onTap: () => context.push(AppRoutes.localRecording(watchId)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const SsLiveBadge(isLive: true),
                const SizedBox(width: SsSpacing.sm),
                SsLocationChip(
                  engine: Engine.local,
                  label: context.l10n.localLabel,
                ),
                const Spacer(),
                Text(
                  formatDurationHms(Duration(seconds: state.recordedSeconds)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: SsSpacing.md),
            Text(creatorName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: SsSpacing.xs),
            Text('${context.l10n.homeLocalSaveHint} · $quota'),
          ],
        ),
      ),
    );
  }
}

class HomeFinalizingRecordingCard extends StatelessWidget {
  const HomeFinalizingRecordingCard({
    required this.creatorName,
    required this.step,
    super.key,
  });

  final String creatorName;
  final LocalFinalizationStep? step;

  @override
  Widget build(BuildContext context) {
    final LocalFinalizationStep current =
        step ?? LocalFinalizationStep.stopCapture;
    final List<String> labels = <String>[
      context.l10n.localRecordingFinalizeStopStep,
      context.l10n.localRecordingFinalizeFlushStep,
      context.l10n.localRecordingFinalizeVerifyStep,
      context.l10n.localRecordingFinalizeRegisterStep,
    ];

    return SsCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.save_outlined),
          const SizedBox(width: SsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.homeFinalizingTitle(creatorName),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: SsSpacing.xs),
                Text(
                  context.l10n.homeFinalizingStep(
                    current.index + 1,
                    LocalFinalizationStep.values.length,
                    labels[current.index],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeSecondSlotOpenCard extends StatelessWidget {
  const HomeSecondSlotOpenCard({required this.expiresAt, super.key});

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final String time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(expiresAt.toLocal()));
    return SsInlineAlert(
      title: context.l10n.secondLocalSlotUnlockedTitle,
      message: context.l10n.homeSecondSlotOpenBody(time),
      tone: SsInlineAlertTone.success,
    );
  }
}

class HomeDailyRecordingExhaustedCard extends StatelessWidget {
  const HomeDailyRecordingExhaustedCard({
    required this.dailyMinutes,
    required this.rewardsUsed,
    required this.rewardsCap,
    required this.resetLabel,
    required this.onBuyCloudHours,
    super.key,
  });

  final int dailyMinutes;
  final int rewardsUsed;
  final int rewardsCap;
  final String resetLabel;
  final VoidCallback onBuyCloudHours;

  @override
  Widget build(BuildContext context) {
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            context.l10n.homeDailyRecordingExhaustedTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsSpacing.sm),
          Text(
            context.l10n.homeDailyRecordingExhaustedBody(
              dailyMinutes,
              rewardsUsed,
              rewardsCap,
              resetLabel,
            ),
          ),
          const SizedBox(height: SsSpacing.md),
          SsPrimaryButton(
            label: context.l10n.buyCloudHoursAction,
            icon: Icons.cloud_outlined,
            onPressed: onBuyCloudHours,
          ),
        ],
      ),
    );
  }
}
