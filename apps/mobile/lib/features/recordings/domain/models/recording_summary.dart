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

enum RecordingFilter { all, active, completed, failed }

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

class RecordingPage {
  const RecordingPage({required this.items, required this.nextCursor});

  final List<RecordingSummary> items;
  final String? nextCursor;
}

class RecordingSummary {
  const RecordingSummary({
    required this.id,
    required this.watchId,
    required this.creatorDisplayName,
    required this.creatorUsername,
    required this.status,
    required this.actions,
    required this.startedAt,
    required this.durationSeconds,
    this.sizeBytes,
    this.costCredits,
    this.bytesRecorded,
    this.progress,
    this.artifactReady = false,
    this.thumbnailReady = false,
    this.errorCode,
    this.errorMessage,
  });

  final String id;
  final String watchId;
  final String creatorDisplayName;
  final String creatorUsername;
  final RecordingStatus status;
  final RecordingActions actions;
  final DateTime? startedAt;
  final int durationSeconds;
  final int? sizeBytes;
  final double? costCredits;
  final int? bytesRecorded;
  final double? progress;
  final bool artifactReady;
  final bool thumbnailReady;
  final String? errorCode;
  final String? errorMessage;

  bool get isActiveLifecycle {
    return switch (status) {
      RecordingStatus.queued ||
      RecordingStatus.resolving ||
      RecordingStatus.waitingLive ||
      RecordingStatus.recording ||
      RecordingStatus.processing ||
      RecordingStatus.uploading ||
      RecordingStatus.stopRequested => true,
      RecordingStatus.completed ||
      RecordingStatus.failed ||
      RecordingStatus.stopped => false,
    };
  }

  RecordingSummary copyWith({
    RecordingStatus? status,
    RecordingActions? actions,
    int? durationSeconds,
    int? sizeBytes,
    double? costCredits,
    int? bytesRecorded,
    double? progress,
    bool? artifactReady,
    bool? thumbnailReady,
    String? errorCode,
    String? errorMessage,
  }) {
    return RecordingSummary(
      id: id,
      watchId: watchId,
      creatorDisplayName: creatorDisplayName,
      creatorUsername: creatorUsername,
      status: status ?? this.status,
      actions: actions ?? this.actions,
      startedAt: startedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      costCredits: costCredits ?? this.costCredits,
      bytesRecorded: bytesRecorded ?? this.bytesRecorded,
      progress: progress ?? this.progress,
      artifactReady: artifactReady ?? this.artifactReady,
      thumbnailReady: thumbnailReady ?? this.thumbnailReady,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
