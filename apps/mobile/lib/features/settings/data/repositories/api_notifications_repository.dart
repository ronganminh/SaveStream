import '../../../../core/api/api_client.dart';
import '../../domain/models/app_notification.dart';

final class ApiNotificationsRepository {
  const ApiNotificationsRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<AppNotification>> listNotifications() async {
    final response = await _apiClient.get<List<AppNotification>>(
      '/v1/notifications',
      queryParameters: <String, dynamic>{'limit': 50},
      decoder: _decodeList,
    );
    return response.data;
  }

  Future<AppNotification> markRead(String notificationId) async {
    final response = await _apiClient.patch<AppNotification>(
      '/v1/notifications/$notificationId',
      data: <String, Object?>{'read': true},
      decoder: _decodeItem,
    );
    return response.data;
  }

  static List<AppNotification> _decodeList(Object? json) {
    final map = json as Map<String, Object?>;
    final items = map['items'] as List<Object?>;
    return List<AppNotification>.unmodifiable(items.map(_decodeItem));
  }

  static AppNotification _decodeItem(Object? json) {
    final map = json as Map<String, Object?>;
    return AppNotification(
      id: map['id'] as String,
      type: switch (map['type']) {
        'recording_started' => AppNotificationType.recordingStarted,
        'recording_ready' => AppNotificationType.recordingReady,
        'recording_failed' => AppNotificationType.recordingFailed,
        _ => throw const FormatException('Unknown notification type'),
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
