import '../models/recording_summary.dart';

abstract interface class RecordingRepository {
  Future<List<RecordingSummary>> listRecordings();

  Future<RecordingPage> listRecordingPage({
    RecordingFilter filter = RecordingFilter.all,
    String? cursor,
    int limit = 4,
  });

  Future<RecordingSummary?> getRecording(String id);

  Future<RecordingSummary?> stopRecording(String id);

  Future<RecordingSummary?> retryRecording(String id);

  Future<void> deleteRecording(String id);
}
