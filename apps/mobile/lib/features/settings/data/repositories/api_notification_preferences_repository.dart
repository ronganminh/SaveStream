import '../../../../core/api/api_client.dart';
import '../../domain/models/notification_preferences.dart';

final class ApiNotificationPreferencesRepository {
  const ApiNotificationPreferencesRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<NotificationPreferences> getPreferences() async {
    final response = await _apiClient.get<NotificationPreferences>(
      '/v1/me/notification-preferences',
      decoder: _decode,
    );
    return response.data;
  }

  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  ) async {
    final response = await _apiClient.patch<NotificationPreferences>(
      '/v1/me/notification-preferences',
      data: <String, Object?>{
        'recording_started': preferences.recordingStarted,
        'recording_ready': preferences.recordingReady,
        'recording_failed': preferences.recordingFailed,
      },
      decoder: _decode,
    );
    return response.data;
  }

  static NotificationPreferences _decode(Object? json) {
    final map = json as Map<String, Object?>;
    return NotificationPreferences(
      recordingStarted: map['recording_started'] as bool,
      recordingReady: map['recording_ready'] as bool,
      recordingFailed: map['recording_failed'] as bool,
    );
  }
}
