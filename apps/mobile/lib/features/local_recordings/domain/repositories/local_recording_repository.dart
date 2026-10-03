import '../../../recordings/domain/models/recording_summary.dart';
import '../models/local_recording_models.dart';

abstract interface class LocalRecordingRepository {
  Future<LocalRecordingSession> start({
    required String watchId,
    required String deviceId,
    String? rewardId,
  });

  Future<LocalRecordingSession> extend(String sessionId, {String? rewardId});

  Future<LocalRecordingSummary> finish(
    String sessionId, {
    required int recordedSeconds,
    required int sizeBytes,
    required RecordingEndReason endReason,
    required RecordingStatus status,
  });

  Future<List<LocalRecordingSummary>> list();

  Future<void> delete(String id, {required String deviceId});
}
