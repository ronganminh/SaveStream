import '../../../../core/api/api_client.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';

final class ApiNotificationsRepository implements NotificationsRepository {
  const ApiNotificationsRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  static const int _pageSize = 50;

  final ApiClient _apiClient;

  @override
  Future<NotificationPage> listNotifications({String? cursor}) async {
    final response = await _apiClient.get<NotificationPage>(
      '/v1/notifications',
      queryParameters: <String, dynamic>{
        'limit': _pageSize,
        if (cursor != null) 'cursor': cursor,
      },
      decoder: _decodePage,
    );
    return response.data;
  }

  @override
  Future<AppNotification> markRead(String notificationId) async {
    final response = await _apiClient.patch<AppNotification>(
      '/v1/notifications/$notificationId',
      data: <String, Object?>{'read': true},
      decoder: _decodeItem,
    );
    return response.data;
  }

  static NotificationPage _decodePage(Object? json) {
    final map = json as Map<String, Object?>;
    final items = map['items'] as List<Object?>;
    final pagination = map['pagination'] as Map<String, Object?>?;
    final bool hasMore = pagination?['has_more'] as bool? ?? false;
    final Object? nextCursor = pagination?['next_cursor'];
    return NotificationPage(
      items: List<AppNotification>.unmodifiable(items.map(_decodeItem)),
      nextCursor: hasMore && nextCursor is String ? nextCursor : null,
    );
  }

  static AppNotification _decodeItem(Object? json) {
    final map = json as Map<String, Object?>;
    final String rawType = map['type'] as String;
    return AppNotification(
      id: map['id'] as String,
      // An unknown kind must not take the whole feed down with it.
      type: switch (rawType) {
        'recording_started' => AppNotificationType.recordingStarted,
        'recording_ready' => AppNotificationType.recordingReady,
        'recording_failed' => AppNotificationType.recordingFailed,
        _ => AppNotificationType.other,
      },
      v2Type: switch (rawType) {
        'creator_live' => AppNotificationV2Type.creatorLive,
        'recording_expiring' => AppNotificationV2Type.recordingExpiring,
        'free_minutes_low' => AppNotificationV2Type.freeMinutesLow,
        _ => null,
      },
      title: map['title'] as String,
      body: map['body'] as String,
      read: map['read'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
      resourceType: map['resource_type'] as String?,
      resourceId: map['resource_id'] as String?,
    );
  }
}
