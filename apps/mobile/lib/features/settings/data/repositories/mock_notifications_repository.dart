import '../../../../core/mock/mock_repository_base.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/notification_preferences.dart';
import '../../domain/repositories/notifications_repository.dart';

final class MockNotificationsRepository extends MockRepositoryBase
    implements NotificationsRepository {
  MockNotificationsRepository(super.behavior);

  final Set<String> _readIds = <String>{};

  List<AppNotification> get _seed => <AppNotification>[
    AppNotification(
      id: 'notification-ready',
      type: AppNotificationType.recordingReady,
      title: 'Recording ready',
      body: 'Your recording of @alex.live is ready to play.',
      read: _readIds.contains('notification-ready'),
      createdAt: DateTime.utc(2026, 10, 2, 9),
      resourceType: 'recording',
      resourceId: 'recording-completed',
    ),
    AppNotification(
      id: 'notification-started',
      type: AppNotificationType.recordingStarted,
      title: 'Recording started',
      body: 'SaveStream started recording @alex.live.',
      read: true,
      createdAt: DateTime.utc(2026, 10, 2, 8),
    ),
    AppNotification(
      id: 'notification-creator-live',
      type: AppNotificationType.other,
      v2Type: AppNotificationV2Type.creatorLive,
      title: 'Creator is LIVE',
      body: '@alex.live is LIVE now.',
      read: false,
      createdAt: DateTime.utc(2026, 10, 2, 7, 45),
      resourceType: 'watch',
      resourceId: 'watch_001',
    ),
    AppNotification(
      id: 'notification-expiring',
      type: AppNotificationType.other,
      v2Type: AppNotificationV2Type.recordingExpiring,
      title: 'Recording expires soon',
      body: 'A cloud recording will expire soon.',
      read: false,
      createdAt: DateTime.utc(2026, 10, 2, 7, 30),
      resourceType: 'recording',
      resourceId: 'recording-completed',
    ),
    AppNotification(
      id: 'notification-free-minutes-low',
      type: AppNotificationType.other,
      v2Type: AppNotificationV2Type.freeMinutesLow,
      title: 'Free minutes are running low',
      body: 'You are close to using today\'s Free recording minutes.',
      read: false,
      createdAt: DateTime.utc(2026, 10, 2, 7, 15),
    ),
  ];

  @override
  Future<NotificationPage> listNotifications({String? cursor}) {
    return respond<NotificationPage>(
      success: () => NotificationPage(items: _seed),
      empty: () => const NotificationPage(items: <AppNotification>[]),
    );
  }

  @override
  Future<AppNotification> markRead(String notificationId) {
    return respond<AppNotification>(
      success: () {
        _readIds.add(notificationId);
        return _seed.firstWhere(
          (AppNotification item) => item.id == notificationId,
        );
      },
      empty: () => throw StateError('No notification to mark read.'),
    );
  }
}

final class MockNotificationPreferencesRepository extends MockRepositoryBase
    implements NotificationPreferencesRepository {
  MockNotificationPreferencesRepository(super.behavior);

  NotificationPreferences _preferences = const NotificationPreferences(
    recordingStarted: true,
    recordingReady: true,
    recordingFailed: true,
    creatorLive: true,
    recordingExpiring: true,
    freeMinutesLow: true,
  );

  @override
  Future<NotificationPreferences> getPreferences() {
    return respond<NotificationPreferences>(
      success: () => _preferences,
      empty: () => _preferences,
    );
  }

  @override
  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  ) {
    return respond<NotificationPreferences>(
      success: () => _preferences = preferences,
      empty: () => _preferences = preferences,
    );
  }
}
