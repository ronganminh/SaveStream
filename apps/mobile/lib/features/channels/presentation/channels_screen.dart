/// W01/W03 — V2 Watching list.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/contracts/ads_service.dart';
import '../../../platform/platform_providers.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../local_recordings/presentation/controllers/local_recording_confirmation_controller.dart';
import '../../local_recordings/presentation/controllers/local_recording_controller.dart';
import '../../local_recordings/presentation/local_recording_reward_sheet.dart';
import '../../local_recordings/presentation/local_recording_start_sheet.dart';
import '../../local_recordings/presentation/second_local_slot_sheet.dart';
import '../../recordings/domain/models/recording_summary.dart';
import '../../recordings/presentation/controllers/recording_providers.dart';
import '../../settings/presentation/notification_action_button.dart';
import '../domain/models/watch_summary.dart';
import 'cloud_hours_upsell_sheet.dart';
import 'controllers/watch_providers.dart';
import 'pro_manual_record_sheet.dart';
import 'watch_limit_sheet.dart';

enum _WatchFilter { all, live, offline }

class ChannelsScreen extends ConsumerStatefulWidget {
  const ChannelsScreen({super.key});

  @override
  ConsumerState<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends ConsumerState<ChannelsScreen> {
  _WatchFilter _filter = _WatchFilter.all;
  final Set<String> _mutating = <String>{};

  Future<void> _startRecording(
    WatchSummary watch,
    Entitlement entitlement,
  ) async {
    if (_mutating.contains(watch.id)) return;
    setState(() => _mutating.add(watch.id));
    try {
      if (entitlement.plan == Plan.pro) {
        final Engine? engine = await showProManualRecordSheet(
          context: context,
          creatorName: watch.creatorDisplayName,
          entitlement: entitlement,
        );
        if (engine == null || !mounted) return;
        if (engine == Engine.cloud) {
          final RecordingSummary created = await ref
              .read(recordingControllerProvider)
              .create(
                CreateRecordingCommand(
                  sourceType: RecordingSourceType.username,
                  sourceValue: watch.creatorUsername,
                ),
              );
          if (mounted) context.push(AppRoutes.recordingDetail(created.id));
          return;
        }
      }
      await _startLocalRecording(watch, entitlement);
    } on Object {
      if (mounted) {
        SsToast.show(context, context.l10n.localRecordingErrorTitle);
      }
    } finally {
      if (mounted) setState(() => _mutating.remove(watch.id));
    }
  }

  Future<void> _startRewardedRecording(
    WatchSummary watch,
    Entitlement entitlement,
  ) async {
    final bool started = await showRewardedRecordingStartSheet(
      context: context,
      ref: ref,
      watchId: watch.id,
      entitlement: entitlement.local,
    );
    if (started && mounted) {
      context.push(AppRoutes.localRecording(watch.id));
    }
  }

  Future<void> _startLocalRecording(
    WatchSummary watch,
    Entitlement entitlement,
  ) async {
    if (!entitlement.local.enabled) return;
    if (!entitlement.local.unlimited &&
        entitlement.local.minutesRemaining <= 0) {
      await _startRewardedRecording(watch, entitlement);
      return;
    }
    final LocalRecordingController controller = ref.read(
      localRecordingControllerProvider,
    );
    if (controller.hasActiveSession) {
      if (entitlement.plan == Plan.pro || controller.hasSecondarySession) {
        SsToast.show(context, context.l10n.secondLocalSlotBusy);
        return;
      }
      final bool startSecond = await showSecondLocalSlotSheet(
        context: context,
        ref: ref,
        entitlement: entitlement.local,
        targetCreatorName: watch.creatorDisplayName,
      );
      if (!startSecond || !mounted) return;
      await controller.startSecond(watchId: watch.id);
      if (mounted) context.push(AppRoutes.localRecording(watch.id));
      return;
    }

    final LocalRecordingConfirmationController confirmation = ref.read(
      localRecordingConfirmationControllerProvider,
    );
    final bool shouldConfirm = await confirmation.shouldConfirm(
      force:
          !entitlement.local.unlimited &&
          entitlement.local.minutesRemaining <= 0,
    );
    if (!mounted) return;
    if (shouldConfirm) {
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
      await confirmation.markConfirmed();
      if (!mounted) return;
    }
    try {
      await controller.start(watchId: watch.id);
      if (mounted) context.push(AppRoutes.localRecording(watch.id));
    } on ApiException catch (error) {
      if (error.code == 'FREE_MINUTES_EXHAUSTED') {
        ref.invalidate(entitlementProvider);
        final Entitlement refreshed = await ref.read(
          entitlementProvider.future,
        );
        if (mounted) {
          await _startRewardedRecording(watch, refreshed);
        }
        return;
      }
      if (error.code == 'LOCAL_SLOT_BUSY') {
        if (mounted) {
          SsToast.show(context, context.l10n.secondLocalSlotBusy);
        }
        return;
      }
      rethrow;
    }
  }

  Future<void> _toggleNotify(WatchSummary watch, bool enabled) async {
    setState(() => _mutating.add(watch.id));
    try {
      await ref
          .read(watchControllerProvider)
          .setNotifyOnLive(watch.id, enabled: enabled);
      if (mounted) {
        SsToast.show(context, context.l10n.notificationSavedMessage);
      }
    } finally {
      if (mounted) setState(() => _mutating.remove(watch.id));
    }
  }

  Future<void> _toggleAutoRecord(WatchSummary watch, bool enabled) async {
    setState(() => _mutating.add(watch.id));
    try {
      await ref
          .read(watchControllerProvider)
          .setAutoRecord(watch.id, enabled: enabled);
    } finally {
      if (mounted) setState(() => _mutating.remove(watch.id));
    }
  }

  void _add(Entitlement entitlement, int count) {
    final int limit = entitlement.limits.maxWatches;
    if (count >= limit) {
      showWatchLimitSheet(context, count: count, limit: limit);
      return;
    }
    context.push(AppRoutes.addChannel);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<WatchSummary>> watches = ref.watch(watchListProvider);
    final AsyncValue<Entitlement> entitlement = ref.watch(entitlementProvider);
    final AsyncValue<List<RecordingSummary>> recordings = ref.watch(
      watchRecordingsProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.channelsTitle),
        actions: <Widget>[
          const NotificationActionButton(),
          IconButton(
            tooltip: context.l10n.addChannelAction,
            onPressed: watches.hasValue && entitlement.hasValue
                ? () => _add(
                    entitlement.requireValue,
                    watches.requireValue.length,
                  )
                : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(watches, entitlement, recordings)),
    );
  }

  Widget _buildBody(
    AsyncValue<List<WatchSummary>> watches,
    AsyncValue<Entitlement> entitlement,
    AsyncValue<List<RecordingSummary>> recordings,
  ) {
    if (watches.isLoading || entitlement.isLoading || recordings.isLoading) {
      return const _ChannelsSkeleton();
    }
    if (watches.hasError || entitlement.hasError || recordings.hasError) {
      final Object error =
          watches.error ?? entitlement.error ?? recordings.error!;
      return Center(
        child: SsAsyncErrorState(
          error: error,
          onRetry: () {
            ref.invalidate(watchListProvider);
            ref.invalidate(entitlementProvider);
            ref.invalidate(watchRecordingsProvider);
          },
        ),
      );
    }

    final List<WatchSummary> all = watches.requireValue;
    final Entitlement access = entitlement.requireValue;
    final List<RecordingSummary> recs = recordings.requireValue;
    final bool online = ref.watch(appOnlineProvider).value ?? true;
    if (all.isEmpty) {
      return _EmptyChannels(onAdd: () => _add(access, 0));
    }

    final List<WatchSummary> filtered = all
        .where(
          (WatchSummary item) => switch (_filter) {
            _WatchFilter.all => true,
            _WatchFilter.live => item.isLive,
            _WatchFilter.offline =>
              !item.isLive && item.status == WatchStatus.active,
          },
        )
        .toList(growable: false);
    final int liveCount = all.where((WatchSummary item) => item.isLive).length;
    final int offlineCount = all
        .where(
          (WatchSummary item) =>
              !item.isLive && item.status == WatchStatus.active,
        )
        .length;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(watchListProvider);
        ref.invalidate(entitlementProvider);
        ref.invalidate(watchRecordingsProvider);
        await ref.read(watchListProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          SsSpacing.lg,
          SsSpacing.md,
          SsSpacing.lg,
          SsSpacing.xxl,
        ),
        children: <Widget>[
          _WatchingHeader(
            entitlement: access,
            count: all.length,
            liveCount: liveCount,
            offlineCount: offlineCount,
            filter: _filter,
            onFilter: (_WatchFilter value) => setState(() => _filter = value),
          ),
          if (filtered.isEmpty) ...<Widget>[
            const SizedBox(height: SsSpacing.xl),
            SsEmptyState(
              icon: Icons.filter_alt_off_rounded,
              title: context.l10n.emptyChannelsTitle,
              message: context.l10n.emptyChannelsBody,
            ),
          ] else
            for (final WatchSummary watch in filtered) ...<Widget>[
              const SizedBox(height: SsSpacing.md),
              _WatchTile(
                watch: watch,
                recording: _recordingForWatch(recs, watch.id),
                entitlement: access,
                mutating: _mutating.contains(watch.id),
                onNotify: (bool enabled) => _toggleNotify(watch, enabled),
                onAutoRecord: (bool enabled) =>
                    _toggleAutoRecord(watch, enabled),
                onRecord: watch.isLive
                    ? () => _startRecording(watch, access)
                    : null,
              ),
            ],
          if (all.length < access.limits.maxWatches) ...<Widget>[
            const SizedBox(height: SsSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _add(access, all.length),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(
                  '${context.l10n.addChannelAction} · '
                  '${context.l10n.watchCapacityRemaining(access.limits.maxWatches - all.length)}',
                ),
              ),
            ),
          ],
          if (access.plan == Plan.free &&
              online &&
              MediaQuery.textScalerOf(context).scale(1) < 1.8) ...<Widget>[
            ref.watch(adsServiceProvider).bannerFor(AdPlacement.watchList) ??
                const SizedBox.shrink(),
          ],
        ],
      ),
    );
  }
}

