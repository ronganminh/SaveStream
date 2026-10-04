import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';
import 'controllers/recording_library_controller.dart';
import 'models/recording_library_item.dart';
import 'recording_ui_helpers.dart';

/// L01 — Unified local + cloud recording library.
class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  RecordingLibraryStorage? _storage;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<RecordingLibraryItem>> library = ref.watch(
      recordingLibraryProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.recordingsTitle)),
      body: SafeArea(
        child: library.when(
          loading: () => const _RecordingsSkeleton(),
          error: (Object error, StackTrace stackTrace) => Center(
            child: SsAsyncErrorState(
              error: error,
              onRetry: () => ref.invalidate(recordingLibraryProvider),
            ),
          ),
          data: (List<RecordingLibraryItem> items) {
            final String normalized = _query.trim().toLowerCase();
            final List<RecordingLibraryItem> visible = items
                .where((RecordingLibraryItem item) {
                  final bool storageMatches =
                      _storage == null || item.storage == _storage;
                  final bool queryMatches =
                      normalized.isEmpty ||
                      item.creatorDisplayName.toLowerCase().contains(
                        normalized,
                      ) ||
                      item.creatorHandle.toLowerCase().contains(normalized);
                  return storageMatches && queryMatches;
                })
                .toList(growable: false);

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(recordingLibraryProvider);
                await ref.read(recordingLibraryProvider.future);
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
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: context.l10n.recordingSearchHint,
                    ),
                    onChanged: (String value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: SsSpacing.md),
                  Wrap(
                    spacing: SsSpacing.sm,
                    children: <Widget>[
                      ChoiceChip(
                        label: Text(context.l10n.recordingFilterAll),
                        selected: _storage == null,
                        onSelected: (_) => setState(() => _storage = null),
                      ),
                      ChoiceChip(
                        label: Text(context.l10n.localLabel),
                        selected: _storage == RecordingLibraryStorage.local,
                        onSelected: (_) => setState(
                          () => _storage = RecordingLibraryStorage.local,
                        ),
                      ),
                      ChoiceChip(
                        label: Text(context.l10n.cloudLabel),
                        selected: _storage == RecordingLibraryStorage.cloud,
                        onSelected: (_) => setState(
                          () => _storage = RecordingLibraryStorage.cloud,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SsSpacing.lg),
                  if (visible.isEmpty)
                    SsEmptyState(
                      icon: Icons.video_library_outlined,
                      title: context.l10n.emptyRecordingsTitle,
                      message: context.l10n.emptyRecordingsBody,
                    )
                  else
                    for (final RecordingLibraryItem item
                        in visible) ...<Widget>[
                      _LibraryCard(item: item),
                      const SizedBox(height: SsSpacing.md),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.item});

  final RecordingLibraryItem item;

  @override
  Widget build(BuildContext context) {
    final bool local = item.storage == RecordingLibraryStorage.local;
    final String route = local
        ? AppRoutes.localRecordingDetail(item.id)
        : AppRoutes.recordingDetail(item.id);

    return SsCard(
      child: InkWell(
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SsSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.creatorDisplayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SsLocationChip(
                    engine: local ? Engine.local : Engine.cloud,
                    label: local
                        ? context.l10n.localLabel
                        : context.l10n.cloudLabel,
                  ),
                ],
              ),
              const SizedBox(height: SsSpacing.xs),
              Text(item.creatorHandle),
              const SizedBox(height: SsSpacing.sm),
              SsStatusChip(
                label: recordingStatusLabel(context.l10n, item.status),
                tone: recordingStatusTone(item.status),
              ),
              if (item.isCrossDevice) ...<Widget>[
                const SizedBox(height: SsSpacing.sm),
                Text(
                  context.l10n.recordingCrossDeviceValue(item.deviceName ?? ''),
                ),
                Text(context.l10n.recordingCrossDeviceUnavailable),
              ],
              if (item.issue ==
                  RecordingLibraryIssue.missedNoCloudSlot) ...<Widget>[
                const SizedBox(height: SsSpacing.sm),
                Text(context.l10n.recordingMissedNoCloudSlotBody),
              ],
              const SizedBox(height: SsSpacing.sm),
              Text(
                '${formatDuration(item.durationSeconds)} · ${formatBytes(item.sizeBytes)}',
              ),
            ],
          ),
        ),
      ),
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
        SsSkeleton(height: 56, radius: SsRadii.md),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 40, radius: SsRadii.md),
        SizedBox(height: SsSpacing.lg),
        SsSkeleton(height: 180, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 180, radius: SsRadii.lg),
      ],
    );
  }
}
