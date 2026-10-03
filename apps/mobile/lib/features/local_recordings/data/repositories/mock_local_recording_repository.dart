import '../../../../core/mock/mock_repository_base.dart';
import '../../../recordings/domain/models/recording_summary.dart';
import '../../domain/models/local_recording_models.dart';
import '../../domain/repositories/local_recording_repository.dart';

final class MockLocalRecordingRepository extends MockRepositoryBase
    implements LocalRecordingRepository {
  MockLocalRecordingRepository(super.behavior);

  final Map<String, LocalRecordingSession> _sessions =
      <String, LocalRecordingSession>{};
  final List<LocalRecordingSummary> _items = <LocalRecordingSummary>[];

  @override
  Future<LocalRecordingSession> start({
    required String watchId,
    required String deviceId,
    String? rewardId,
  }) {
    return respond<LocalRecordingSession>(
      success: () {
        final String id = 'lrs_${_sessions.length + 1}';
        final LocalRecordingSession session = LocalRecordingSession(
          sessionId: id,
          watchId: watchId,
          deviceId: deviceId,
          grantedSeconds: rewardId == null ? 600 : 1200,
          leaseExpiresAt: DateTime.utc(2026, 10, 3, 14),
          streamUrl: Uri.parse('https://example.test/live/$watchId.flv'),
          streamFormat: LocalStreamFormat.flv,
          streamHeaders: const <String, String>{'User-Agent': 'SaveStream'},
        );
        _sessions[id] = session;
        return session;
      },
      empty: () => LocalRecordingSession(
        sessionId: 'lrs_empty',
        watchId: watchId,
        deviceId: deviceId,
        grantedSeconds: 0,
        leaseExpiresAt: DateTime.utc(2026, 10, 3, 14),
        streamUrl: Uri.parse('https://example.test/empty.flv'),
        streamFormat: LocalStreamFormat.flv,
      ),
    );
  }

  @override
  Future<LocalRecordingSession> extend(String sessionId, {String? rewardId}) {
    return respond<LocalRecordingSession>(
      success: () {
        final LocalRecordingSession current =
            _sessions[sessionId] ??
            (throw StateError('Unknown local recording session.'));
        final LocalRecordingSession extended = current.copyWith(
          grantedSeconds: current.grantedSeconds + 600,
          leaseExpiresAt: current.leaseExpiresAt.add(
            const Duration(minutes: 10),
          ),
        );
        _sessions[sessionId] = extended;
        return extended;
      },
      empty: () =>
          _sessions[sessionId] ??
          (throw StateError('Unknown local recording session.')),
    );
  }

  @override
  Future<LocalRecordingSummary> finish(
    String sessionId, {
    required int recordedSeconds,
    required int sizeBytes,
    required RecordingEndReason endReason,
    required RecordingStatus status,
  }) {
    return respond<LocalRecordingSummary>(
      success: () {
        final LocalRecordingSession session =
            _sessions.remove(sessionId) ??
            (throw StateError('Unknown local recording session.'));
        final LocalRecordingSummary summary = LocalRecordingSummary(
          id: sessionId,
          watchId: session.watchId,
          creatorDisplayName: 'Mock creator',
          creatorHandle: '@mock_creator',
          deviceId: session.deviceId,
          deviceName: 'Mock device',
          startedAt: DateTime.utc(2026, 10, 3, 13, 22),
          recordedSeconds: recordedSeconds,
          sizeBytes: sizeBytes,
          status: status,
        );
        _items.insert(0, summary);
        return summary;
      },
      empty: () => LocalRecordingSummary(
        id: sessionId,
        watchId: 'watch_empty',
        creatorDisplayName: 'Mock creator',
        creatorHandle: '@mock_creator',
        deviceId: 'device_empty',
        deviceName: 'Mock device',
        startedAt: DateTime.utc(2026, 10, 3, 13, 22),
        recordedSeconds: 0,
        sizeBytes: 0,
        status: RecordingStatus.partial,
      ),
    );
  }

  @override
  Future<List<LocalRecordingSummary>> list() {
    return respond<List<LocalRecordingSummary>>(
      success: () => List<LocalRecordingSummary>.unmodifiable(_items),
      empty: () => const <LocalRecordingSummary>[],
    );
  }

  @override
  Future<void> delete(String id, {required String deviceId}) {
    return respond<void>(
      success: () {
        _items.removeWhere(
          (LocalRecordingSummary item) =>
              item.id == id && item.deviceId == deviceId,
        );
      },
      empty: () {},
    );
  }
}
