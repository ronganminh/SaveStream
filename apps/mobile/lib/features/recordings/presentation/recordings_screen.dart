import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/recording_summary.dart';
import 'controllers/recording_providers.dart';
import 'recording_ui_helpers.dart';

class RecordingsScreen extends ConsumerWidget {
  const RecordingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<RecordingListState> recordings = ref.watch(
      recordingListControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recordingsTitle)),
      body: SafeArea(
        child: recordings.when(
          loading: () => const _RecordingsSkeleton(),
          error: (Object error, StackTrace stackTrace) => Center(
            child: SsAsyncErrorState(
              error: error,
              onRetry: () =>
                  ref.read(recordingListControllerProvider.notifier).refresh(),
            ),
          ),
          data: (RecordingListState state) => _RecordingListBody(state: state),
        ),
      ),
    );
  }
}

class _RecordingListBody extends ConsumerWidget {
  const _RecordingListBody({required this.state});

  final RecordingListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;

    return Column(
      children: <Widget>[
        if (state.isRefreshing)
          Semantics(
            label: l10n.refreshingLabel,
            child: const LinearProgressIndicator(minHeight: 2),
          ),
        if (state.refreshError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SsSpacing.lg,
              SsSpacing.sm,
              SsSpacing.lg,
              0,
            ),
            child: SsInlineAsyncError(
              error: state.refreshError!,
              onRetry: () =>
                  ref.read(recordingListControllerProvider.notifier).refresh(),
            ),
          ),
        SizedBox(
          height: 58,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              SsSpacing.lg,
              SsSpacing.sm,
              SsSpacing.lg,
              SsSpacing.sm,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: RecordingFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: SsSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final RecordingFilter filter = RecordingFilter.values[index];
              return ChoiceChip(
                selected: state.filter == filter,
                label: Text(recordingFilterLabel(l10n, filter)),
                onSelected: (_) => ref
                    .read(recordingListControllerProvider.notifier)
                    .setFilter(filter),
              );
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(recordingListControllerProvider.notifier).refresh(),
            child: state.items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(SsSpacing.xl),
                    children: <Widget>[
                      const SizedBox(height: 120),
                      SsEmptyState(
                        icon: Icons.video_library_outlined,
                        title: l10n.emptyRecordingsTitle,
                        message: _emptyMessage(l10n, state.filter),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      SsSpacing.lg,
                      SsSpacing.sm,
                      SsSpacing.lg,
                      SsSpacing.xxl,
                    ),
                    itemCount: state.items.length + 1,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: SsSpacing.md),
                    itemBuilder: (BuildContext context, int index) {
                      if (index == state.items.length) {
                        return _LoadMoreSection(state: state);
                      }
                      return _RecordingCard(recording: state.items[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({required this.recording});

  final RecordingSummary recording;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SsCard(
      child: InkWell(
        onTap: () => context.push(AppRoutes.recordingDetail(recording.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SsSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          recording.creatorUsername,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SsSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: SsStatusChip(
                  label: recordingStatusLabel(l10n, recording.status),
                  tone: recordingStatusTone(recording.status),
                  icon: recording.status == RecordingStatus.recording
                      ? Icons.fiber_manual_record_rounded
                      : null,
                ),
              ),
              const SizedBox(height: SsSpacing.md),
              Text(
                recordingStatusDescription(l10n, recording.status),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: SsSpacing.md),
              Wrap(
                spacing: SsSpacing.lg,
                runSpacing: SsSpacing.sm,
                children: <Widget>[
                  _CardMeta(
                    label: l10n.recordingStartedLabel,
                    value: recordingTimestamp(context, recording.startedAt),
                  ),
                  _CardMeta(
                    label: l10n.recordingDurationLabel,
                    value: formatDuration(recording.durationSeconds),
                  ),
                  _CardMeta(
                    label: l10n.recordingSizeLabel,
                    value: formatBytes(
                      recording.sizeBytes ?? recording.bytesRecorded,
                    ),
                  ),
                  _CardMeta(
                    label: l10n.recordingCostLabel,
                    value: formatCredits(recording.costCredits),
                  ),
                ],
              ),
              const SizedBox(height: SsSpacing.md),
              Wrap(
                spacing: SsSpacing.sm,
                runSpacing: SsSpacing.sm,
                children: <Widget>[
                  SsStatusChip(
                    label: recording.artifactReady
                        ? l10n.artifactReadyLabel
                        : l10n.artifactPendingLabel,
                    tone: recording.artifactReady
                        ? SsStatusTone.success
                        : SsStatusTone.neutral,
                    icon: Icons.inventory_2_outlined,
                  ),
                  SsStatusChip(
                    label: recording.thumbnailReady
                        ? l10n.thumbnailReadyLabel
                        : l10n.thumbnailPendingLabel,
                    tone: recording.thumbnailReady
                        ? SsStatusTone.success
                        : SsStatusTone.neutral,
                    icon: Icons.image_outlined,
                  ),
                ],
              ),
              if (recording.progress != null &&
                  recording.status != RecordingStatus.completed) ...<Widget>[
                const SizedBox(height: SsSpacing.md),
                LinearProgressIndicator(value: recording.progress),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CardMeta extends StatelessWidget {
  const _CardMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 145,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _LoadMoreSection extends ConsumerWidget {
  const _LoadMoreSection({required this.state});

  final RecordingListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;

    if (state.nextCursor == null && state.loadMoreError == null) {
      return Padding(
        padding: const EdgeInsets.only(top: SsSpacing.sm),
        child: Center(
          child: Text(
            l10n.recordingEndOfListLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(SsSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: SsSpacing.sm),
        child: SsInlineAsyncError(
          error: state.loadMoreError!,
          messageOverride: l10n.recordingLoadMoreFailed,
          onRetry: () =>
              ref.read(recordingListControllerProvider.notifier).loadMore(),
        ),
      );
    }

    return TextButton.icon(
      onPressed: () =>
          ref.read(recordingListControllerProvider.notifier).loadMore(),
      icon: const Icon(Icons.expand_more_rounded),
      label: Text(l10n.loadMoreAction),
    );
  }
}

class _RecordingsSkeleton extends StatelessWidget {
  const _RecordingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(width: 260, height: 36, radius: SsRadii.md),
        SizedBox(height: SsSpacing.lg),
        SsSkeleton(height: 220, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 220, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 220, radius: SsRadii.lg),
      ],
    );
  }
}

String _emptyMessage(AppLocalizations l10n, RecordingFilter filter) {
  return switch (filter) {
    RecordingFilter.all => l10n.emptyRecordingsBody,
    RecordingFilter.active => l10n.emptyActiveRecordingsBody,
    RecordingFilter.completed => l10n.emptyCompletedRecordingsBody,
    RecordingFilter.failed => l10n.emptyFailedRecordingsBody,
  };
}
