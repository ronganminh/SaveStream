import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'contracts/push_service.dart';
import 'push_runtime.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

final class FirebasePushService implements PushService {
  FirebasePushService({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;
  final StreamController<String?> _tokens =
      StreamController<String?>.broadcast();
  final StreamController<PushOpenedMessage> _openedMessages =
      StreamController<PushOpenedMessage>.broadcast();
  final StreamController<ForegroundPushMessage> _foregroundMessages =
      StreamController<ForegroundPushMessage>.broadcast();
  final StreamController<ForegroundPushMessage> _runtimeOpenedMessages =
      StreamController<ForegroundPushMessage>.broadcast();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  PushOpenedMessage? _initialOpenedMessage;
  ForegroundPushMessage? _initialRuntimeOpenedMessage;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(_tokens.add);
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) =>
          _foregroundMessages.add(_mapRuntimeMessage(message)),
    );
    _openedMessageSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      RemoteMessage message,
    ) {
      _openedMessages.add(_mapMessage(message));
      _runtimeOpenedMessages.add(_mapRuntimeMessage(message));
    });

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _initialOpenedMessage = _mapMessage(initialMessage);
      _initialRuntimeOpenedMessage = _mapRuntimeMessage(initialMessage);
    }

    if (await permissionStatus == PushPermissionStatus.granted) {
      await _emitCurrentToken();
    } else {
      _tokens.add(null);
    }
  }

  @override
  Future<PushPermissionStatus> get permissionStatus async {
    final NotificationSettings settings = await _messaging
        .getNotificationSettings();
    return _mapPermission(settings.authorizationStatus);
  }

  @override
  Future<PushPermissionStatus> requestPermission() async {
    final NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final PushPermissionStatus status = _mapPermission(
      settings.authorizationStatus,
    );
    if (status == PushPermissionStatus.granted) {
      await _emitCurrentToken();
    } else {
      _tokens.add(null);
    }
    return status;
  }

  @override
  Stream<String?> get tokenStream => _tokens.stream;

  Stream<ForegroundPushMessage> get foregroundMessageStream =>
      _foregroundMessages.stream;

  Stream<ForegroundPushMessage> get runtimeOpenedMessageStream async* {
    final ForegroundPushMessage? initial = _initialRuntimeOpenedMessage;
    if (initial != null) {
      _initialRuntimeOpenedMessage = null;
      yield initial;
    }
    yield* _runtimeOpenedMessages.stream;
  }

  @override
  Stream<PushOpenedMessage> get openedMessageStream async* {
    final PushOpenedMessage? initial = _initialOpenedMessage;
    if (initial != null) {
      _initialOpenedMessage = null;
      yield initial;
    }
    yield* _openedMessages.stream;
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _openedMessageSubscription?.cancel();
    await _tokens.close();
    await _openedMessages.close();
    await _foregroundMessages.close();
    await _runtimeOpenedMessages.close();
  }

  Future<void> _emitCurrentToken() async {
    try {
      _tokens.add(await _messaging.getToken());
    } on FirebaseException {
      // On iOS the APNs token can still be unavailable immediately after
      // permission is granted. onTokenRefresh will deliver the FCM token later.
    }
  }

  static PushPermissionStatus _mapPermission(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => PushPermissionStatus.granted,
      AuthorizationStatus.denied ||
      AuthorizationStatus.deniedPermanently => PushPermissionStatus.denied,
      AuthorizationStatus.notDetermined => PushPermissionStatus.notDetermined,
    };
  }

  static PushOpenedMessage _mapMessage(RemoteMessage message) {
    return PushOpenedMessage(
      kind: message.data['type'] ?? 'unknown',
      resourceId: message.data['resource_id'],
    );
  }

  static ForegroundPushMessage _mapRuntimeMessage(RemoteMessage message) {
    return ForegroundPushMessage(
      title: message.notification?.title ?? 'SaveStream',
      body: message.notification?.body ?? '',
      kind: message.data['type'] ?? 'unknown',
      resourceType: message.data['resource_type'],
      resourceId: message.data['resource_id'],
    );
  }
}
