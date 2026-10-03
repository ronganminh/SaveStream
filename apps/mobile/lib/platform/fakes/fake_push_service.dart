import 'dart:async';

import '../contracts/push_service.dart';

final class FakePushService implements PushService {
  FakePushService();

  final StreamController<String?> _tokens =
      StreamController<String?>.broadcast();
  final StreamController<PushOpenedMessage> _messages =
      StreamController<PushOpenedMessage>.broadcast();

  PushPermissionStatus _status = PushPermissionStatus.notDetermined;

  @override
  Future<PushPermissionStatus> get permissionStatus async => _status;

  @override
  Stream<PushOpenedMessage> get openedMessageStream => _messages.stream;

  @override
  Stream<String?> get tokenStream => _tokens.stream;

  @override
  Future<PushPermissionStatus> requestPermission() async {
    _status = PushPermissionStatus.granted;
    _tokens.add('fake-fcm-token');
    return _status;
  }
}
