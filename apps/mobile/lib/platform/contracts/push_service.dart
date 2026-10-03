enum PushPermissionStatus { notDetermined, denied, granted }

class PushOpenedMessage {
  const PushOpenedMessage({
    required this.kind,
    this.resourceId,
  });

  final String kind;
  final String? resourceId;
}

abstract interface class PushService {
  Future<PushPermissionStatus> get permissionStatus;

  Future<PushPermissionStatus> requestPermission();

  Stream<String?> get tokenStream;

  Stream<PushOpenedMessage> get openedMessageStream;
}
