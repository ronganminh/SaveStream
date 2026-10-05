/// R02-android/R02-ios/R03/R04 — Active Local recording states.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
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
import 'controllers/recording_platform_controller.dart';
import 'controllers/rewarded_minutes_controller.dart';
import 'local_recording_alerts.dart';
import 'local_recording_reward_sheet.dart';

class LocalRecordingScreen extends ConsumerStatefulWidget {
  const LocalRecordingScreen({required this.watchId, super.key});

  final String watchId;

  @override
  ConsumerState<LocalRecordingScreen> createState() =>
      _LocalRecordingScreenState();
}

class _LocalRecordingScreenState extends ConsumerState<LocalRecordingScreen> {
  LocalRecordingSummary? _completed;
  bool _finishing = false;
  bool _autoStorageStopStarted = false;
  String? _finishError;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<WatchSummary?> watch = ref.watch(
      watchDetailProvider(widget.watchId),
    );
    final AsyncValue<Entitlement> entitlement = ref.watch(entitlementProvider);
    final LocalRecordingController controller = ref.watch(
      localRecordingControllerProvider,
    );
    final bool isSecondary =
        controller.secondarySession?.watchId == widget.watchId;
    final bool isPrimary = controller.activeSession?.watchId == widget.watchId;
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

    if (state.storageState == LocalStorageState.critical &&
        session != null &&
        !_finishing &&
        _completed == null &&
        !_autoStorageStopStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoStorageStopStarted) return;
        _autoStorageStopStarted = true;
        _finishRecording(
          controller: controller,
          isSecondary: isSecondary,
          endReason: RecordingEndReason.storageLow,
        );
      });
    }

    final LocalRecordingSummary? completed = _completed;
    if (completed != null) {
      return Scaffold(
        body: SafeArea(
          child: LocalRecordingCompletedBody(
            creatorName: creator.creatorDisplayName,
            summary: completed,
          ),
        ),
      );
    }

    if (_finishing || state.phase == LocalRecorderPhase.finalizing) {
      return Scaffold(
        body: SafeArea(
          child: LocalRecordingFinalizingBody(
            step: state.phase == LocalRecorderPhase.stopped
                ? LocalFinalizationStep.registerRecording
                : state.finalizationStep,
            errorMessage: _finishError,
          ),
        ),
      );
    }

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
          padding: const EdgeInsets.fromLTRB(
            SsSpacing.lg,
            SsSpacing.lg,
            SsSpacing.lg,
            SsSpacing.xxl,
          ),
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
                        textScaler: MediaQuery.textScalerOf(
                          context,
                        ).clamp(maxScaleFactor: 1.5),
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    const SizedBox(height: SsSpacing.xs),
                    Text(
                      context.l10n.localRecordingSavedHere(
                        formatFileSize(state.sizeBytes),
                      ),
                    ),
                    if (state.storageState != LocalStorageState.ok) ...<Widget>[
                      const SizedBox(height: SsSpacing.lg),
                      LocalRecordingStorageAlert(state: state),
                    ],
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
                    const SizedBox(height: SsSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          SsSpacing.lg,
          SsSpacing.sm,
          SsSpacing.lg,
          SsSpacing.lg,
        ),
        child: SsPrimaryButton(
          label: context.l10n.localRecordingStopAction,
          icon: Icons.stop_circle_outlined,
          onPressed: !canStop
              ? null
              : () => _confirmStop(
                  controller: controller,
                  isSecondary: isSecondary,
                  recordedSeconds: state.recordedSeconds,
                ),
        ),
      ),
    );
  }

  Future<void> _confirmStop({
    required LocalRecordingController controller,
    required bool isSecondary,
    required int recordedSeconds,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.localRecordingStopConfirmTitle),
          content: Text(
            context.l10n.localRecordingStopConfirmBody(
              formatDurationHms(Duration(seconds: recordedSeconds)),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.localRecordingContinueAction),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.localRecordingStopAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _finishRecording(
      controller: controller,
      isSecondary: isSecondary,
      endReason: RecordingEndReason.userStopped,
    );
  }

  Future<void> _finishRecording({
    required LocalRecordingController controller,
    required bool isSecondary,
    required RecordingEndReason endReason,
  }) async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _finishError = null;
    });
    try {
      final LocalRecordingSummary summary = isSecondary
          ? await controller.stopSecond(
              endReason: endReason,
              status: RecordingStatus.completed,
            )
          : await controller.stop(
              endReason: endReason,
              status: RecordingStatus.completed,
            );
      if (!mounted) return;
      await ref
          .read(recordingPlatformControllerProvider)
          .showCompleted(
            l10n: context.l10n,
            creatorName: summary.creatorDisplayName,
            recordedSeconds: summary.recordedSeconds,
            sizeBytes: summary.sizeBytes,
            recordingId: summary.id,
          );
      if (!mounted) return;
      setState(() {
        _completed = summary;
        _finishing = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _finishing = false;
        _finishError = error.toString();
      });
    }
  }

  bool _canRequestReward(
    RewardedMinutesState rewarded,
    LocalEntitlement entitlement,
  ) {
    if (entitlement.unlimited) {
      return false;
    }
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

class LocalRecordingStorageAlert extends StatelessWidget {
  const LocalRecordingStorageAlert({required this.state, super.key});

  final LocalRecorderState state;

  @override
  Widget build(BuildContext context) {
    final int freeStorageBytes = state.freeStorageBytes ?? 0;
    final int estimatedMinutes = state.estimatedStorageMinutes ?? 0;
    final bool critical = state.storageState == LocalStorageState.critical;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SsInlineAlert(
          title: critical
              ? context.l10n.localRecordingStorageCriticalTitle
              : context.l10n.localRecordingStorageLowTitle,
          message: critical
              ? context.l10n.localRecordingStorageCriticalBody
              : context.l10n.localRecordingStorageLowBody(
                  formatFileSize(freeStorageBytes),
                  estimatedMinutes,
                ),
          tone: SsInlineAlertTone.warning,
        ),
        if (!critical)
          Align(
            alignment: Alignment.centerLeft,
            child: SsTextAction(
              label: context.l10n.localRecordingCleanStorageAction,
              icon: Icons.cleaning_services_outlined,
              onPressed: () => context.push(AppRoutes.recordings),
            ),
          ),
      ],
    );
  }
}

