/// `/v1/me/notification-preferences`.
///
/// The "push" switches (no prefix) decide whether the server creates the app
/// notification at all: the inbox entry and its push. The `email*` switches
/// decide the email copy. Kinds without a push switch (credits low, out of
/// minutes, missed LIVE) are always delivered in the app.
class NotificationPreferences {
  const NotificationPreferences({
    required this.recordingStarted,
    required this.recordingReady,
    required this.recordingFailed,
    this.creatorLive = true,
    this.recordingExpiring = true,
    this.freeMinutesLow = true,
    this.marketing = false,
    this.emailCreatorLive = true,
    this.emailRecordingReady = true,
    this.emailRecordingFailed = true,
    this.emailRecordingExpiring = true,
    this.emailCreditsLow = true,
    this.emailCreditsExhausted = true,
    this.emailSupported = true,
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

  /// Optional product and promotional messages (admin "marketing"
  /// broadcasts, in the app, by push and by email). Off unless chosen.
  final bool marketing;

  final bool emailCreatorLive;
  final bool emailRecordingReady;

  /// Also covers missed LIVEs (`recording_missed`).
  final bool emailRecordingFailed;
  final bool emailRecordingExpiring;
  final bool emailCreditsLow;
  final bool emailCreditsExhausted;

  /// False when the server has no email provider configured: the email
  /// switches are kept but nothing is sent.
  final bool emailSupported;

  NotificationPreferences copyWith({
    bool? recordingStarted,
    bool? recordingReady,
    bool? recordingFailed,
    bool? creatorLive,
    bool? recordingExpiring,
    bool? freeMinutesLow,
    bool? marketing,
    bool? emailCreatorLive,
    bool? emailRecordingReady,
    bool? emailRecordingFailed,
    bool? emailRecordingExpiring,
    bool? emailCreditsLow,
    bool? emailCreditsExhausted,
  }) {
    return NotificationPreferences(
      recordingStarted: recordingStarted ?? this.recordingStarted,
      recordingReady: recordingReady ?? this.recordingReady,
      recordingFailed: recordingFailed ?? this.recordingFailed,
      creatorLive: creatorLive ?? this.creatorLive,
      recordingExpiring: recordingExpiring ?? this.recordingExpiring,
      freeMinutesLow: freeMinutesLow ?? this.freeMinutesLow,
      marketing: marketing ?? this.marketing,
      emailCreatorLive: emailCreatorLive ?? this.emailCreatorLive,
      emailRecordingReady: emailRecordingReady ?? this.emailRecordingReady,
      emailRecordingFailed: emailRecordingFailed ?? this.emailRecordingFailed,
      emailRecordingExpiring:
          emailRecordingExpiring ?? this.emailRecordingExpiring,
      emailCreditsLow: emailCreditsLow ?? this.emailCreditsLow,
      emailCreditsExhausted:
          emailCreditsExhausted ?? this.emailCreditsExhausted,
      emailSupported: emailSupported,
    );
  }
}
