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
  recordingExpiring,
  freeMinutesLow,
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
    );
  }
}

class NotificationPage {
  const NotificationPage({required this.items, this.nextCursor});

  final List<AppNotification> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