class LocalRecordingFinalizingBody extends StatelessWidget {
  const LocalRecordingFinalizingBody({
    required this.step,
    this.errorMessage,
    super.key,
  });

  final LocalFinalizationStep? step;
  final String? errorMessage;

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

    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  context.l10n.localRecordingFinalizingTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: SsSpacing.lg),
                SsChecklist(
                  items: <SsChecklistItem>[
                    for (int index = 0; index < labels.length; index += 1)
                      SsChecklistItem(
                        label: labels[index],
                        done: index < current.index,
                        active: index == current.index,
                      ),
                  ],
                ),
                const SizedBox(height: SsSpacing.lg),
                SsInlineAlert(
                  title: context.l10n.localLabel,
                  message: context.l10n.localRecordingFinalizingBody,
                ),
                if (errorMessage != null) ...<Widget>[
                  const SizedBox(height: SsSpacing.md),
                  SsInlineAlert(
                    title: context.l10n.localRecordingErrorTitle,
                    message: errorMessage,
                    tone: SsInlineAlertTone.error,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class LocalRecordingCompletedBody extends StatelessWidget {
  const LocalRecordingCompletedBody({
    required this.creatorName,
    required this.summary,
    super.key,
  });

  final String creatorName;
  final LocalRecordingSummary summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Icon(Icons.check_circle_rounded, size: 56),
                const SizedBox(height: SsSpacing.md),
                Text(
                  context.l10n.localRecordingCompletedTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SsSpacing.lg),
                SsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        creatorName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: SsSpacing.sm),
                      SsLocationChip(
                        engine: Engine.local,
                        label: context.l10n.localLabel,
                      ),
                      const SizedBox(height: SsSpacing.sm),
                      Text(
                        context.l10n.localRecordingCompletedMeta(
                          formatDurationHms(
                            Duration(seconds: summary.recordedSeconds),
                          ),
                          formatFileSize(summary.sizeBytes),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SsSpacing.lg),
                SsPrimaryButton(
                  label: context.l10n.localRecordingOpenAction,
                  icon: Icons.play_circle_outline_rounded,
                  onPressed: () =>
                      context.push(AppRoutes.recordingDetail(summary.id)),
                ),
                const SizedBox(height: SsSpacing.sm),
                SsSecondaryButton(
                  label: context.l10n.localRecordingHomeAction,
                  onPressed: () => context.go(AppRoutes.home),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
