import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../data/repositories/api_notifications_repository.dart';
import '../../domain/models/app_notification.dart';

final Provider<ApiNotificationsRepository> notificationsRepositoryProvider =
    Provider<ApiNotificationsRepository>((ref) {
      return ApiNotificationsRepository(
        apiClient: ref.watch(apiClientProvider),
      );
    });

final FutureProvider<List<AppNotification>> notificationFeedProvider =
    FutureProvider<List<AppNotification>>((ref) {
      return ref.watch(notificationsRepositoryProvider).listNotifications();
    });
