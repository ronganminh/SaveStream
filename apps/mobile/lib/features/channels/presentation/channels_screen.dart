import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../recordings/domain/models/recording_summary.dart';
import '../../recordings/presentation/controllers/recording_providers.dart';
import '../domain/models/channel_detail_view_model.dart';
import '../domain/models/watch_summary.dart';
import 'controllers/watch_providers.dart';
import 'watch_ui_helpers.dart';

class ChannelDetailScreen extends ConsumerStatefulWidget {
  const ChannelDetailScreen({required this.watchId, super.key});

  final String watchId;

  @override
  ConsumerState<ChannelDetailScreen> createState() =>
      _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends ConsumerState<ChannelDetailScreen> {
  bool _isMutating = false;
  Object? _mutationError;

  Future<void> _runMutation(Future<void> Function() action) async {
    setState(() {
      _isMutating = true;
      _mutationError = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _mutationError = error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  Future<void> _recordNow(WatchSummary watch) async {
    RecordingSummary? created;
    await _runMutation(() async {
      created = await ref
          .read(recordingControllerProvider)
          .create(
            CreateRecordingCommand(
              sourceType: _recordingSourceType(watch.sourceType),
              sourceValue:
                  watch.sourceValue ??
                  watch.creatorUsername.replaceFirst('@', ''),
            ),
          );
    });
    if (_mutationError == null && created != null && mounted) {
      context.push(AppRoutes.recordingDetail(created!.id));
    }
  }

  Future<void> _deleteWatch(WatchSummary watch) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await SsConfirmDialog.show(
      context,
      title: l10n.deleteChannelTitle,
      message: l10n.deleteChannelMessage(watch.creatorDisplayName),
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteChannelAction,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await _runMutation(
      () => ref.read(watchControllerProvider).delete(watch.id),
    );
    if (_mutationError == null && mounted) {
      context.go(AppRoutes.channels);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<ChannelDetailViewModel?> detail = ref.watch(
      channelDetailProvider(widget.watchId),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.channelDetailTitle)),
      body: SafeArea(
        child: SsAsyncRefreshFrame(
          isRefreshing: detail.isRefreshing,
          child: detail.when(
            loading: () => const _ChannelDetailSkeleton(),
            error: (Object error, StackTrace stackTrace) => Center(
              child: SsAsyncErrorState(
                error: error,
                onRetry: () =>
                    ref.invalidate(channelDetailProvider(widget.watchId)),
              ),
            ),
            data: (ChannelDetailViewModel? value) {
              if (value == null) {
                return Center(
                  child: SsEmptyState(
                    title: l10n.channelNotFoundTitle,
                    message: l10n.channelNotFoundBody,
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(channelDetailProvider(widget.watchId));
                  await ref.read(channelDetailProvider(widget.watchId).future);
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
                    _CreatorCard(watch: value.watch),
                    if (_mutationError != null) ...<Widget>[
                      const SizedBox(height: SsSpacing.md),
                      SsInlineAsyncError(
                        error: _mutationError!,
                        messageOverride: _channelMutationMessage(
                          l10n,
                          _mutationError!,
                        ),
                      ),
                    ],
                    const SizedBox(height: SsSpacing.lg),
                    _MonitoringCard(
                      watch: value.watch,
                      isMutating: _isMutating,
                      onRecordNow: () => _recordNow(value.watch),
                      onAutoRecordChanged: (bool enabled) {
                        _runMutation(
                          () => ref
                              .read(watchControllerProvider)
                              .setAutoRecord(value.watch.id, enabled: enabled),
                        );
                      },
                      onPauseResume: () {
                        if (value.watch.status == WatchStatus.active) {
                          _runMutation(
                            () => ref
                                .read(watchControllerProvider)
                                .pause(value.watch.id),
                          );
                        } else {
                          _runMutation(
                            () => ref
                                .read(watchControllerProvider)
                                .resume(value.watch.id),
                          );
                        }
                      },
                      onDelete: () => _deleteWatch(value.watch),
                    ),
                    const SizedBox(height: SsSpacing.xl),
                    _RecordingHistory(recordings: value.recordings),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CreatorCard extends StatelessWidget {
  const _CreatorCard({required this.watch});

  final WatchSummary watch;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
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
                    const SizedBox(height: SsSpacing.xs),
                    Text(
                      watch.creatorUsername,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SsSpacing.lg),
          Wrap(
            spacing: SsSpacing.sm,
            runSpacing: SsSpacing.sm,
            children: <Widget>[
              SsStatusChip(
                label: watch.isLive ? l10n.liveStatus : l10n.offlineStatus,
                tone: watch.isLive
                    ? SsStatusTone.recording
                    : SsStatusTone.neutral,
                icon: watch.isLive
                    ? Icons.fiber_manual_record_rounded
                    : Icons.cloud_off_outlined,
              ),
              SsStatusChip(
                label: watchStatusLabel(l10n, watch.status),
                tone: watchStatusTone(watch.status),
              ),
            ],
          ),
          const SizedBox(height: SsSpacing.md),
          Text(
            watchStatusReason(l10n, watch.status),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: SsSpacing.lg),
          _DetailLine(
            label: l10n.lastCheckedLabel,
            value: watchTimestamp(context, watch.lastCheckedAt),
          ),
          const SizedBox(height: SsSpacing.sm),
          _DetailLine(
            label: l10n.lastLiveLabel,
            value: watchTimestamp(context, watch.lastLiveAt),
          ),
        ],
      ),
    );
  }
}

class _MonitoringCard extends StatelessWidget {
  const _MonitoringCard({
    required this.watch,
    required this.isMutating,
    required this.onRecordNow,
    required this.onAutoRecordChanged,
    required this.onPauseResume,
    required this.onDelete,
  });

  final WatchSummary watch;
  final bool isMutating;
  final VoidCallback onRecordNow;
  final ValueChanged<bool> onAutoRecordChanged;
  final VoidCallback onPauseResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.monitoringSettingsTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: watch.autoRecord,
            title: Text(l10n.autoRecordTitle),
            subtitle: Text(l10n.autoRecordDescription),
            onChanged: isMutating ? null : onAutoRecordChanged,
          ),
          const Divider(),
          const SizedBox(height: SsSpacing.sm),
          SsPrimaryButton(
            label: l10n.recordNowAction,
            icon: Icons.fiber_manual_record_rounded,
            onPressed: isMutating ? null : onRecordNow,
          ),
          const SizedBox(height: SsSpacing.sm),
          SsSecondaryButton(
            label: watch.status == WatchStatus.active
                ? l10n.pauseMonitoringAction
                : l10n.resumeMonitoringAction,
            icon: watch.status == WatchStatus.active
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            onPressed: isMutating ? null : onPauseResume,
          ),
          const SizedBox(height: SsSpacing.sm),
          TextButton.icon(
            onPressed: isMutating ? null : onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            label: Text(
              l10n.deleteChannelAction,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingHistory extends StatelessWidget {
  const _RecordingHistory({required this.recordings});

  final List<RecordingSummary> recordings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    if (recordings.isEmpty) {
      return SsCard(
        child: SsEmptyState(
          title: l10n.channelNoRecordingsTitle,
          message: l10n.channelNoRecordingsBody,
          icon: Icons.video_library_outlined,
        ),
      );
    }

    final RecordingSummary latest = recordings.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.latestRecordingTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: SsSpacing.md),
        _RecordingTile(recording: latest),
        const SizedBox(height: SsSpacing.xl),
        Text(
          l10n.recordingHistoryTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: SsSpacing.md),
        ...recordings.map(
          (RecordingSummary recording) => Padding(
            padding: const EdgeInsets.only(bottom: SsSpacing.md),
            child: _RecordingTile(recording: recording),
          ),
        ),
      ],
    );
  }
}

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({required this.recording});

  final RecordingSummary recording;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return SsCard(
      child: SsListTile(
        title: recording.creatorDisplayName,
        subtitle: recording.id,
        leading: const Icon(Icons.video_library_outlined),
        trailing: SsStatusChip(
          label: _recordingStatusLabel(l10n, recording.status),
          tone: _recordingStatusTone(recording.status),
        ),
        onTap: () => context.push(AppRoutes.recordingDetail(recording.id)),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: SsSpacing.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _ChannelDetailSkeleton extends StatelessWidget {
  const _ChannelDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(height: 220, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 210, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.xl),
        SsSkeleton(width: 180, height: 24),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 88, radius: SsRadii.lg),
      ],
    );
  }
}

String _recordingStatusLabel(AppLocalizations l10n, RecordingStatus status) {
  return switch (status) {
    RecordingStatus.queued => l10n.recordingStatusQueued,
    RecordingStatus.resolving => l10n.recordingStatusResolving,
    RecordingStatus.waitingLive => l10n.recordingStatusWaitingLive,
    RecordingStatus.recording => l10n.recordingStatusRecording,
    RecordingStatus.processing => l10n.recordingStatusProcessing,
    RecordingStatus.uploading => l10n.recordingStatusUploading,
    RecordingStatus.completed => l10n.recordingStatusCompleted,
    RecordingStatus.failed => l10n.recordingStatusFailed,
    RecordingStatus.stopRequested => l10n.recordingStatusStopRequested,
    RecordingStatus.stopped => l10n.recordingStatusStopped,
  };
}

SsStatusTone _recordingStatusTone(RecordingStatus status) {
  return switch (status) {
    RecordingStatus.recording => SsStatusTone.recording,
    RecordingStatus.completed => SsStatusTone.success,
    RecordingStatus.failed => SsStatusTone.error,
    RecordingStatus.stopRequested => SsStatusTone.warning,
    RecordingStatus.stopped => SsStatusTone.warning,
    RecordingStatus.queued ||
    RecordingStatus.resolving ||
    RecordingStatus.waitingLive ||
    RecordingStatus.processing ||
    RecordingStatus.uploading => SsStatusTone.neutral,
  };
}

String? _channelMutationMessage(AppLocalizations l10n, Object error) {
  if (error is ApiException &&
      error.kind == ApiExceptionKind.insufficientCredits) {
    return l10n.watchResumeInsufficientCreditMessage;
  }
  return null;
}

RecordingSourceType _recordingSourceType(WatchSourceType? type) {
  return switch (type) {
    WatchSourceType.roomId => RecordingSourceType.roomId,
    WatchSourceType.url => RecordingSourceType.url,
    WatchSourceType.username || null => RecordingSourceType.username,
  };
}