class _WatchingHeader extends StatelessWidget {
  const _WatchingHeader({
    required this.entitlement,
    required this.count,
    required this.liveCount,
    required this.offlineCount,
    required this.filter,
    required this.onFilter,
  });

  final Entitlement entitlement;
  final int count;
  final int liveCount;
  final int offlineCount;
  final _WatchFilter filter;
  final ValueChanged<_WatchFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final int limit = entitlement.limits.maxWatches;
    final int remaining = (limit - count).clamp(0, limit).toInt();
    final bool overLegacyLimit = count > limit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.watchingHeader(
            count,
            limit,
            entitlement.plan == Plan.pro
                ? l10n.proPlanLabel
                : l10n.freePlanLabel,
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: SsSpacing.xs),
        Text(
          overLegacyLimit
              ? l10n.watchCapacityLegacyExceeded(count)
              : remaining > 0
              ? l10n.watchCapacityRemaining(remaining)
              : l10n.watchCapacityFull,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (overLegacyLimit) ...<Widget>[
          const SizedBox(height: SsSpacing.md),
          SsInlineAlert(
            title: l10n.watchCapacityFull,
            message: l10n.watchCapacityLegacyExceeded(count),
            tone: SsInlineAlertTone.warning,
          ),
        ],
        const SizedBox(height: SsSpacing.md),
        SsFilterChips(
          items: <String>[
            '${l10n.watchFilterAll} · $count',
            '${l10n.watchFilterLive} · $liveCount',
            '${l10n.watchFilterOffline} · $offlineCount',
          ],
          selectedIndex: filter.index,
          onSelected: (int index) => onFilter(_WatchFilter.values[index]),
        ),
        const SizedBox(height: SsSpacing.sm),
        _WatchCapacityIndicator(count: count, limit: limit),
      ],
    );
  }
}

