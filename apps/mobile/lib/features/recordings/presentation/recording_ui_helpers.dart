import 'package:flutter/material.dart';

import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/recording_summary.dart';

String recordingStatusLabel(AppLocalizations l10n, RecordingStatus status) {
  return switch (status) {
    RecordingStatus.queued => l10n.recordingStatusQueued,
    RecordingStatus.resolving => l10n.recordingStatusResolving,
    RecordingStatus.waitingLive => l10n.recordingStatusWaitingLive,
    RecordingStatus.recording => l10n.recordingStatusRecording,
    RecordingStatus.processing => l10n.recordingStatusProcessing,
    RecordingStatus.uploading => l10n.recordingStatusUploading,
    RecordingStatus.completed => l10n.recordingStatusCompleted,
    RecordingStatus.failed => l10n.recordingStatusFailed,
    RecordingStatus.stopRequested => l10n.recordingStatusStopRequested,
    RecordingStatus.stopped => l10n.recordingStatusStopped,
  };
}

String recordingStatusDescription(
  AppLocalizations l10n,
  RecordingStatus status,
) {
  return switch (status) {
    RecordingStatus.queued => l10n.recordingQueuedBody,
    RecordingStatus.resolving => l10n.recordingResolvingBody,
    RecordingStatus.waitingLive => l10n.recordingWaitingLiveBody,
    RecordingStatus.recording => l10n.recordingActiveBody,
    RecordingStatus.processing => l10n.recordingProcessingBody,
    RecordingStatus.uploading => l10n.recordingUploadingBody,
    RecordingStatus.completed => l10n.recordingCompletedBody,
    RecordingStatus.failed => l10n.recordingFailedBody,
    RecordingStatus.stopRequested => l10n.recordingStopRequestedBody,
    RecordingStatus.stopped => l10n.recordingStoppedBody,
  };
}

SsStatusTone recordingStatusTone(RecordingStatus status) {
  return switch (status) {
    RecordingStatus.recording => SsStatusTone.recording,
    RecordingStatus.completed => SsStatusTone.success,
    RecordingStatus.failed => SsStatusTone.error,
    RecordingStatus.stopRequested => SsStatusTone.warning,
    RecordingStatus.stopped => SsStatusTone.warning,
    RecordingStatus.queued ||
    RecordingStatus.resolving ||
    RecordingStatus.waitingLive ||
    RecordingStatus.processing ||
    RecordingStatus.uploading => SsStatusTone.neutral,
  };
}

String recordingFilterLabel(AppLocalizations l10n, RecordingFilter filter) {
  return switch (filter) {
    RecordingFilter.all => l10n.recordingFilterAll,
    RecordingFilter.active => l10n.recordingFilterActive,
    RecordingFilter.completed => l10n.recordingFilterCompleted,
    RecordingFilter.failed => l10n.recordingFilterFailed,
  };
}

String recordingTimestamp(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.notStartedLabel;
  }
  final MaterialLocalizations material = MaterialLocalizations.of(context);
  final DateTime local = value.toLocal();
  return material.formatMediumDate(local) +
      ' · ' +
      material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
}

String formatDuration(int seconds) {
  final int hours = seconds ~/ 3600;
  final int minutes = (seconds % 3600) ~/ 60;
  final int remaining = seconds % 60;
  if (hours > 0) {
    return '${hours}h ${minutes}m ${remaining}s';
  }
  if (minutes > 0) {
    return '${minutes}m ${remaining}s';
  }
  return '${remaining}s';
}

String formatBytes(int? bytes) {
  if (bytes == null) {
    return '—';
  }
  const double kb = 1024;
  const double mb = kb * 1024;
  const double gb = mb * 1024;
  if (bytes >= gb) {
    return '${(bytes / gb).toStringAsFixed(1)} GB';
  }
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(0)} MB';
  }
  if (bytes >= kb) {
    return '${(bytes / kb).toStringAsFixed(0)} KB';
  }
  return '$bytes B';
}

String formatCredits(double? credits) {
  if (credits == null) {
    return '—';
  }
  return credits.toStringAsFixed(1);
}
