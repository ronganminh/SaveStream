import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../channels/domain/models/watch_summary.dart';
import '../../recordings/domain/models/recording_summary.dart';
import '../domain/models/home_dashboard_view_model.dart';
import 'controllers/home_dashboard_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<HomeDashboardViewModel> dashboard = ref.watch(
      homeDashboardProvider,
    );

    final String? displayName = dashboard.value?.metrics.displayName;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SsLargeHeader(
              title: displayName == null
                  ? l10n.appTitle
                  : l10n.homeGreeting(displayName),
              subtitle: MaterialLocalizations.of(
                context,
              ).formatFullDate(DateTime.now()),
              actions: <Widget>[
                IconButton(
                  tooltip: l10n.notificationsTitle,
                  onPressed: () => context.push(AppRoutes.notifications),
                  icon: const Icon(Icons.notifications_outlined),
                ),
              ],
            ),
            Expanded(
              child: SsAsyncRefreshFrame(
                isRefreshing: dashboard.isRefreshing,
                child: dashboard.when(
                  loading: () => const _HomeSkeleton(),
                  error: (Object error, StackTrace stackTrace) => Center(
                    child: SsAsyncErrorState(
                      error: error,
                      onRetry: () => ref.invalidate(homeDashboardProvider),
                    ),
                  ),
                  data: (HomeDashboardViewModel data) => RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(homeDashboardProvider);
                      await ref.read(homeDashboardProvider.future);
                    },
                    child: _HomeDashboard(data: data),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({required this.data});

  final HomeDashboardViewModel data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            SsSpacing.lg,
            0,
            SsSpacing.lg,
            SsSpacing.xxl,
          ),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _MetricGrid(data: data),
                    const SizedBox(height: SsSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: SsPrimaryButton(
                        label: l10n.addChannelAction,
                        icon: Icons.add_rounded,
                        onPressed: () => context.push(AppRoutes.addChannel),
                      ),
                    ),
                    if (data.isEmptyAccount) ...<Widget>[
                      const SizedBox(height: SsSpacing.xl),
                      SsCard(
                        child: SsEmptyState(
                          icon: Icons.rss_feed_rounded,
                          title: l10n.homeEmptyTitle,
                          message: l10n.homeEmptyBody,
                        ),
                      ),
                    ] else ...<Widget>[
                      if (data.isLowCredit) ...<Widget>[
                        const SizedBox(height: SsSpacing.xl),
                        _HomeAlert(
                          icon: Icons.account_balance_wallet_outlined,
                          title: l10n.homeLowCreditTitle,
                          message: l10n.homeLowCreditBody,
                          tone: colors.tertiary,
                          actionLabel: l10n.homeViewCreditsAction,
                          onAction: () => context.push(AppRoutes.credits),
                        ),
                      ],
                      if (data.failedRecordings.isNotEmpty) ...<Widget>[
                        const SizedBox(height: SsSpacing.md),
                        _HomeAlert(
                          icon: Icons.error_outline_rounded,
                          title: l10n.homeRecordingFailedTitle,
                          message: l10n.homeRecordingFailedBody,
                          tone: colors.error,
                          actionLabel: l10n.homeReviewRecordingAction,
                          onAction: () => context.push(
                            AppRoutes.recordingDetail(
                              data.failedRecordings.first.id,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: SsSpacing.xl),
                      _UsageCard(data: data),
                      if (data.activeRecordings.isNotEmpty) ...<Widget>[
                        const SizedBox(height: SsSpacing.xl),
                        _ActiveRecordingCard(
                          recording: data.activeRecordings.first,
                        ),
                      ],
                      if (data.featuredWatches.isNotEmpty) ...<Widget>[
                        const SizedBox(height: SsSpacing.xl),
                        SsSectionHeader(
                          title: l10n.homeMonitoredChannelsTitle,
                          actionLabel: l10n.sectionExampleAction,
                          onAction: () => context.go(AppRoutes.channels),
                        ),
                        const SizedBox(height: SsSpacing.sm),
                        ...data.featuredWatches.map(
                          (WatchSummary watch) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: SsSpacing.md,
                            ),
                            child: _WatchCard(watch: watch),
                          ),
                        ),
                      ],
                      if (data.recentRecordings.isNotEmpty) ...<Widget>[
                        const SizedBox(height: SsSpacing.lg),
                        SsSectionHeader(
                          title: l10n.homeRecentRecordingsTitle,
                          actionLabel: l10n.sectionExampleAction,
                          onAction: () => context.go(AppRoutes.recordings),
                        ),
                        const SizedBox(height: SsSpacing.sm),
                        ...data.recentRecordings.map(
                          (RecordingSummary recording) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: SsSpacing.md,
                            ),
                            child: _RecordingCard(recording: recording),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.data});

  final HomeDashboardViewModel data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 560
            ? 3
            : constraints.maxWidth >= 320
            ? 2
            : 1;
        final double width =
            (constraints.maxWidth - (columns - 1) * SsSpacing.md) / columns;

        return Wrap(
          spacing: SsSpacing.md,
          runSpacing: SsSpacing.md,
          children: <Widget>[
            _MetricCard(
              width: width,
              icon: Icons.account_balance_wallet_outlined,
              label: l10n.homeAvailableCreditLabel,
              value: data.metrics.availableCredit.toString(),
            ),
            _MetricCard(
              width: width,
              icon: Icons.fiber_manual_record_rounded,
              label: l10n.homeActiveRecordingsLabel,
              value: data.activeRecordings.length.toString(),
            ),
            _MetricCard(
              width: width,
              icon: Icons.rss_feed_rounded,
              label: l10n.homeMonitoredChannelsLabel,
              value: data.monitoredChannelCount.toString(),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      child: SsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: colors.primary),
            const SizedBox(height: SsSpacing.md),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: SsSpacing.xs),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeAlert extends StatelessWidget {
  const _HomeAlert({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color tone;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SsCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: tone),
          const SizedBox(width: SsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: SsSpacing.xs),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: SsSpacing.sm),
                TextButton(onPressed: onAction, child: Text(actionLabel)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.data});

  final HomeDashboardViewModel data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stack =
                  constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.4;
              final Widget title = Text(
                l10n.homeUsageTitle,
                style: Theme.of(context).textTheme.titleMedium,
              );
              final Widget action = TextButton(
                onPressed: () => context.push(AppRoutes.credits),
                child: Text(l10n.homeViewUsageAction),
              );

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    title,
                    const SizedBox(height: SsSpacing.xs),
                    Align(alignment: Alignment.centerLeft, child: action),
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Expanded(child: title),
                  action,
                ],
              );
            },
          ),
          const SizedBox(height: SsSpacing.md),
          LinearProgressIndicator(value: data.usageProgress),
          const SizedBox(height: SsSpacing.sm),
          Text(
            l10n.homeUsageHours(
              data.metrics.recordingHoursUsed.toStringAsFixed(1),
              data.metrics.recordingHoursLimit.toStringAsFixed(0),
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ActiveRecordingCard extends StatelessWidget {
  const _ActiveRecordingCard({required this.recording});

  final RecordingSummary recording;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SsSectionHeader(title: l10n.homeActiveRecordingTitle),
        const SizedBox(height: SsSpacing.sm),
        SsCard(
          child: InkWell(
            onTap: () => context.push(AppRoutes.recordingDetail(recording.id)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: SsSpacing.xs),
              child: Row(
                children: <Widget>[
                  SsAvatar(label: recording.creatorDisplayName, radius: 24),
                  const SizedBox(width: SsSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          recording.creatorDisplayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: SsSpacing.xs),
                        Text(
                          l10n.homeCloudRecordingHint,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SsStatusChip(
                    label: 'REC',
                    tone: SsStatusTone.recording,
                    icon: Icons.fiber_manual_record_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WatchCard extends StatelessWidget {
  const _WatchCard({required this.watch});

  final WatchSummary watch;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return SsCard(
      child: SsListTile(
        title: watch.creatorDisplayName,
        subtitle: watch.creatorUsername,
        leading: SsAvatar(label: watch.creatorDisplayName),
        trailing: SsStatusChip(
          label: _watchStatusLabel(l10n, watch),
          tone: _watchStatusTone(watch.status),
          icon: watch.isLive ? Icons.fiber_manual_record_rounded : null,
        ),
        onTap: () => context.push(AppRoutes.channelDetail(watch.id)),
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({required this.recording});

  final RecordingSummary recording;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return SsCard(
      child: SsListTile(
        title: recording.creatorDisplayName,
        subtitle: recording.creatorUsername,
        leading: SsAvatar(label: recording.creatorDisplayName),
        trailing: SsStatusChip(
          label: _recordingStatusLabel(l10n, recording.status),
          tone: _recordingStatusTone(recording.status),
        ),
        onTap: () => context.push(AppRoutes.recordingDetail(recording.id)),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(width: 220, height: 30),
        SizedBox(height: SsSpacing.sm),
        SsSkeleton(width: 280),
        SizedBox(height: SsSpacing.xl),
        Row(
          children: <Widget>[
            Expanded(child: SsSkeleton(height: 112, radius: SsRadii.lg)),
            SizedBox(width: SsSpacing.md),
            Expanded(child: SsSkeleton(height: 112, radius: SsRadii.lg)),
          ],
        ),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 52, radius: SsRadii.md),
        SizedBox(height: SsSpacing.xl),
        SsSkeleton(height: 120, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.xl),
        SsSkeleton(width: 180, height: 22),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 82, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 82, radius: SsRadii.lg),
      ],
    );
  }
}

String _watchStatusLabel(AppLocalizations l10n, WatchSummary watch) {
  if (watch.isLive) {
    return l10n.liveStatus;
  }
  return switch (watch.status) {
    WatchStatus.active => l10n.watchStatusActive,
    WatchStatus.paused => l10n.watchStatusPaused,
    WatchStatus.pausedInsufficientCredit =>
      l10n.watchStatusPausedInsufficientCredit,
    WatchStatus.pausedError => l10n.watchStatusPausedError,
    WatchStatus.disabled => l10n.watchStatusDisabled,
  };
}

SsStatusTone _watchStatusTone(WatchStatus status) {
  return switch (status) {
    WatchStatus.active => SsStatusTone.success,
    WatchStatus.paused => SsStatusTone.warning,
    WatchStatus.pausedInsufficientCredit => SsStatusTone.warning,
    WatchStatus.pausedError => SsStatusTone.error,
    WatchStatus.disabled => SsStatusTone.neutral,
  };
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
