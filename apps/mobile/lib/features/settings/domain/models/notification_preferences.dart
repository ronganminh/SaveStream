class NotificationPreferences {
  const NotificationPreferences({
    required this.recordingStarted,
    required this.recordingReady,
    required this.recordingFailed,
    this.creatorLive = true,
    this.recordingExpiring = true,
    this.freeMinutesLow = true,
  });

  final bool recordingStarted;
  final bool recordingReady;
  final bool recordingFailed;

  /// Master preference for LIVE push notifications.
  ///
  /// A Watch may additionally disable LIVE pushes with its own
  /// `notifyOnLive` flag. Both switches must allow the push.
  final bool creatorLive;

  /// Alerts when a cloud recording is close to its retention expiry.
  final bool recordingExpiring;

  /// Alerts when Free recording minutes are close to running out.
  final bool freeMinutesLow;

  NotificationPreferences copyWith({
    bool? recordingStarted,
    bool? recordingReady,
    bool? recordingFailed,
    bool? creatorLive,
    bool? recordingExpiring,
    bool? freeMinutesLow,
  }) {
    return NotificationPreferences(
      recordingStarted: recordingStarted ?? this.recordingStarted,
      recordingReady: recordingReady ?? this.recordingReady,
      recordingFailed: recordingFailed ?? this.recordingFailed,
      creatorLive: creatorLive ?? this.creatorLive,
      recordingExpiring: recordingExpiring ?? this.recordingExpiring,
      freeMinutesLow: freeMinutesLow ?? this.freeMinutesLow,
    );
  }
}
