import 'enums.dart';

class UsageSnapshot {
  const UsageSnapshot({
    required this.plan,
    this.freeMinutesLeft = 0,
    this.freeMinutesPool = 10,
    this.resetAt,
    this.adsUsed = 0,
    this.adsCap = 8,
    this.cloudHoursUsed = 0,
    this.cloudHoursLimit = 30,
    this.cloudPackHours = 0,
    this.watchCount = 0,
    this.watchLimit = 3,
    this.updatedAt,
  });

  final Plan plan;
  final int freeMinutesLeft, freeMinutesPool, adsUsed, adsCap, watchCount, watchLimit;
  final double cloudHoursUsed, cloudHoursLimit, cloudPackHours;
  final DateTime? resetAt, updatedAt;

  bool get freeExhausted => plan == Plan.free && freeMinutesLeft <= 0;
  CloudQuotaState get cloudQuota {
    final left = cloudHoursLimit - cloudHoursUsed + cloudPackHours;
    if (left <= 0) return CloudQuotaState.exhausted;
    if (left < 2) return CloudQuotaState.low;
    return CloudQuotaState.ok;
  }
}

class Creator {
  const Creator({
    required this.id,
    required this.name,
    required this.handle,
    required this.liveStatus,
    this.avatarUrl,
    this.notify = true,
    this.autoRecord = false,
    this.lastLiveLabel,
  });

  final String id, name, handle;
  final String? avatarUrl, lastLiveLabel;
  final LiveStatus liveStatus;
  final bool notify, autoRecord;

  String get initials {
    final p = name.trim().split(RegExp(r'\s+'));
    return (p.length > 1 ? p[0][0] + p[1][0] : name.substring(0, 2)).toUpperCase();
  }
}

class Recording {
  const Recording({
    required this.id,
    required this.creator,
    required this.title,
    required this.startedAt,
    required this.duration,
    required this.engine,
    required this.status,
    required this.copies,
    this.sizeBytes,
    this.expiresAt,
  });

  final String id, title;
  final Creator creator;
  final DateTime startedAt;
  final Duration duration;
  final Engine engine;
  final RecordingStatus status;
  final CopyLocation copies;
  final int? sizeBytes;
  final DateTime? expiresAt; // cloud: lưu 14 ngày
}

class ActiveRecording {
  const ActiveRecording({
    required this.sessionId,
    required this.creator,
    required this.engine,
    required this.status,
    required this.elapsed,
    this.bytes = 0,
  });

  final String sessionId;
  final Creator creator;
  final Engine engine;
  final RecordingStatus status;
  final Duration elapsed;
  final int bytes;

  ActiveRecording copyWith({RecordingStatus? status, Duration? elapsed, int? bytes}) => ActiveRecording(
        sessionId: sessionId,
        creator: creator,
        engine: engine,
        status: status ?? this.status,
        elapsed: elapsed ?? this.elapsed,
        bytes: bytes ?? this.bytes,
      );
}
