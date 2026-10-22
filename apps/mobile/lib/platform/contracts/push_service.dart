enum PushPermissionStatus { notDetermined, denied, granted }

class PushOpenedMessage {
  const PushOpenedMessage({required this.kind, this.resourceId});

  final String kind;
  final String? resourceId;
}

abstract interface class PushService {
  Future<PushPermissionStatus> get permissionStatus;

  Future<PushPermissionStatus> requestPermission();

  /// Opens the system notification settings for this app (Android 13+
  /// POST_NOTIFICATIONS can't be asked again once denied). False when the
  /// platform has no such screen.
  Future<bool> openSystemSettings();

  Stream<String?> get tokenStream;

  Stream<PushOpenedMessage> get openedMessageStream;
}
