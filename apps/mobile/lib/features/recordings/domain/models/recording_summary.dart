enum RecordingStatus {
  queued('queued'),
  resolving('resolving'),
  waitingLive('waiting_live'),
  recording('recording'),
  processing('processing'),
  uploading('uploading'),
  completed('completed'),
  failed('failed'),
  stopRequested('stop_requested'),
  stopped('stopped');

  const RecordingStatus(this.apiValue);

  final String apiValue;
}

class RecordingActions {
  const RecordingActions({
    required this.canStop,
    required this.canRetry,
    required this.canDelete,
  });

  final bool canStop;
  final bool canRetry;
  final bool canDelete;
}

class RecordingSummary {
  const RecordingSummary({
    required this.id,
    required this.watchId,
    required this.creatorDisplayName,
    required this.creatorUsername,
    required this.status,
    required this.actions,
  });

  final String id;
  final String watchId;
  final String creatorDisplayName;
  final String creatorUsername;
  final RecordingStatus status;
  final RecordingActions actions;
}
