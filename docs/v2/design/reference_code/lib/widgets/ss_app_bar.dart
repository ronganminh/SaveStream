import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/enums.dart';
import '../theme/ss_theme.dart';
import 'ss_badges.dart';

enum SsAppBarVariant { large, compact, modal }

/// Không phải PreferredSizeWidget — để chiều cao tự giãn khi text scale 200% (X01–X03).
class SsAppBar extends StatelessWidget {
  const SsAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.variant = SsAppBarVariant.large,
    this.actions = const [],
    this.plan,
    this.hasUnread = false,
    this.showNotifications = false,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final SsAppBarVariant variant;
  final List<Widget> actions;
  final Plan? plan;
  final bool hasUnread, showNotifications;
  final VoidCallback? onBack;

  static void _pop(BuildContext c) {
    if (c.canPop()) c.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final large = variant == SsAppBarVariant.large;
    final lead = switch (variant) {
      SsAppBarVariant.large => null,
      SsAppBarVariant.compact => IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: onBack ?? () => _pop(context)),
      SsAppBarVariant.modal => IconButton(
          tooltip: 'Đóng',
          icon: const Icon(Icons.close_rounded),
          onPressed: onBack ?? () => _pop(context)),
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(large ? 20 : 4, large ? 8 : 4, 8, large ? 12 : 4),
      child: Row(children: [
        if (lead != null) lead,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title,
                style: large ? context.tt.titleLarge!.copyWith(fontWeight: FontWeight.w700) : context.tt.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            if (subtitle != null)
              Text(subtitle!, style: context.tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ),
        if (plan != null) ...[SsPlanBadge(plan: plan!), const SizedBox(width: SsSpace.xs)],
        ...actions,
        if (showNotifications)
          IconButton(
            tooltip: hasUnread ? 'Thông báo, có mục chưa đọc' : 'Thông báo',
            onPressed: () => context.push('/notifications'),
            icon: Badge(isLabelVisible: hasUnread, smallSize: 9, backgroundColor: context.ss.recording, child: const Icon(Icons.notifications_rounded)),
          ),
      ]),
    );
  }
}
