import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/mock/mock_repository_base.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/watch_summary.dart';
import 'controllers/watch_providers.dart';
import 'watch_ui_helpers.dart';

class ChannelsScreen extends ConsumerWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<WatchSummary>> watches = ref.watch(watchListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.channelsTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.addChannelAction,
            onPressed: () => context.push(AppRoutes.addChannel),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: watches.when(
          loading: () => const _ChannelsSkeleton(),
          error: (Object error, StackTrace stackTrace) => Center(
            child: SsErrorState(
              title: _errorTitle(l10n, error),
              message: _errorMessage(l10n, error),
              retryLabel: l10n.retryAction,
              onRetry: () => ref.invalidate(watchListProvider),
            ),
          ),
          data: (List<WatchSummary> items) {
            if (items.isEmpty) {
              return _EmptyChannels(
                onAdd: () => context.push(AppRoutes.addChannel),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(watchListProvider);
                await ref.read(watchListProvider.future);
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  SsSpacing.lg,
                  SsSpacing.md,
                  SsSpacing.lg,
                  SsSpacing.xxl,
                ),
                itemCount: items.length + 1,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: SsSpacing.md),
                itemBuilder: (BuildContext context, int index) {
                  if (index == 0) {
                    return _ChannelsHeader(
                      count: items.length,
                      onAdd: () => context.push(AppRoutes.addChannel),
                    );
                  }
                  return _ChannelCard(watch: items[index - 1]);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChannelsHeader extends StatelessWidget {
  const _ChannelsHeader({required this.count, required this.onAdd});

  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.channelsSummaryTitle(count),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: SsSpacing.xs),
          Text(
            l10n.channelsSummaryBody,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: SsSpacing.lg),
          SsPrimaryButton(
            label: l10n.addChannelAction,
            icon: Icons.add_rounded,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.watch});

  final WatchSummary watch;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SsCard(
      child: InkWell(
        onTap: () => context.push(AppRoutes.channelDetail(watch.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SsSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SsAvatar(label: watch.creatorDisplayName, radius: 24),
                  const SizedBox(width: SsSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          watch.creatorDisplayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: SsSpacing.xs),
                        Text(
                          watch.creatorUsername,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: SsSpacing.md),
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
                  SsStatusChip(
                    label: watch.autoRecord
                        ? l10n.autoRecordOnLabel
                        : l10n.autoRecordOffLabel,
                    tone: watch.autoRecord
                        ? SsStatusTone.success
                        : SsStatusTone.neutral,
                    icon: Icons.video_settings_outlined,
                  ),
                ],
              ),
              const SizedBox(height: SsSpacing.md),
              Text(
                watchStatusReason(l10n, watch.status),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: SsSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TimestampLine(
                      icon: Icons.sync_rounded,
                      label: l10n.lastCheckedLabel,
                      value: watchTimestamp(context, watch.lastCheckedAt),
                    ),
                  ),
                  const SizedBox(width: SsSpacing.md),
                  Expanded(
                    child: _TimestampLine(
                      icon: Icons.podcasts_rounded,
                      label: l10n.lastLiveLabel,
                      value: watchTimestamp(context, watch.lastLiveAt),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimestampLine extends StatelessWidget {
  const _TimestampLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: SsSpacing.xs),
        Expanded(
          child: Text(
            label + ': ' + value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _EmptyChannels extends StatelessWidget {
  const _EmptyChannels({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SsSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SsEmptyState(
              title: l10n.emptyChannelsTitle,
              message: l10n.emptyChannelsBody,
              icon: Icons.rss_feed_rounded,
            ),
            const SizedBox(height: SsSpacing.lg),
            SsPrimaryButton(
              label: l10n.addChannelAction,
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
        SsSkeleton(height: 120, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 172, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 172, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 172, radius: SsRadii.lg),
      ],
    );
  }
}

String _errorTitle(AppLocalizations l10n, Object error) {
  if (_isOfflineLike(error)) {
    return l10n.offlineErrorTitle;
  }
  return l10n.errorTitle;
}

String _errorMessage(AppLocalizations l10n, Object error) {
  if (_isOfflineLike(error)) {
    return l10n.offlineErrorBody;
  }
  return l10n.errorBody;
}

bool _isOfflineLike(Object error) {
  return (error is MockRepositoryException &&
          error.kind == MockFailureKind.offlineLike) ||
      (error is ApiException &&
          (error.kind == ApiExceptionKind.network ||
              error.kind == ApiExceptionKind.timeout));
}
