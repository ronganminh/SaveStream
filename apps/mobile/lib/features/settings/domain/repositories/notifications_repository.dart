import '../models/app_notification.dart';
import '../models/notification_preferences.dart';

abstract interface class NotificationsRepository {
  Future<NotificationPage> listNotifications({String? cursor});

  Future<AppNotification> markRead(String notificationId);

  /// Marks every notification read. Returns how many changed.
  Future<int> markAllRead();
}

abstract interface class NotificationPreferencesRepository {
  Future<NotificationPreferences> getPreferences();

  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  );
}