class _WatchCapacityIndicator extends StatelessWidget {
  const _WatchCapacityIndicator({required this.count, required this.limit});

  final int count;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final Color active = Theme.of(context).colorScheme.primary;
    final Color inactive = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest;
    if (limit > 5) {
      return LinearProgressIndicator(
        value: limit == 0 ? 0 : (count / limit).clamp(0, 1),
        minHeight: 4,
        borderRadius: BorderRadius.circular(999),
      );
    }
    return Row(
      children: <Widget>[
        for (int index = 0; index < limit; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: SsSpacing.xs),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: index < count ? active : inactive,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WatchTile extends StatelessWidget {
  const _WatchTile({
    required this.watch,
    required this.recording,
    required this.entitlement,
    required this.mutating,
    required this.onNotify,
    required this.onAutoRecord,
    required this.onRecord,
  });

  final WatchSummary watch;
  final RecordingSummary? recording;
  final Entitlement entitlement;
  final bool mutating;
  final ValueChanged<bool> onNotify;
  final ValueChanged<bool> onAutoRecord;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool pro = entitlement.plan == Plan.pro;
    final bool cloudExhausted = pro && entitlement.cloudMinutesAvailable <= 0;
    final bool pausedNoCloudMinutes =
        watch.autoRecordState == AutoRecordState.pausedNoCloudMinutes ||
        cloudExhausted;
    final RecordingStatus? recordingStatus = recording?.status;

    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: () => context.push(AppRoutes.channelDetail(watch.id)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SsAvatar(
                  label: watch.creatorDisplayName,
                  imageUrl: watch.creatorAvatarUrl,
                  radius: 24,
                  isLive: watch.isLive,
                ),
                const SizedBox(width: SsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        watch.creatorDisplayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(watch.creatorUsername),
                      const SizedBox(height: SsSpacing.sm),
                      Wrap(
                        spacing: SsSpacing.sm,
                        runSpacing: SsSpacing.sm,
                        children: <Widget>[
                          _liveChip(context, watch),
                          if (recordingStatus ==
                              RecordingStatus.waitingForCloudSlot)
                            SsStatusChip(
                              label: l10n.watchWaitingCloudSlot,
                              icon: Icons.hourglass_top_rounded,
                              tone: SsStatusTone.warning,
                            ),
                          if (recordingStatus ==
                              RecordingStatus.missedNoCloudSlot)
                            SsStatusChip(
                              label: l10n.watchMissedNoCloudSlot,
                              icon: Icons.event_busy_rounded,
                              tone: SsStatusTone.warning,
                            ),
                          if (pausedNoCloudMinutes)
                            SsStatusChip(
                              label: l10n.autoRecordPausedNoCloudHoursLabel,
                              icon: Icons.pause_circle_outline_rounded,
                              tone: SsStatusTone.warning,
                            )
                          else if (watch.status == WatchStatus.paused)
                            SsStatusChip(
                              label: l10n.watchPausedStatus,
                              icon: Icons.pause_rounded,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          if (!watch.isLive && watch.nextCheckAt != null) ...<Widget>[
            const SizedBox(height: SsSpacing.sm),
            Text(
              l10n.watchNextCheckAt(
                MaterialLocalizations.of(context).formatTimeOfDay(
                  TimeOfDay.fromDateTime(watch.nextCheckAt!.toLocal()),
                ),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (watch.isLive) ...<Widget>[
            const SizedBox(height: SsSpacing.md),
            SsPrimaryButton(
              label: l10n.recordNowAction,
              icon: Icons.radio_button_checked_rounded,
              onPressed: mutating ? null : onRecord,
            ),
          ],
          const Divider(height: SsSpacing.xl),
          Semantics(
            label: l10n.watchNotifyOnLive,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: watch.notifyOnLive,
              title: Text(l10n.watchNotifyOnLive),
              secondary: const Icon(Icons.notifications_active_outlined),
              onChanged: mutating ? null : onNotify,
            ),
          ),
          if (pro) ...<Widget>[
            Semantics(
              label: l10n.watchAutoRecordCloud,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: watch.autoRecord,
                title: Text(l10n.watchAutoRecordCloud),
                subtitle: pausedNoCloudMinutes
                    ? Text(l10n.autoRecordPausedNoCloudHoursBody)
                    : null,
                secondary: const Icon(Icons.cloud_outlined),
                onChanged: mutating || pausedNoCloudMinutes
                    ? null
                    : onAutoRecord,
              ),
            ),
            if (pausedNoCloudMinutes)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.cloudHoursLocation('auto_record')),
                  icon: const Icon(Icons.add_card_rounded),
                  label: Text(l10n.buyMoreCloudHoursAction),
                ),
              ),
          ] else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline_rounded),
              title: Text(l10n.watchAutoRecordCloud),
              subtitle: Text(l10n.watchAutoRecordLocked),
              onTap: () => showCloudHoursUpsellSheet(context),
            ),
        ],
      ),
    );
  }

