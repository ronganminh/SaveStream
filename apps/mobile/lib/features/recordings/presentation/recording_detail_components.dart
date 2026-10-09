import 'package:flutter/material.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../domain/models/recording_summary.dart';
import 'recording_ui_helpers.dart';

class RecordingDetailHeading extends StatelessWidget {
  const RecordingDetailHeading({
    required this.name,
    required this.startedAt,
    required this.durationSeconds,
    required this.sizeBytes,
    required this.status,
    required this.engine,
    this.downloaded = false,
    super.key,
  });

  final String name;
  final DateTime? startedAt;
  final int durationSeconds;
  final int sizeBytes;
  final RecordingStatus status;
  final Engine engine;
  final bool downloaded;

  @override
  Widget build(BuildContext context) {
    final Color onVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: SsSpacing.xs),
        Text(
          <String>[
            recordingTimestamp(context, startedAt),
            formatDuration(durationSeconds),
            formatBytes(sizeBytes),
          ].join(' · '),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: onVariant),
        ),
        const SizedBox(height: SsSpacing.sm),
        Wrap(
          spacing: SsSpacing.xs,
          runSpacing: SsSpacing.xs,
          children: <Widget>[
            SsStatusChip(
              label: recordingStatusLabel(context.l10n, status),
              tone: recordingStatusTone(status),
              icon: _statusIcon(status),
            ),
            SsStatusChip(
              label: engine == Engine.local
                  ? context.l10n.localLabel
                  : context.l10n.cloudLabel,
              tone: engine == Engine.local
                  ? SsStatusTone.local
                  : SsStatusTone.cloud,
              icon: engine == Engine.local
                  ? Icons.smartphone_rounded
                  : Icons.cloud_rounded,
            ),
            if (downloaded)
              SsStatusChip(
                label: context.l10n.recordingDownloadedChip,
                tone: SsStatusTone.local,
                icon: Icons.download_done_rounded,
              ),
          ],
        ),
      ],
    );
  }
}

class RecordingDetailInfoRow {
  const RecordingDetailInfoRow(
    this.label,
    this.value, {
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;
}

class RecordingDetailInfoCard extends StatelessWidget {
  const RecordingDetailInfoCard({required this.rows, super.key});

  final List<RecordingDetailInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SsCard(
      padding: const EdgeInsets.symmetric(
        horizontal: SsSpacing.md,
        vertical: SsSpacing.sm,
      ),
      child: Column(
        children: <Widget>[
          for (int index = 0; index < rows.length; index++) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: SsSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      rows[index].label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: SsSpacing.md),
                  Flexible(
                    child: Text(
                      rows[index].value,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: rows[index].emphasize
                            ? FontWeight.w700
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RecordingDetailActions extends StatelessWidget {
  const RecordingDetailActions({required this.actions, super.key});

  final List<RecordingDetailActionData> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int index = 0; index < actions.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: SsSpacing.sm),
            Expanded(child: _RecordingDetailAction(data: actions[index])),
          ],
        ],
      ),
    );
  }
}

class RecordingDetailActionData {
  const RecordingDetailActionData({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool loading;
}

class _RecordingDetailAction extends StatelessWidget {
  const _RecordingDetailAction({required this.data});

  final RecordingDetailActionData data;

  @override
  Widget build(BuildContext context) {
    final Color foreground = data.destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return OutlinedButton(
      onPressed: data.loading ? null : data.onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(
          horizontal: SsSpacing.xs,
          vertical: SsSpacing.md,
        ),
      ),
      child: data.loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(data.icon, size: 20),
                const SizedBox(height: SsSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    data.label,
                    maxLines: 1,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

IconData _statusIcon(RecordingStatus status) {
  return switch (status) {
    RecordingStatus.completed => Icons.check_rounded,
    RecordingStatus.partial ||
    RecordingStatus.recovered => Icons.contrast_rounded,
    RecordingStatus.processing ||
    RecordingStatus.uploading ||
    RecordingStatus.finalizing => Icons.save_outlined,
    RecordingStatus.failed ||
    RecordingStatus.missedNoCloudSlot => Icons.error_outline_rounded,
    _ => Icons.schedule_rounded,
  };
}
