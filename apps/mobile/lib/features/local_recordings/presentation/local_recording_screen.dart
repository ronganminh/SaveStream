/// R02-android/R02-ios/R03/R04 — Active Local recording states.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/contracts/local_recorder.dart';
import '../../../platform/platform_providers.dart';
import '../../channels/domain/models/watch_summary.dart';
import '../../channels/presentation/controllers/watch_providers.dart';
import '../../devices/domain/models/device_registration.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../recordings/domain/models/recording_summary.dart';
import '../domain/models/local_recording_models.dart';
import 'controllers/local_recording_controller.dart';
import 'controllers/rewarded_minutes_controller.dart';
import 'local_recording_alerts.dart';
import 'local_recording_reward_sheet.dart';

class LocalRecordingScreen extends ConsumerWidget {
  const LocalRecordingScreen({required this.watchId, super.key});

  final String watchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WatchSummary?> watch = ref.watch(
      watchDetailProvider(watchId),
    );
    final AsyncValue<Entitlement> entitlement = ref.watch(entitlementProvider);
    final LocalRecordingController controller = ref.watch(
      localRecordingControllerProvider,
    );
    final bool isSecondary =
        controller.secondarySession?.watchId == watchId;
    final bool isPrimary = controller.activeSession?.watchId == watchId;
    final AsyncValue<LocalRecorderState> recorder = ref.watch(
      isSecondary
          ? secondaryLocalRecorderStateProvider
          : localRecorderStateProvider,
    );
    final RewardedMinutesState rewarded = ref.watch(
      rewardedMinutesControllerProvider,
    );

    if (!watch.hasValue || !entitlement.hasValue) {
      return const Scaffold(body: SafeArea(child: _LocalRecordingSkeleton()));
    }
    final WatchSummary? creator = watch.value;
    if (creator == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SsEmptyState(
              icon: Icons.person_off_outlined,
              title: context.l10n.channelNotFoundTitle,
              message: context.l10n.channelNotFoundBody,
            ),
          ),
        ),
      );
    }

    final LocalRecorderState state = _stateOrStarting(recorder);
    final LocalRecordingSession? session = isSecondary
        ? controller.secondarySession
        : isPrimary
        ? controller.activeSession
        : null;
    final int remainingSeconds = _remainingSeconds(
      session,
      state.recordedSeconds,
    );
    final bool canStop =
        session != null && state.phase != LocalRecorderPhase.finalizing;
    final LocalEntitlement localEntitlement = entitlement.requireValue.local;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.pop(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        title: Text(context.l10n.localRecordingActiveTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SsSpacing.lg),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                creator.creatorDisplayName,
                                style: textTheme.headlineSmall,
                              ),
                              Text(creator.creatorUsername),
                            ],
                          ),
                        ),
                        const SsLiveBadge(isLive: true),
                      ],
                    ),
                    const SizedBox(height: SsSpacing.lg),
                    SsLocationChip(
                      engine: Engine.local,
                      label: context.l10n.localLabel,
                    ),
                    const SizedBox(height: SsSpacing.lg),
                    Semantics(
                      label: context.l10n.localRecordingElapsedSemantics(
                        formatDurationHms(
                          Duration(seconds: state.recordedSeconds),
                        ),
                      ),
                      child: Text(
                        formatDurationHms(
                          Duration(seconds: state.recordedSeconds),
                        ),
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    const SizedBox(height: SsSpacing.xs),
                    Text(
                      context.l10n.localRecordingSavedHere(
                        formatFileSize(state.sizeBytes),
                      ),
                    ),
                    const SizedBox(height: SsSpacing.lg),
                    LocalRecordingAlerts(
                      state: state,
                      creatorName: creator.creatorDisplayName,
                      remainingSeconds: remainingSeconds,
                      isUnlimited: localEntitlement.unlimited,
                      minutesPerReward: localEntitlement.minutesPerReward,
                      extensionsCap: localEntitlement.extensionsCapPerRecording,
                      rewardState: rewarded,
                      onRewardRequested:
                          !isSecondary &&
                              _canRequestReward(rewarded, localEntitlement)
                          ? () {
                              showRewardedMinutesSheet(
                                context: context,
                                ref: ref,
                                entitlement: localEntitlement,
                                extensionsUsed: rewarded.extensionCount,
                              );
                            }
                          : null,
                    ),
                    if (!localEntitlement.unlimited &&
                        session != null) ...<Widget>[
                      const SizedBox(height: SsSpacing.lg),
                      SsQuotaCard(
                        title: context.l10n.localRecordingFreeRemainingTitle,
                        value: _formatCountdown(remainingSeconds),
                        subtitle:
                            '${context.l10n.rewardMinutesExtensionProgress(rewarded.extensionCount, localEntitlement.extensionsCapPerRecording)} · '
                            '${context.l10n.rewardMinutesDailyProgress(localEntitlement.rewardsUsedToday, localEntitlement.rewardsCapPerDay)}',
                      ),
                    ],
                    const SizedBox(height: SsSpacing.lg),
                    _PlatformAlert(
                      platform: ref.watch(deviceInfoServiceProvider).platform,
                    ),
                    const SizedBox(height: SsSpacing.lg),
                    SsPrimaryButton(
                      label: context.l10n.localRecordingStopAction,
                      icon: Icons.stop_circle_outlined,
                      onPressed: !canStop
                          ? null
                          : () async {
                              if (isSecondary) {
                                await controller.stopSecond(
                                  status: RecordingStatus.completed,
                                );
                              } else {
                                await controller.stop(
                                  status: RecordingStatus.completed,
                                );
                              }
                              if (context.mounted) {
                                context.pop();
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canRequestReward(
    RewardedMinutesState rewarded,
    LocalEntitlement entitlement,
  ) {
    if (rewarded.extensionCount >= entitlement.extensionsCapPerRecording) {
      return false;
    }
    if (entitlement.rewardsUsedToday >= entitlement.rewardsCapPerDay) {
      return false;
    }
    return rewarded.phase != RewardedMinutesPhase.locked;
  }

  LocalRecorderState _stateOrStarting(AsyncValue<LocalRecorderState> recorder) {
    return recorder.value ??
        const LocalRecorderState(phase: LocalRecorderPhase.starting);
  }

  int _remainingSeconds(LocalRecordingSession? session, int recordedSeconds) {
    if (session == null) return 0;
    final int remaining = session.grantedSeconds - recordedSeconds;
    if (remaining <= 0) return 0;
    if (remaining >= session.grantedSeconds) {
      return session.grantedSeconds;
    }
    return remaining;
  }

  String _formatCountdown(int seconds) {
    final int minutes = seconds ~/ 60;
    final int rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${rest.toString().padLeft(2, '0')}';
  }
}

class _PlatformAlert extends StatelessWidget {
  const _PlatformAlert({required this.platform});

  final DevicePlatform platform;

  @override
  Widget build(BuildContext context) {
    if (platform == DevicePlatform.android) {
      return SsInlineAlert(
        title: context.l10n.localRecordingAndroidActiveTitle,
        message: context.l10n.localRecordingAndroidActiveBody,
      );
    }
    return SsInlineAlert(
      title: context.l10n.nativeKeepAppOpenReminderTitle,
      message: context.l10n.localRecordingIosActiveBody,
    );
  }
}

class _LocalRecordingSkeleton extends StatelessWidget {
  const _LocalRecordingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(height: 72, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 140, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 110, radius: SsRadii.lg),
      ],
    );
  }
}
