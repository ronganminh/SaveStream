import 'package:flutter/material.dart';

import '../core/enums.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../theme/ss_theme.dart';
import 'ss_avatar.dart';
import 'ss_badges.dart';

class SsRecordingTile extends StatelessWidget {
  const SsRecordingTile({super.key, required this.recording, this.onTap, this.showDivider = true});
  final Recording recording;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final r = recording;
    final meta = [fmtTime(r.startedAt), fmtDuration(r.duration), if (r.sizeBytes != null) fmtBytes(r.sizeBytes!)].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: SsSpace.screenH, vertical: SsSpace.md),
        decoration: BoxDecoration(border: showDivider ? Border(bottom: BorderSide(color: cs.outline)) : null),
        child: Row(children: [
          SsCreatorAvatar(initials: r.creator.initials, imageUrl: r.creator.avatarUrl),
          const SizedBox(width: SsSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.creator.name, style: context.tt.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(r.title, style: context.tt.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(meta, style: context.ssType.mono.copyWith(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: SsSpace.xs),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (r.copies == CopyLocation.both) ...[
                  const SsLocationChip(engine: Engine.local),
                  const SsLocationChip(engine: Engine.cloud),
                ] else
                  SsLocationChip(engine: r.engine),
                if (r.status != RecordingStatus.completed) SsStatusPill(status: r.status),
              ]),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        ]),
      ),
    );
  }
}
