import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/recording_summary.dart';
import 'controllers/recording_providers.dart';
import 'recordings_screen.dart';

class RecordingDetailScreen extends ConsumerWidget {
  const RecordingDetailScreen({required this.recordingId, super.key});

  final String recordingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<RecordingSummary?> recording = ref.watch(
      recordingDetailProvider(recordingId),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recordingDetailTitle)),
      body: SafeArea(
        child: recording.when(
          loading: () => Center(child: SsLoadingView(label: l10n.loadingLabel)),
          error: (_, _) => SsErrorState(
            title: l10n.errorTitle,
            message: l10n.errorBody,
            retryLabel: l10n.retryAction,
            onRetry: () =>
                ref.invalidate(recordingDetailProvider(recordingId)),
          ),
          data: (RecordingSummary? value) {
            if (value == null) {
              return SsEmptyState(
                title: l10n.recordingNotFoundTitle,
                message: l10n.recordingNotFoundBody,
              );
            }

            return ListView(
              padding: const EdgeInsets.all(SsSpacing.lg),
              children: <Widget>[
                SsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        value.creatorDisplayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: SsSpacing.xs),
                      Text(value.creatorUsername),
                      const SizedBox(height: SsSpacing.xl),
                      SsStatusChip(
                        label: recordingStatusLabel(l10n, value.status),
                        tone: recordingStatusTone(value.status),
                      ),
                      const SizedBox(height: SsSpacing.xl),
                      _ActionRow(
                        label: l10n.canStopLabel,
                        enabled: value.actions.canStop,
                      ),
                      _ActionRow(
                        label: l10n.canRetryLabel,
                        enabled: value.actions.canRetry,
                      ),
                      _ActionRow(
                        label: l10n.canDeleteLabel,
                        enabled: value.actions.canDelete,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SsSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(enabled ? context.l10n.yesLabel : context.l10n.noLabel),
        ],
      ),
    );
  }
}
