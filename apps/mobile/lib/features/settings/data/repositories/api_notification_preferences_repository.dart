import '../../../../core/api/api_client.dart';
import '../../domain/models/notification_preferences.dart';
import '../../domain/repositories/notifications_repository.dart';

final class ApiNotificationPreferencesRepository
    implements NotificationPreferencesRepository {
  const ApiNotificationPreferencesRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<NotificationPreferences> getPreferences() async {
    final response = await _apiClient.get<NotificationPreferences>(
      '/v1/me/notification-preferences',
      decoder: _decode,
    );
    return response.data;
  }

  @override
  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  ) async {
    final response = await _apiClient.patch<NotificationPreferences>(
      '/v1/me/notification-preferences',
      data: <String, Object?>{
        'recording_started': preferences.recordingStarted,
        'recording_ready': preferences.recordingReady,
        'recording_failed': preferences.recordingFailed,
        'creator_live': preferences.creatorLive,
        'recording_expiring': preferences.recordingExpiring,
        'free_minutes_low': preferences.freeMinutesLow,
        'marketing': preferences.marketing,
        'email_creator_live': preferences.emailCreatorLive,
        'email_recording_ready': preferences.emailRecordingReady,
        'email_recording_failed': preferences.emailRecordingFailed,
        'email_recording_expiring': preferences.emailRecordingExpiring,
        'email_credits_low': preferences.emailCreditsLow,
        'email_credits_exhausted': preferences.emailCreditsExhausted,
      },
      decoder: _decode,
    );
    return response.data;
  }

  static NotificationPreferences _decode(Object? json) {
    final map = json as Map<String, Object?>;
    // Fields added after the first release default like the server does.
    bool flag(String key, {bool fallback = true}) =>
        map[key] as bool? ?? fallback;
    return NotificationPreferences(
      recordingStarted: map['recording_started'] as bool,
      recordingReady: map['recording_ready'] as bool,
      recordingFailed: map['recording_failed'] as bool,
      creatorLive: map['creator_live'] as bool,
      recordingExpiring: map['recording_expiring'] as bool,
      freeMinutesLow: map['free_minutes_low'] as bool,
      marketing: flag('marketing', fallback: false),
      emailCreatorLive: flag('email_creator_live'),
      emailRecordingReady: flag('email_recording_ready'),
      emailRecordingFailed: flag('email_recording_failed'),
      emailRecordingExpiring: flag('email_recording_expiring'),
      emailCreditsLow: flag('email_credits_low'),
      emailCreditsExhausted: flag('email_credits_exhausted'),
      emailSupported: flag('email_supported'),
    );
  }
}
