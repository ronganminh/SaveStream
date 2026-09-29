import '../models/recording_summary.dart';

abstract interface class RecordingRepository {
  Future<List<RecordingSummary>> listRecordings();

  Future<RecordingSummary?> getRecording(String id);
}
