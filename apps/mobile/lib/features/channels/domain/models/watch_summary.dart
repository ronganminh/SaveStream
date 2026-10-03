enum AutoRecordState {
  off('off'),
  active('active'),
  pausedNoCloudMinutes('paused_no_cloud_minutes'),
  waitingForCloudSlot('waiting_for_cloud_slot');

  const AutoRecordState(this.apiValue);

  final String apiValue;
}

enum WatchStatus {
  active('active'),
  paused('paused'),
  pausedInsufficientCredit('paused_insufficient_credit'),
  pausedError('paused_error'),
  disabled('disabled');

  const WatchStatus(this.apiValue);

  final String apiValue;
}

enum WatchSourceType {
  username('username'),
  roomId('room_id'),
  url('url');

  const WatchSourceType(this.apiValue);

  final String apiValue;
}

class CreateWatchCommand {
  const CreateWatchCommand({
    required this.sourceType,
    required this.sourceValue,
    required this.autoRecord,
    this.notifyOnLive = true,
  });

  final WatchSourceType sourceType;
  final String sourceValue;
  final bool autoRecord;
  final bool notifyOnLive;
}

class WatchSummary {
  const WatchSummary({
    required this.id,
    required this.creatorDisplayName,
    required this.creatorUsername,
    required this.status,
    required this.isLive,
    this.sourceType,
    this.sourceValue,
    this.autoRecord = true,
    this.notifyOnLive = true,
    this.autoRecordState = AutoRecordState.off,
    this.lastCheckedAt,
    this.nextCheckAt,
    this.lastLiveAt,
  });

  final String id;
  final String creatorDisplayName;
  final String creatorUsername;
  final WatchStatus status;
  final bool isLive;
  final WatchSourceType? sourceType;
  final String? sourceValue;
  final bool autoRecord;
  final bool notifyOnLive;
  final AutoRecordState autoRecordState;
  final DateTime? lastCheckedAt;
  final DateTime? nextCheckAt;
  final DateTime? lastLiveAt;

  WatchSummary copyWith({
    String? creatorDisplayName,
    String? creatorUsername,
    WatchStatus? status,
    bool? isLive,
    WatchSourceType? sourceType,
    String? sourceValue,
    bool? autoRecord,
    bool? notifyOnLive,
    AutoRecordState? autoRecordState,
    DateTime? lastCheckedAt,
    DateTime? nextCheckAt,
    DateTime? lastLiveAt,
  }) {
    return WatchSummary(
      id: id,
      creatorDisplayName: creatorDisplayName ?? this.creatorDisplayName,
      creatorUsername: creatorUsername ?? this.creatorUsername,
      status: status ?? this.status,
      isLive: isLive ?? this.isLive,
      sourceType: sourceType ?? this.sourceType,
      sourceValue: sourceValue ?? this.sourceValue,
      autoRecord: autoRecord ?? this.autoRecord,
      notifyOnLive: notifyOnLive ?? this.notifyOnLive,
      autoRecordState: autoRecordState ?? this.autoRecordState,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      nextCheckAt: nextCheckAt ?? this.nextCheckAt,
      lastLiveAt: lastLiveAt ?? this.lastLiveAt,
    );
  }
}
