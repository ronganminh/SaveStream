enum AppNotificationType {
  recordingStarted,
  recordingReady,
  recordingFailed,
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
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final String? resourceType;
  final String? resourceId;

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
    );
  }
}
