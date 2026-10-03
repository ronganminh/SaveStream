import '../../../recordings/domain/models/recording_summary.dart';

enum LocalStreamFormat { flv, hls }

enum RecordingEndReason {
  userStopped,
  liveEnded,
  freeMinutesExhausted,
  storageLow,
  interrupted,
  error,
}

class LocalRecordingSession {
  const LocalRecordingSession({
    required this.sessionId,
    required this.watchId,
    required this.deviceId,
    required this.grantedSeconds,
    required this.leaseExpiresAt,
    required this.streamUrl,
    required this.streamFormat,
    this.streamHeaders = const <String, String>{},
  });

  final String sessionId;
  final String watchId;
  final String deviceId;
  final int grantedSeconds;
  final DateTime leaseExpiresAt;
  final Uri streamUrl;
  final LocalStreamFormat streamFormat;
  final Map<String, String> streamHeaders;

  LocalRecordingSession copyWith({
    int? grantedSeconds,
    DateTime? leaseExpiresAt,
    Uri? streamUrl,
    LocalStreamFormat? streamFormat,
    Map<String, String>? streamHeaders,
  }) {
    return LocalRecordingSession(
      sessionId: sessionId,
      watchId: watchId,
      deviceId: deviceId,
      grantedSeconds: grantedSeconds ?? this.grantedSeconds,
      leaseExpiresAt: leaseExpiresAt ?? this.leaseExpiresAt,
      streamUrl: streamUrl ?? this.streamUrl,
      streamFormat: streamFormat ?? this.streamFormat,
      streamHeaders: streamHeaders ?? this.streamHeaders,
    );
  }
}

class LocalRecordingSummary {
  const LocalRecordingSummary({
    required this.id,
    required this.watchId,
    required this.creatorDisplayName,
    required this.creatorHandle,
    required this.deviceId,
    required this.deviceName,
    required this.startedAt,
    required this.recordedSeconds,
    required this.sizeBytes,
    required this.status,
  });

  final String id;
  final String watchId;
  final String creatorDisplayName;
  final String creatorHandle;
  final String deviceId;
  final String deviceName;
  final DateTime startedAt;
  final int recordedSeconds;
  final int sizeBytes;
  final RecordingStatus status;
}
