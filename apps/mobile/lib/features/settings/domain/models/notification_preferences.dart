class NotificationPreferences {
  const NotificationPreferences({
    required this.recordingStarted,
    required this.recordingReady,
    required this.recordingFailed,
  });

  final bool recordingStarted;
  final bool recordingReady;
  final bool recordingFailed;

  NotificationPreferences copyWith({
    bool? recordingStarted,
    bool? recordingReady,
    bool? recordingFailed,
  }) {
    return NotificationPreferences(
      recordingStarted: recordingStarted ?? this.recordingStarted,
      recordingReady: recordingReady ?? this.recordingReady,
      recordingFailed: recordingFailed ?? this.recordingFailed,
    );
  }
}
