import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/features/local_recordings/domain/models/local_recording_models.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/settings/domain/models/notification_preferences.dart';
import 'package:savestream_mobile/features/settings/presentation/device_storage_screen.dart';

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

  test('S03 snapshot counts only the indexed Local recordings it receives', () {
    final LocalRecordingSummary recording = LocalRecordingSummary(
      id: 'local-1',
      watchId: 'watch-1',
      creatorDisplayName: 'Creator',
      creatorHandle: '@creator',
      deviceId: 'device-1',
      deviceName: 'Phone',
      startedAt: DateTime.utc(2026, 10, 1),
      recordedSeconds: 60,
      sizeBytes: 1024,
      status: RecordingStatus.completed,
    );

    final DeviceStorageSnapshot snapshot = DeviceStorageSnapshot(
      freeBytes: 2048,
      localBytes: recording.sizeBytes,
      localCount: 1,
      recordings: <LocalRecordingSummary>[recording],
    );

    expect(snapshot.freeBytes, 2048);
    expect(snapshot.localBytes, 1024);
    expect(snapshot.localCount, 1);
    expect(snapshot.recordings.single.id, 'local-1');
  });
}
