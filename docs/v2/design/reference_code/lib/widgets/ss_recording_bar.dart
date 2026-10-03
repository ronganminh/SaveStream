import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../theme/ss_theme.dart';
import 'ss_avatar.dart';

/// Thanh nổi trên bottom nav khi có 1–2 recording. Ẩn trên Active Recording detail.
class SsRecordingBar extends StatelessWidget {
  const SsRecordingBar({super.key, required this.recordings, required this.onTap});
  final List<ActiveRecording> recordings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ss = context.ss;
    final first = recordings.first;
    final label = recordings.length == 1 ? first.creator.name : '${recordings.length} recording đang chạy';
    final timers = recordings.map((r) => fmtDuration(r.elapsed)).join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(SsSpace.sm, 0, SsSpace.sm, SsSpace.sm),
      child: Material(
        color: ss.player,
        borderRadius: BorderRadius.circular(SsRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(SsRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SsSpace.md, vertical: SsSpace.sm),
            child: Row(children: [
              SsCreatorAvatar(initials: first.creator.initials, size: SsAvatarSize.s32, isLive: true),
              const SizedBox(width: SsSpace.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: context.tt.labelMedium!.copyWith(color: ss.onPlayer), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(timers, style: context.ssType.mono.copyWith(color: ss.onPlayerMuted, fontSize: 12)),
                ]),
              ),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: ss.recording, shape: BoxShape.circle)),
              const SizedBox(width: SsSpace.sm),
              Icon(Icons.expand_less_rounded, color: ss.onPlayer),
            ]),
          ),
        ),
      ),
    );
  }
}
