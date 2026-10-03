import '../../../entitlement/domain/models/entitlement.dart';

enum RecordingStatus {
  starting('starting'),
  queued('queued'),
  resolving('resolving'),
  waitingLive('waiting_live'),
  waitingForCloudSlot('waiting_for_cloud_slot'),
  recording('recording'),
  reconnecting('reconnecting'),
  processing('processing'),
  uploading('uploading'),
  finalizing('finalizing'),
  completed('completed'),
  partial('partial'),
  recovered('recovered'),
  failed('failed'),
  stopRequested('stop_requested'),
  stopped('stopped'),
  missedNoCloudSlot('missed_no_cloud_slot');

  const RecordingStatus(this.apiValue);

  final String apiValue;
}

enum RecordingSourceType {
  username('username'),
  roomId('room_id'),
  url('url');

  const RecordingSourceType(this.apiValue);

  final String apiValue;
}

enum RecordingFilter { all, active, completed, failed }

class CreateRecordingCommand {
  const CreateRecordingCommand({
    required this.sourceType,
    required this.sourceValue,
    this.maxDurationSeconds,
  });

  final RecordingSourceType sourceType;
  final String sourceValue;
  final int? maxDurationSeconds;
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

class RecordingArtifactSummary {
  const RecordingArtifactSummary({
    required this.id,
    required this.recordingId,
    required this.sizeBytes,
    required this.checksumSha256,
    required this.createdAt,
  });

  final String id;
  final String recordingId;
  final int sizeBytes;
  final String checksumSha256;
  final DateTime createdAt;
}

class ArtifactDownloadUrl {
  const ArtifactDownloadUrl({required this.uri, required this.expiresAt});

  final Uri uri;
  final DateTime expiresAt;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());
}

class RecordingEvent {
  const RecordingEvent({
    required this.id,
    required this.sequence,
    required this.type,
    required this.recordingId,
    required this.createdAt,
    required this.status,
    required this.durationSeconds,
    required this.bytesRecorded,
  });

  final String id;
  final int sequence;
  final String type;
  final String recordingId;
  final DateTime createdAt;
  final RecordingStatus status;
  final int durationSeconds;
  final int bytesRecorded;
}

class RecordingPage {
  const RecordingPage({required this.items, required this.nextCursor});

  final List<RecordingSummary> items;
  final String? nextCursor;
}

class RecordingSummary {
  const RecordingSummary({
    required this.id,
    required this.creatorDisplayName,
    required this.creatorUsername,
    required this.status,
    required this.actions,
    required this.startedAt,
    required this.durationSeconds,
    this.watchId,
    this.sourceType = RecordingSourceType.username,
    this.sourceValue = '',
    this.endedAt,
    this.sizeBytes,
    this.costCredits,
    this.bytesRecorded,
    this.progress,
    this.artifactReady = false,
    this.thumbnailReady = false,
    this.errorCode,
    this.errorMessage,
    this.engine = Engine.cloud,
    this.expiresAt,
    this.minutesCharged = 0,
    this.queuePosition,
  });

  final String id;
  final String? watchId;
  final RecordingSourceType sourceType;
  final String sourceValue;
  final String creatorDisplayName;
  final String creatorUsername;
  final RecordingStatus status;
  final RecordingActions actions;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final int? sizeBytes;
  final double? costCredits;
  final int? bytesRecorded;
  final double? progress;
  final bool artifactReady;
  final bool thumbnailReady;
  final String? errorCode;
  final String? errorMessage;
  final Engine engine;
  final DateTime? expiresAt;
  final int minutesCharged;
  final int? queuePosition;

  bool get isActiveLifecycle {
    return switch (status) {
      RecordingStatus.starting ||
      RecordingStatus.queued ||
      RecordingStatus.resolving ||
      RecordingStatus.waitingLive ||
      RecordingStatus.waitingForCloudSlot ||
      RecordingStatus.recording ||
      RecordingStatus.reconnecting ||
      RecordingStatus.processing ||
      RecordingStatus.uploading ||
      RecordingStatus.finalizing ||
      RecordingStatus.stopRequested => true,
      RecordingStatus.completed ||
      RecordingStatus.partial ||
      RecordingStatus.recovered ||
      RecordingStatus.failed ||
      RecordingStatus.stopped ||
      RecordingStatus.missedNoCloudSlot => false,
    };
  }

  RecordingSummary copyWith({
    String? watchId,
    RecordingStatus? status,
    RecordingActions? actions,
    DateTime? endedAt,
    int? durationSeconds,
    int? sizeBytes,
    double? costCredits,
    int? bytesRecorded,
    double? progress,
    bool? artifactReady,
    bool? thumbnailReady,
    String? errorCode,
    String? errorMessage,
    Engine? engine,
    DateTime? expiresAt,
    int? minutesCharged,
    int? queuePosition,
  }) {
    return RecordingSummary(
      id: id,
      watchId: watchId ?? this.watchId,
      sourceType: sourceType,
      sourceValue: sourceValue,
      creatorDisplayName: creatorDisplayName,
      creatorUsername: creatorUsername,
      status: status ?? this.status,
      actions: actions ?? this.actions,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      costCredits: costCredits ?? this.costCredits,
      bytesRecorded: bytesRecorded ?? this.bytesRecorded,
      progress: progress ?? this.progress,
      artifactReady: artifactReady ?? this.artifactReady,
      thumbnailReady: thumbnailReady ?? this.thumbnailReady,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      engine: engine ?? this.engine,
      expiresAt: expiresAt ?? this.expiresAt,
      minutesCharged: minutesCharged ?? this.minutesCharged,
      queuePosition: queuePosition ?? this.queuePosition,
    );
  }
}
