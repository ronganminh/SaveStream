import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_providers.dart';
import '../../data/repositories/mock_notifications_repository.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';

final Provider<NotificationsRepository> notificationsRepositoryProvider =
    Provider<NotificationsRepository>(
      (ref) => MockNotificationsRepository(ref.watch(mockBehaviorProvider)),
    );

class NotificationFeedState {
  const NotificationFeedState({
    required this.items,
    this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<AppNotification> items;
  final String? nextCursor;
  final bool isLoadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;
}

final AsyncNotifierProvider<NotificationFeedController, NotificationFeedState>
notificationFeedProvider =
    AsyncNotifierProvider<NotificationFeedController, NotificationFeedState>(
      NotificationFeedController.new,
    );

class NotificationFeedController extends AsyncNotifier<NotificationFeedState> {
  @override
  Future<NotificationFeedState> build() async {
    final NotificationPage page = await ref
        .watch(notificationsRepositoryProvider)
        .listNotifications();
    return NotificationFeedState(
      items: page.items,
      nextCursor: page.nextCursor,
    );
  }

  Future<void> loadMore() async {
    final NotificationFeedState? current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData<NotificationFeedState>(
      NotificationFeedState(
        items: current.items,
        nextCursor: current.nextCursor,
        isLoadingMore: true,
      ),
    );
    try {
      final NotificationPage page = await ref
          .read(notificationsRepositoryProvider)
          .listNotifications(cursor: current.nextCursor);
      if (!ref.mounted) return;
      state = AsyncData<NotificationFeedState>(
        NotificationFeedState(
          items: <AppNotification>[...current.items, ...page.items],
          nextCursor: page.nextCursor,
        ),
      );
    } on Object catch (error) {
      if (!ref.mounted) return;
      // Keep the loaded pages; the failure stays local to the Load more row.
      state = AsyncData<NotificationFeedState>(
        NotificationFeedState(
          items: current.items,
          nextCursor: current.nextCursor,
          loadMoreError: error,
        ),
      );
    }
  }

  /// Marks one notification read. Rethrows so the screen can report failure.
  Future<void> markRead(String notificationId) async {
    final AppNotification saved = await ref
        .read(notificationsRepositoryProvider)
        .markRead(notificationId);
    if (!ref.mounted) return;
    final NotificationFeedState? current = state.value;
    if (current == null) return;
    state = AsyncData<NotificationFeedState>(
      NotificationFeedState(
        items: <AppNotification>[
          for (final AppNotification item in current.items)
            item.id == notificationId ? saved : item,
        ],
        nextCursor: current.nextCursor,
        isLoadingMore: current.isLoadingMore,
        loadMoreError: current.loadMoreError,
      ),
    );
  }

  /// Marks everything read at once (optimistic). Restores the previous items
  /// and rethrows when the server refuses.
  Future<void> markAllRead() async {
    final NotificationFeedState? current = state.value;
    if (current == null) return;
    NotificationFeedState withItems(List<AppNotification> items) {
      return NotificationFeedState(
        items: items,
        nextCursor: current.nextCursor,
        isLoadingMore: current.isLoadingMore,
        loadMoreError: current.loadMoreError,
      );
    }

    state = AsyncData<NotificationFeedState>(
      withItems(<AppNotification>[
        for (final AppNotification item in current.items)
          item.read ? item : item.copyWith(read: true),
      ]),
    );
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
    } on Object {
      if (ref.mounted) {
        state = AsyncData<NotificationFeedState>(withItems(current.items));
      }
      rethrow;
    }
  }
}

/// Whether the bell shows its unread dot. The API has no unread-count
/// endpoint, so this reads the loaded feed pages (newest first).
final Provider<int> unreadNotificationCountProvider = Provider<int>((ref) {
  return ref
          .watch(notificationFeedProvider)
          .value
          ?.items
          .where((AppNotification item) => !item.read)
          .length ??
      0;
});
