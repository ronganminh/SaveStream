enum AppNotificationType {
  recordingStarted,
  recordingReady,
  recordingFailed,

  /// A notification kind this app version does not know yet.
  other,
}

/// V2 notification kinds added by the product contract.
///
/// Kept separate from [AppNotificationType] so Track C can map the new wire
/// values without forcing presentation changes before A6.
enum AppNotificationV2Type {
  creatorLive,
  recordingMissed,
  recordingExpiring,
  cloudMinutesExhausted,
  freeMinutesLow,
  purchaseCompleted,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.resourceType,
    this.resourceId,
    this.v2Type,
    this.kind = '',
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final String? resourceType;
  final String? resourceId;
  final AppNotificationV2Type? v2Type;

  /// The wire `type` as sent (`credits_low`, `recording_missed`, …), so kinds
  /// without an enum value still get their own icon and link. Empty when the
  /// notification was built without one; see [effectiveKind].
  final String kind;

  /// [kind], or the wire name of [type] / [v2Type] when [kind] is empty.
  String get effectiveKind {
    if (kind.isNotEmpty) return kind;
    return switch (v2Type) {
      AppNotificationV2Type.creatorLive => 'creator_live',
      AppNotificationV2Type.recordingMissed => 'recording_missed',
      AppNotificationV2Type.recordingExpiring => 'recording_expiring',
      AppNotificationV2Type.cloudMinutesExhausted => 'cloud_minutes_exhausted',
      AppNotificationV2Type.freeMinutesLow => 'free_minutes_low',
      AppNotificationV2Type.purchaseCompleted => 'purchase_completed',
      null => switch (type) {
        AppNotificationType.recordingStarted => 'recording_started',
        AppNotificationType.recordingReady => 'recording_ready',
        AppNotificationType.recordingFailed => 'recording_failed',
        AppNotificationType.other => '',
      },
    };
  }

  /// The Recording this notification points at, when it has one.
  String? get recordingId => resourceType == 'recording' ? resourceId : null;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      read: read ?? this.read,
      createdAt: createdAt,
      resourceType: resourceType,
      resourceId: resourceId,
      v2Type: v2Type,
      kind: kind,
    );
  }
}

class NotificationPage {
  const NotificationPage({required this.items, this.nextCursor});

  final List<AppNotification> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
