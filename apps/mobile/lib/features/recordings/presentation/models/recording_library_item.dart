import '../../domain/models/recording_summary.dart';

enum RecordingLibraryIssue {
  none,
  expiredCloud,
  partialTimeline,
  missedNoCloudSlot,
  missingCloudArtifact,
}

class RecordingLibraryItem {
  const RecordingLibraryItem({
    required this.id,
    required this.creatorDisplayName,
    required this.creatorHandle,
    required this.status,
    required this.startedAt,
    required this.durationSeconds,
    required this.sizeBytes,
    required this.canPlay,
    required this.canShare,
    required this.canDelete,
    this.expiresAt,
    this.issue = RecordingLibraryIssue.none,
  });

  final String id;
  final String creatorDisplayName;
  final String creatorHandle;
  final RecordingStatus status;
  final DateTime? startedAt;
  final int durationSeconds;
  final int sizeBytes;
  final bool canPlay;
  final bool canShare;
  final bool canDelete;
  final DateTime? expiresAt;
  final RecordingLibraryIssue issue;

  bool isExpiringSoon(DateTime now) {
    final DateTime? expiry = expiresAt;
    if (expiry == null || !expiry.isAfter(now)) return false;
    return expiry.difference(now) <= const Duration(days: 3);
  }
}

RecordingLibraryItem libraryItemFromCloud(RecordingSummary recording) {
  final bool supportsArtifact = switch (recording.status) {
    RecordingStatus.completed ||
    RecordingStatus.partial ||
    RecordingStatus.recovered ||
    RecordingStatus.stopped => true,
    _ => false,
  };
  final RecordingLibraryIssue issue = switch (recording.status) {
    RecordingStatus.missedNoCloudSlot =>
      RecordingLibraryIssue.missedNoCloudSlot,
    RecordingStatus.partial => RecordingLibraryIssue.partialTimeline,
    _ when supportsArtifact && !recording.artifactReady =>
      RecordingLibraryIssue.missingCloudArtifact,
    _ => RecordingLibraryIssue.none,
  };

  return RecordingLibraryItem(
    id: recording.id,
    creatorDisplayName: recording.creatorDisplayName,
    creatorHandle: recording.creatorUsername,
    status: recording.status,
    startedAt: recording.startedAt,
    durationSeconds: recording.durationSeconds,
    sizeBytes: recording.sizeBytes ?? recording.bytesRecorded ?? 0,
    canPlay: supportsArtifact && recording.artifactReady,
    canShare: supportsArtifact && recording.artifactReady,
    canDelete: recording.actions.canDelete,
    expiresAt: recording.expiresAt,
    issue: issue,
  );
}
