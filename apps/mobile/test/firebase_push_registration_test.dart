import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/features/devices/domain/models/device_registration.dart';
import 'package:savestream_mobile/features/devices/domain/repositories/device_repository.dart';
import 'package:savestream_mobile/platform/contracts/push_service.dart';
import 'package:savestream_mobile/platform/fakes/fake_device_info_service.dart';
import 'package:savestream_mobile/platform/push_token_registration_coordinator.dart';

void main() {
  test(
    'registers the current FCM token for an authenticated session',
    () async {
      final AppSessionController session = AppSessionController();
      final AppSettingsController settings = AppSettingsController(
        locale: const Locale('vi'),
      );
      final _TestPushService push = _TestPushService();
      final _RecordingDeviceRepository repository =
          _RecordingDeviceRepository();
      final PushTokenRegistrationCoordinator coordinator =
          PushTokenRegistrationCoordinator(
            session: session,
            settings: settings,
            pushService: push,
            deviceInfoService: const FakeDeviceInfoService(
              id: 'dev-1',
              name: 'Pixel',
            ),
            deviceRepository: repository,
            appVersionLoader: () async => '2.0.0',
          )..start();

      push.emitToken('fcm-token-1');
      await pumpEventQueue();

      expect(repository.registered, hasLength(1));
      final DeviceRegistration device = repository.registered.single;
      expect(device.deviceId, 'dev-1');
      expect(device.pushToken, 'fcm-token-1');
      expect(device.locale, 'vi');
      expect(device.appVersion, '2.0.0');

      await coordinator.dispose();
      await push.dispose();
    },
  );

  test('token refresh updates the same device registration', () async {
    final AppSessionController session = AppSessionController();
    final _TestPushService push = _TestPushService();
    final _RecordingDeviceRepository repository = _RecordingDeviceRepository();
    final PushTokenRegistrationCoordinator coordinator =
        PushTokenRegistrationCoordinator(
          session: session,
          settings: AppSettingsController(),
          pushService: push,
          deviceInfoService: const FakeDeviceInfoService(id: 'dev-1'),
          deviceRepository: repository,
          appVersionLoader: () async => '2.0.0',
        )..start();

    push.emitToken('token-a');
    await pumpEventQueue();
    push.emitToken('token-b');
    await pumpEventQueue();

    expect(
      repository.registered.map((DeviceRegistration item) => item.pushToken),
      <String?>['token-a', 'token-b'],
    );

    await coordinator.dispose();
    await push.dispose();
  });

  test(
    'login registers the latest snapshot without prompting for push',
    () async {
      final AppSessionController session = AppSessionController(
        authStatus: AppAuthStatus.unauthenticated,
      );
      final _TestPushService push = _TestPushService();
      final _RecordingDeviceRepository repository =
          _RecordingDeviceRepository();
      final PushTokenRegistrationCoordinator coordinator =
          PushTokenRegistrationCoordinator(
            session: session,
            settings: AppSettingsController(),
            pushService: push,
            deviceInfoService: const FakeDeviceInfoService(id: 'dev-1'),
            deviceRepository: repository,
            appVersionLoader: () async => '2.0.0',
          )..start();

      push.emitToken(null);
      await pumpEventQueue();
      expect(repository.registered, isEmpty);

      session.markAuthenticated();
      await pumpEventQueue();

      expect(repository.registered, hasLength(1));
      expect(repository.registered.single.pushToken, isNull);

      await coordinator.dispose();
      await push.dispose();
    },
  );
}

final class _TestPushService implements PushService {
  final StreamController<String?> _tokens =
      StreamController<String?>.broadcast();

  void emitToken(String? token) => _tokens.add(token);

  Future<void> dispose() => _tokens.close();

  @override
  Future<PushPermissionStatus> get permissionStatus async =>
      PushPermissionStatus.granted;

  @override
  Stream<PushOpenedMessage> get openedMessageStream =>
      const Stream<PushOpenedMessage>.empty();

  @override
  Future<PushPermissionStatus> requestPermission() async =>
      PushPermissionStatus.granted;

  @override
  Stream<String?> get tokenStream => _tokens.stream;
}

final class _RecordingDeviceRepository implements DeviceRepository {
  final List<DeviceRegistration> registered = <DeviceRegistration>[];

  @override
  Future<DeviceRegistration> register(DeviceRegistration device) async {
    registered.add(device);
    return device;
  }

  @override
  Future<void> unregister(String deviceId) async {}
}
