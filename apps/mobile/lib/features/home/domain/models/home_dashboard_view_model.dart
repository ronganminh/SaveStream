import '../../../channels/domain/models/watch_summary.dart';
import '../../../entitlement/domain/models/entitlement.dart';
import '../../../recordings/domain/models/recording_summary.dart';

class HomeAccountMetrics {
  const HomeAccountMetrics({
    required this.displayName,
    required this.availableCredit,
    required this.recordingHoursUsed,
    required this.recordingHoursLimit,
  });

  final String displayName;
  final int availableCredit;
  final double recordingHoursUsed;
  final double recordingHoursLimit;

  HomeAccountMetrics copyWith({int? availableCredit}) {
    return HomeAccountMetrics(
      displayName: displayName,
      availableCredit: availableCredit ?? this.availableCredit,
      recordingHoursUsed: recordingHoursUsed,
      recordingHoursLimit: recordingHoursLimit,
    );
  }
}

class HomeDashboardViewModel {
  const HomeDashboardViewModel({
    required this.metrics,
    required this.watches,
    required this.recordings,
    required this.entitlement,
  });

  final HomeAccountMetrics metrics;
  final List<WatchSummary> watches;
  final List<RecordingSummary> recordings;
  final Entitlement entitlement;

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

  List<WatchSummary> get liveWatches =>
      watches.where((WatchSummary item) => item.isLive).toList(growable: false);

  List<RecordingSummary> get waitingForCloudSlot => recordings
      .where(
        (RecordingSummary item) =>
            item.status == RecordingStatus.waitingForCloudSlot,
      )
      .toList(growable: false);

  List<RecordingSummary> get missedNoCloudSlot => recordings
      .where(
        (RecordingSummary item) =>
            item.status == RecordingStatus.missedNoCloudSlot,
      )
      .toList(growable: false);

  bool get hasAhaMoment => watches.isNotEmpty && recordings.isNotEmpty;

  int get cloudSlotsUsed => activeRecordings
      .where((RecordingSummary item) => item.engine == Engine.cloud)
      .length;

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
