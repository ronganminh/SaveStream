/// W09/W10/W10-waiting/W11/W12 — Creator detail states.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/platform_providers.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../local_recordings/presentation/controllers/local_recording_controller.dart';
import '../../local_recordings/presentation/local_recording_start_sheet.dart';
import '../../recordings/domain/models/recording_summary.dart';
import '../domain/models/channel_detail_view_model.dart';
import '../domain/models/watch_summary.dart';
import 'cloud_hours_upsell_sheet.dart';
import 'controllers/watch_providers.dart';

class ChannelDetailScreen extends ConsumerStatefulWidget {
  const ChannelDetailScreen({required this.watchId, super.key});

  final String watchId;

  @override
  ConsumerState<ChannelDetailScreen> createState() =>
      _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends ConsumerState<ChannelDetailScreen> {
  bool _mutating = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _startLocalRecording(
    WatchSummary watch,
    Entitlement entitlement,
  ) async {
    if (entitlement.plan != Plan.free) return;

    final deviceInfo = ref.read(deviceInfoServiceProvider);
    final int freeStorageBytes = await deviceInfo.freeStorageBytes;
    if (!mounted) return;

    final bool confirmed = await showLocalRecordingStartSheet(
      context: context,
      creatorName: watch.creatorDisplayName,
      entitlement: entitlement,
      platform: deviceInfo.platform,
      freeStorageBytes: freeStorageBytes,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(localRecordingControllerProvider).start(watchId: watch.id);
      if (mounted) {
        context.push(AppRoutes.localRecording(watch.id));
      }
    } on Object {
      if (mounted) {
        SsToast.show(context, context.l10n.localRecordingErrorTitle);
      }
    }
  }

  Future<void> _delete(WatchSummary watch) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          context.l10n.deleteChannelMessage(watch.creatorDisplayName),
        ),
        content: Text(
          context.l10n.deleteChannelMessage(watch.creatorDisplayName),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.deleteChannelAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => ref.read(watchControllerProvider).delete(watch.id));
    if (mounted) context.go(AppRoutes.channels);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ChannelDetailViewModel?> detail = ref.watch(
      channelDetailProvider(widget.watchId),
    );
    final AsyncValue<Entitlement> entitlement = ref.watch(entitlementProvider);
    final AsyncValue<List<RecordingSummary>> allRecordings = ref.watch(
      watchRecordingsProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.channelDetailTitle)),
      body: SafeArea(
        child: detail.when(
          loading: () => const _DetailSkeleton(),
          error: (Object error, StackTrace stack) => Center(
            child: SsAsyncErrorState(
              error: error,
              onRetry: () =>
                  ref.invalidate(channelDetailProvider(widget.watchId)),
            ),
          ),
          data: (ChannelDetailViewModel? value) {
            if (value == null) {
              return SsEmptyState(
                title: context.l10n.channelNotFoundTitle,
                message: context.l10n.channelNotFoundBody,
                icon: Icons.person_off_outlined,
              );
            }
            if (!entitlement.hasValue || !allRecordings.hasValue) {
              return const _DetailSkeleton();
            }
            return _DetailBody(
              data: value,
              entitlement: entitlement.requireValue,
              allRecordings: allRecordings.requireValue,
              mutating: _mutating,
              onNotify: (bool enabled) => _run(
                () => ref
                    .read(watchControllerProvider)
                    .setNotifyOnLive(value.watch.id, enabled: enabled),
              ),
              onPauseResume: () => _run(
                () => value.watch.status == WatchStatus.paused
                    ? ref.read(watchControllerProvider).resume(value.watch.id)
                    : ref.read(watchControllerProvider).pause(value.watch.id),
              ),
              onRecord: () => _startLocalRecording(
                value.watch,
                entitlement.requireValue,
              ),
              onDelete: () => _delete(value.watch),
            );
          },
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.data,
    required this.entitlement,
    required this.allRecordings,
    required this.mutating,
    required this.onNotify,
    required this.onPauseResume,
    required this.onRecord,
    required this.onDelete,
  });

  final ChannelDetailViewModel data;
  final Entitlement entitlement;
  final List<RecordingSummary> allRecordings;
  final bool mutating;
  final ValueChanged<bool> onNotify;
  final VoidCallback onPauseResume;
  final VoidCallback onRecord;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final WatchSummary watch = data.watch;
    final RecordingSummary? current = _currentRecording(data.recordings);
    final bool waiting =
        current?.status == RecordingStatus.waitingForCloudSlot ||
        watch.autoRecordState == AutoRecordState.waitingForCloudSlot;
    final bool missed = current?.status == RecordingStatus.missedNoCloudSlot;
    final bool paused = watch.status == WatchStatus.paused;

    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _CreatorHeader(watch: watch),
                const SizedBox(height: SsSpacing.lg),
                if (waiting)
                  _WaitingCard(
                    recording: current,
                    entitlement: entitlement,
                    allRecordings: allRecordings,
                  )
                else if (missed)
                  SsInlineAlert(
                    title: context.l10n.creatorMissedTitle,
                    message: context.l10n.creatorMissedBody,
                    tone: SsInlineAlertTone.warning,
                  )
                else if (paused)
                  SsInlineAlert(
                    title: context.l10n.watchPausedStatus,
                    message: context.l10n.creatorPausedBody,
                    tone: SsInlineAlertTone.warning,
                  )
                else if (watch.isLive)
                  _LiveCard(
                    watch: watch,
                    entitlement: entitlement,
                    onRecord: onRecord,
                  )
                else
                  SsInlineAlert(
                    title: context.l10n.creatorDetailStatusTitle,
                    message: context.l10n.creatorOfflineBody,
                  ),
                const SizedBox(height: SsSpacing.lg),
                SsCard(
                  child: Column(
                    children: <Widget>[
                      Semantics(
                        label: context.l10n.watchNotifyOnLive,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: watch.notifyOnLive,
                          title: Text(context.l10n.watchNotifyOnLive),
                          secondary: const Icon(
                            Icons.notifications_active_outlined,
                          ),
                          onChanged: mutating ? null : onNotify,
                        ),
                      ),
                      const Divider(),
                      if (entitlement.plan == Plan.pro)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.cloud_outlined),
                          title: Text(context.l10n.watchAutoRecordCloud),
                          subtitle: Text(
                            watch.autoRecord
                                ? context.l10n.autoRecordOnLabel
                                : context.l10n.autoRecordOffLabel,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(
                            AppRoutes.autoRecordSettings(watch.id),
                          ),
                        )
                      else
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lock_outline_rounded),
                          title: Text(context.l10n.watchAutoRecordCloud),
                          subtitle: Text(context.l10n.watchAutoRecordLocked),
                          onTap: () => showCloudHoursUpsellSheet(context),
                        ),
                    ],
                  ),
                ),
                if (data.latestRecording != null) ...<Widget>[
                  const SizedBox(height: SsSpacing.lg),
                  SsSectionHeader(
                    title: context.l10n.creatorRecentRecordingTitle,
                  ),
                  const SizedBox(height: SsSpacing.sm),
                  SsRecordingTile(
                    title: data.latestRecording!.creatorDisplayName,
                    subtitle: _recordingSubtitle(
                      context,
                      data.latestRecording!,
                    ),
                    engine: data.latestRecording!.engine,
                    onTap: () => context.push(
                      AppRoutes.recordingDetail(data.latestRecording!.id),
                    ),
                  ),
                ],
                const SizedBox(height: SsSpacing.xl),
                SsSecondaryButton(
                  label: paused
                      ? context.l10n.resumeMonitoringAction
                      : context.l10n.pauseMonitoringAction,
                  icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  onPressed: mutating ? null : onPauseResume,
                ),
                const SizedBox(height: SsSpacing.sm),
                TextButton.icon(
                  onPressed: mutating ? null : onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(context.l10n.deleteChannelAction),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CreatorHeader extends StatelessWidget {
  const _CreatorHeader({required this.watch});

  final WatchSummary watch;

  @override
  Widget build(BuildContext context) {
    return SsCard(
      child: Row(
        children: <Widget>[
          SsAvatar(label: watch.creatorDisplayName, radius: 30),
          const SizedBox(width: SsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  watch.creatorDisplayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(watch.creatorUsername),
              ],
            ),
          ),
          if (watch.isLive)
            const SsLiveBadge(isLive: true)
          else
            SsStatusChip(
              label: watch.status == WatchStatus.paused
                  ? context.l10n.watchPausedStatus
                  : context.l10n.offlineStatus,
            ),
        ],
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    required this.watch,
    required this.entitlement,
    required this.onRecord,
  });

  final WatchSummary watch;
  final Entitlement entitlement;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final bool free = entitlement.plan == Plan.free;
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            context.l10n.creatorLiveSince,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: SsSpacing.sm),
          if (free)
            SsLocationChip(engine: Engine.local, label: context.l10n.localLabel)
          else
            SsLocationChip(
              engine: Engine.cloud,
              label: context.l10n.cloudLabel,
            ),
          const SizedBox(height: SsSpacing.md),
          if (free)
            Text(
              context.l10n.homeFreeMinutesRemaining(
                entitlement.local.minutesRemaining,
                entitlement.local.dailyMinutes,
              ),
            )
          else
            Text(
              context.l10n.cloudTimeRemainingValue(
                formatMinutesAsHoursMinutes(
                  entitlement.cloudMinutesAvailable,
                  hoursLabel: context.l10n.timeHoursUnit,
                  minutesLabel: context.l10n.timeMinutesUnit,
                ),
              ),
            ),
          const SizedBox(height: SsSpacing.lg),
          SsPrimaryButton(
            label: context.l10n.recordNowAction,
            icon: Icons.fiber_manual_record_rounded,
            onPressed: free ? onRecord : null,
          ),
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
    required this.recording,
    required this.entitlement,
    required this.allRecordings,
  });

  final RecordingSummary? recording;
  final Entitlement entitlement;
  final List<RecordingSummary> allRecordings;

  @override
  Widget build(BuildContext context) {
    final List<RecordingSummary> activeCloud = allRecordings
        .where(
          (RecordingSummary item) =>
              item.engine == Engine.cloud &&
              item.status == RecordingStatus.recording,
        )
        .take(entitlement.limits.maxConcurrentCloudRecordings)
        .toList(growable: false);

    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsInlineAlert(
            title: context.l10n.creatorWaitingTitle,
            message: context.l10n.creatorWaitingBody(
              entitlement.limits.maxConcurrentCloudRecordings,
            ),
            tone: SsInlineAlertTone.warning,
          ),
          if (recording?.queuePosition != null) ...<Widget>[
            const SizedBox(height: SsSpacing.md),
            SsStatusChip(
              label: context.l10n.queuePositionLabel(recording!.queuePosition!),
              icon: Icons.format_list_numbered_rounded,
            ),
          ],
          if (activeCloud.isNotEmpty) ...<Widget>[
            const SizedBox(height: SsSpacing.lg),
            Text(
              context.l10n.activeCloudSlotsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: SsSpacing.sm),
            for (final RecordingSummary item in activeCloud)
              Padding(
                padding: const EdgeInsets.only(bottom: SsSpacing.sm),
                child: SsRecordingTile(
                  title: item.creatorDisplayName,
                  subtitle: formatDurationHms(
                    Duration(seconds: item.durationSeconds),
                  ),
                  engine: Engine.cloud,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

RecordingSummary? _currentRecording(List<RecordingSummary> recordings) {
  for (final RecordingSummary item in recordings) {
    if (item.status == RecordingStatus.waitingForCloudSlot ||
        item.status == RecordingStatus.missedNoCloudSlot ||
        item.isActiveLifecycle) {
      return item;
    }
  }
  return recordings.isEmpty ? null : recordings.first;
}

String _recordingSubtitle(BuildContext context, RecordingSummary recording) {
  return '${context.l10n.recordingDurationLabel}: '
      '${formatDurationHms(Duration(seconds: recording.durationSeconds))}';
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(height: 104, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 180, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 160, radius: SsRadii.lg),
      ],
    );
  }
}
