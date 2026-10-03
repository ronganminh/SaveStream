import 'package:flutter/material.dart';

import '../core/enums.dart';
import '../core/models.dart';
import '../theme/ss_theme.dart';
import 'ss_avatar.dart';
import 'ss_badges.dart';
import 'ss_button.dart';

enum SsCreatorTileMode { freeManual, proAuto }

class SsCreatorTile extends StatelessWidget {
  const SsCreatorTile({
    super.key,
    required this.creator,
    this.mode = SsCreatorTileMode.freeManual,
    this.onTap,
    this.onRecord,
    this.onToggleNotify,
    this.onAutoRecord,
  });
  final Creator creator;
  final SsCreatorTileMode mode;
  final VoidCallback? onTap, onRecord, onAutoRecord;
  final ValueChanged<bool>? onToggleNotify;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final c = creator;
    final live = c.liveStatus == LiveStatus.live;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SsRadius.card), side: BorderSide(color: cs.outline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(SsSpace.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SsCreatorAvatar(initials: c.initials, imageUrl: c.avatarUrl, isLive: live),
              const SizedBox(width: SsSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name, style: context.tt.titleSmall),
                  Text(live || c.lastLiveLabel == null ? '${c.handle} · TikTok' : 'LIVE gần nhất ${c.lastLiveLabel}',
                      style: context.tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
              SsLiveBadge(status: c.liveStatus),
            ]),
            if (live && onRecord != null) ...[
              const SizedBox(height: SsSpace.md),
              SsButton(label: 'Record ngay', icon: Icons.radio_button_checked_rounded, size: SsButtonSize.md44, onPressed: onRecord),
            ],
            const SizedBox(height: SsSpace.sm),
            _row(context, Icons.notifications_active_rounded, 'Thông báo khi LIVE',
                Switch(value: c.notify, onChanged: onToggleNotify)),
            if (mode == SsCreatorTileMode.freeManual)
              _row(context, Icons.lock_rounded, 'Auto-record trên cloud', const _ProTag(), onTap: onAutoRecord)
            else
              _row(context, Icons.cloud_rounded, 'Auto-record trên cloud',
                  Switch(value: c.autoRecord, onChanged: (_) => onAutoRecord?.call())),
          ]),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData i, String l, Widget trailing, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SsSpace.minTap),
          child: Row(children: [
            Icon(i, size: 20, color: context.cs.onSurfaceVariant),
            const SizedBox(width: SsSpace.sm),
            Expanded(child: Text(l, style: context.tt.bodyMedium)),
            trailing,
          ]),
        ),
      );
}

class _ProTag extends StatelessWidget {
  const _ProTag();
  @override
  Widget build(BuildContext context) => const SsPlanBadge(plan: Plan.pro);
}
