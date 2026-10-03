import 'package:flutter/material.dart';

import '../theme/ss_theme.dart';

enum SsAvatarSize { s32, s44, s56 }

class SsCreatorAvatar extends StatelessWidget {
  const SsCreatorAvatar({super.key, required this.initials, this.imageUrl, this.size = SsAvatarSize.s44, this.isLive = false});
  final String initials;
  final String? imageUrl;
  final SsAvatarSize size;
  final bool isLive;

  double get _d => switch (size) { SsAvatarSize.s32 => 32, SsAvatarSize.s44 => 44, SsAvatarSize.s56 => 56 };

  @override
  Widget build(BuildContext context) {
    final cs = context.cs, ss = context.ss;
    final inner = CircleAvatar(
      radius: _d / 2,
      backgroundColor: cs.primaryContainer,
      foregroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
      child: Text(initials,
          style: context.tt.labelMedium!.copyWith(color: cs.primary, fontSize: _d * .34), textScaler: TextScaler.noScaling),
    );
    if (!isLive) return inner;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ss.recording, width: 2)),
      child: inner,
    );
  }
}
