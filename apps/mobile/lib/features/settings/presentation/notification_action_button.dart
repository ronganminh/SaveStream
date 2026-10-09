import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../l10n/l10n.dart';
import 'controllers/notification_feed_providers.dart';

/// Header notification action from the V2 spec.
///
/// The spec intentionally uses a dot (not a numeric badge) so large unread
/// counts do not change the header geometry.
class NotificationActionButton extends ConsumerWidget {
  const NotificationActionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool hasUnread =
        ref
            .watch(notificationFeedProvider)
            .value
            ?.items
            .any((item) => !item.read) ??
        false;

    return IconButton(
      tooltip: context.l10n.notificationsTitle,
      onPressed: () => context.push(AppRoutes.notifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Icon(Icons.notifications_outlined),
          if (hasUnread)
            Positioned(
              top: -1,
              right: -2,
              child: Container(
                key: const ValueKey<String>('notification-unread-dot'),
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
