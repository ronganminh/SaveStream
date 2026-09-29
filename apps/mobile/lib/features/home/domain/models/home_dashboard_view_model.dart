import '../../../channels/domain/models/watch_summary.dart';
import '../../../recordings/domain/models/recording_summary.dart';

class HomeAccountMetrics {
  const HomeAccountMetrics({
    required this.displayName,
    required this.availableCredit,
    required this.recordingHoursUsed,
    required this.recordingHoursLimit,
  });

  final String displayName;
  final double availableCredit;
  final double recordingHoursUsed;
  final double recordingHoursLimit;
}

class HomeDashboardViewModel {
  const HomeDashboardViewModel({
    required this.metrics,
    required this.watches,
    required this.recordings,
  });

  final HomeAccountMetrics metrics;
  final List<WatchSummary> watches;
  final List<RecordingSummary> recordings;

  static const double lowCreditThreshold = 5;

  List<RecordingSummary> get activeRecordings => recordings
      .where(
        (RecordingSummary item) => item.status == RecordingStatus.recording,
      )
      .toList(growable: false);

  List<RecordingSummary> get failedRecordings => recordings
      .where((RecordingSummary item) => item.status == RecordingStatus.failed)
      .toList(growable: false);

  List<WatchSummary> get featuredWatches =>
      watches.take(3).toList(growable: false);

  List<RecordingSummary> get recentRecordings =>
      recordings.take(3).toList(growable: false);

  int get monitoredChannelCount => watches.length;

  bool get isEmptyAccount => watches.isEmpty && recordings.isEmpty;

  bool get isLowCredit =>
      !isEmptyAccount && metrics.availableCredit <= lowCreditThreshold;

  double get usageProgress {
    if (metrics.recordingHoursLimit <= 0) {
      return 0;
    }
    return (metrics.recordingHoursUsed / metrics.recordingHoursLimit).clamp(
      0,
      1,
    );
  }
}
