import 'package:flutter/material.dart';

import '../core/enums.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../theme/ss_theme.dart';
import 'ss_avatar.dart';
import 'ss_badges.dart';
import 'ss_button.dart';

class SsActiveRecordingCard extends StatelessWidget {
  const SsActiveRecordingCard({super.key, required this.recording, required this.onStop, this.onOpen, this.onExtend});
  final ActiveRecording recording;
  final VoidCallback onStop;
  final VoidCallback? onOpen, onExtend;

  @override
  Widget build(BuildContext context) {
    final ss = context.ss;
    final r = recording;
    final scale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5); // timer cap 1.5×
    return Material(
      color: ss.player,
      borderRadius: BorderRadius.circular(SsRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(SsSpace.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SsCreatorAvatar(initials: r.creator.initials, size: SsAvatarSize.s32, isLive: true),
              const SizedBox(width: SsSpace.sm),
              Expanded(
                child: Text(r.creator.name,
                    style: context.tt.titleSmall!.copyWith(color: ss.onPlayer), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              SsLocationChip(engine: r.engine),
            ]),
            const SizedBox(height: SsSpace.md),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              SsStatusPill(status: r.status),
              const SizedBox(width: SsSpace.md),
              Expanded(
                child: Semantics(
                  label: 'Thời gian đã record',
                  value: fmtDuration(r.elapsed),
                  child: Text(fmtDuration(r.elapsed),
                      textScaler: scale, style: context.ssType.timer.copyWith(color: ss.onPlayer, fontSize: 32, height: 40 / 32)),
                ),
              ),
            ]),
            if (r.engine == Engine.local && r.bytes > 0)
              Text(fmtBytes(r.bytes), style: context.ssType.mono.copyWith(color: ss.onPlayerMuted)),
            const SizedBox(height: SsSpace.lg),
            Row(children: [
              if (onExtend != null) ...[
                Expanded(
                    child: SsButton(label: '+10 phút', icon: Icons.smart_display_rounded, variant: SsButtonVariant.secondary, size: SsButtonSize.md44, onPressed: onExtend)),
                const SizedBox(width: SsSpace.sm),
              ],
              Expanded(
                child: SsButton(
                  label: 'Dừng recording',
                  icon: Icons.stop_rounded,
                  variant: SsButtonVariant.destructive,
                  size: SsButtonSize.md44,
                  loading: r.status == RecordingStatus.finalizing,
                  onPressed: onStop,
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
