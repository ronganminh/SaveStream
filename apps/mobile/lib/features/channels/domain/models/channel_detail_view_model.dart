import '../../../recordings/domain/models/recording_summary.dart';
import 'watch_summary.dart';

class ChannelDetailViewModel {
  const ChannelDetailViewModel({
    required this.watch,
    required this.recordings,
  });

  final WatchSummary watch;
  final List<RecordingSummary> recordings;

  RecordingSummary? get latestRecording =>
      recordings.isEmpty ? null : recordings.first;
}
