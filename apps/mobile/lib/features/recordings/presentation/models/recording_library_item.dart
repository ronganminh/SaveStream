import '../../../local_recordings/domain/models/local_recording_models.dart';
import '../../domain/models/recording_summary.dart';

enum RecordingLibraryStorage { local, cloud }

enum RecordingDeleteTarget { local, cloud, both }

enum RecordingLibraryIssue {
  none,
  missingLocalFile,
  expiredCloud,
  partialTimeline,
  missedNoCloudSlot,
}

class RecordingLibraryItem {
  const RecordingLibraryItem({
    required this.id,
    required this.creatorDisplayName,
    required this.creatorHandle,
    required this.storage,
    required this.status,
    required this.startedAt,
    required this.durationSeconds,
    required this.sizeBytes,
    required this.canPlay,
    required this.canShare,
    required this.canDelete,
    this.deviceId,
    this.deviceName,
    this.expiresAt,
    this.issue = RecordingLibraryIssue.none,
  });

  final String id;
  final String creatorDisplayName;
  final String creatorHandle;
  final RecordingLibraryStorage storage;
  final RecordingStatus status;
  final DateTime? startedAt;
  final int durationSeconds;
  final int sizeBytes;
  final bool canPlay;
  final bool canShare;
  final bool canDelete;
  final String? deviceId;
  final String? deviceName;
  final DateTime? expiresAt;
  final RecordingLibraryIssue issue;

  bool get isCrossDevice =>
      storage == RecordingLibraryStorage.local && !canPlay && deviceName != null;

  bool isExpiringSoon(DateTime now) {
    final DateTime? expiry = expiresAt;
    if (expiry == null || !expiry.isAfter(now)) return false;
    return expiry.difference(now) <= const Duration(days: 3);
  }
}

RecordingLibraryItem libraryItemFromCloud(RecordingSummary recording) {
  final RecordingLibraryIssue issue = switch (recording.status) {
    RecordingStatus.missedNoCloudSlot =>
      RecordingLibraryIssue.missedNoCloudSlot,
    RecordingStatus.partial => RecordingLibraryIssue.partialTimeline,
    _ => RecordingLibraryIssue.none,
  };

  return RecordingLibraryItem(
    id: recording.id,
    creatorDisplayName: recording.creatorDisplayName,
    creatorHandle: recording.creatorUsername,
    storage: RecordingLibraryStorage.cloud,
    status: recording.status,
    startedAt: recording.startedAt,
    durationSeconds: recording.durationSeconds,
    sizeBytes: recording.sizeBytes ?? recording.bytesRecorded ?? 0,
    canPlay:
        recording.status == RecordingStatus.completed ||
        recording.status == RecordingStatus.partial ||
        recording.status == RecordingStatus.recovered,
    canShare: false,
    canDelete: recording.actions.canDelete,
    expiresAt: recording.expiresAt,
    issue: issue,
  );
}

RecordingLibraryItem libraryItemFromLocal(
  LocalRecordingSummary recording, {
  required String currentDeviceId,
}) {
  final bool sameDevice = recording.deviceId == currentDeviceId;
  final bool available = recording.fileAvailable;
  final RecordingLibraryIssue issue = !available
      ? RecordingLibraryIssue.missingLocalFile
      : recording.status == RecordingStatus.partial
      ? RecordingLibraryIssue.partialTimeline
      : RecordingLibraryIssue.none;

  return RecordingLibraryItem(
    id: recording.id,
    creatorDisplayName: recording.creatorDisplayName,
    creatorHandle: recording.creatorHandle,
    storage: RecordingLibraryStorage.local,
    status: recording.status,
    startedAt: recording.startedAt,
    durationSeconds: recording.recordedSeconds,
    sizeBytes: recording.sizeBytes,
    canPlay: sameDevice && available,
    canShare: sameDevice && available,
    canDelete: sameDevice,
    deviceId: recording.deviceId,
    deviceName: recording.deviceName,
    issue: issue,
  );
}

RecordingDeleteTarget deletionTargetFor({
  required bool hasLocal,
  required bool hasCloud,
}) {
  if (hasLocal && hasCloud) return RecordingDeleteTarget.both;
  if (hasLocal) return RecordingDeleteTarget.local;
  return RecordingDeleteTarget.cloud;
}