  Widget _liveChip(BuildContext context, WatchSummary watch) {
    final AppLocalizations l10n = context.l10n;
    if (watch.status == WatchStatus.paused ||
        watch.status == WatchStatus.disabled) {
      return SsStatusChip(label: l10n.watchPausedStatus);
    }
    if (watch.isLive) {
      return SsStatusChip(
        label: l10n.liveStatus,
        icon: Icons.fiber_manual_record_rounded,
        tone: SsStatusTone.recording,
      );
    }
    if (watch.lastCheckedAt == null) {
      return SsStatusChip(
        label: l10n.watchUnknownStatus,
        icon: Icons.help_outline_rounded,
      );
    }
    return SsStatusChip(
      label: l10n.offlineStatus,
      icon: Icons.cloud_off_outlined,
    );
  }
}

RecordingSummary? _recordingForWatch(
  List<RecordingSummary> recordings,
  String watchId,
) {
  for (final RecordingSummary item in recordings) {
    if (item.watchId == watchId &&
        (item.isActiveLifecycle ||
            item.status == RecordingStatus.missedNoCloudSlot)) {
      return item;
    }
  }
  return null;
}

class _EmptyChannels extends StatelessWidget {
  const _EmptyChannels({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SsSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SsEmptyState(
              title: context.l10n.homeEmptyCreatorTitle,
              message: context.l10n.addFirstCreatorBody,
              icon: Icons.person_add_alt_1_rounded,
            ),
            const SizedBox(height: SsSpacing.lg),
            SsPrimaryButton(
              label: context.l10n.addChannelAction,
              icon: Icons.add_rounded,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelsSkeleton extends StatelessWidget {
  const _ChannelsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(height: 132, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 44, radius: SsRadii.pill),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 260, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 260, radius: SsRadii.lg),
      ],
    );
  }
}
