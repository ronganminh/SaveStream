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
    this.ownerAttested = false,
  });

  final WatchSourceType sourceType;
  final String sourceValue;
  final bool autoRecord;
  final bool notifyOnLive;

  /// "I own or manage this account and I'm allowed to record its LIVEs."
  final bool ownerAttested;
}

enum CreatorLiveStatus {
  unknown('unknown'),
  offline('offline'),
  live('live');

  const CreatorLiveStatus(this.apiValue);

  final String apiValue;
}

class CreatorLookupResult {
  const CreatorLookupResult({
    required this.username,
    required this.displayName,
    required this.liveStatus,
    this.avatarUrl,
    this.roomId,
    this.checkedAt,
  });

  final String username;
  final String displayName;
  final String? avatarUrl;
  final CreatorLiveStatus liveStatus;
  final String? roomId;
  final DateTime? checkedAt;

  bool get isLive => liveStatus == CreatorLiveStatus.live;
}

class WatchSummary {
  const WatchSummary({
    required this.id,
    required this.creatorDisplayName,
    required this.creatorUsername,
    this.creatorAvatarUrl,
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
    this.activeRecordingId,
    this.verificationRequired = false,
    this.verificationDueAt,
    this.ownerVerifiedAt,
  });

  final String id;
  final String creatorDisplayName;
  final String creatorUsername;
  final String? creatorAvatarUrl;
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

  /// Set while a recording job for this channel is in flight.
  final String? activeRecordingId;

  /// True when this channel can't be recorded until ownership is verified.
  final bool verificationRequired;
  final DateTime? verificationDueAt;
  final DateTime? ownerVerifiedAt;

  /// True once the owner proved the channel is theirs (code in the bio).
  bool get isOwnerVerified => ownerVerifiedAt != null;

  WatchSummary copyWith({
    String? creatorDisplayName,
    String? creatorUsername,
    String? creatorAvatarUrl,
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
    DateTime? ownerVerifiedAt,
  }) {
    return WatchSummary(
      id: id,
      creatorDisplayName: creatorDisplayName ?? this.creatorDisplayName,
      creatorUsername: creatorUsername ?? this.creatorUsername,
      creatorAvatarUrl: creatorAvatarUrl ?? this.creatorAvatarUrl,
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
      activeRecordingId: activeRecordingId,
      verificationRequired: verificationRequired,
      verificationDueAt: verificationDueAt,
      ownerVerifiedAt: ownerVerifiedAt ?? this.ownerVerifiedAt,
    );
  }
}
