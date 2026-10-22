import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/features/settings/domain/models/notification_preferences.dart';

void main() {
  test('G05 keeps an explicit expired session state', () {
    final AppSessionController session = AppSessionController();

    session.expireSessionForPreview();

    expect(session.authStatus, AppAuthStatus.expired);
    expect(session.isAuthenticated, isFalse);
  });

  test('S05 V2 notification preferences update independently', () {
    const NotificationPreferences initial = NotificationPreferences(
      recordingStarted: true,
      recordingReady: true,
      recordingFailed: true,
    );

    final NotificationPreferences updated = initial.copyWith(
      creatorLive: false,
      recordingExpiring: false,
      freeMinutesLow: false,
    );

    expect(updated.creatorLive, isFalse);
    expect(updated.recordingExpiring, isFalse);
    expect(updated.freeMinutesLow, isFalse);
    expect(updated.recordingStarted, isTrue);
    expect(updated.recordingReady, isTrue);
    expect(updated.recordingFailed, isTrue);
  });
}
