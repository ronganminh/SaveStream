import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/devices/domain/models/device_registration.dart';
import 'package:savestream_mobile/platform/connectivity_plus_service.dart';
import 'package:savestream_mobile/platform/device_info_plus_service.dart';

void main() {
  group('ConnectivityPlusService', () {
    test('emits initial state and distinct connectivity changes', () async {
      final StreamController<List<ConnectivityResult>> changes =
          StreamController<List<ConnectivityResult>>();
      addTearDown(changes.close);

      final ConnectivityPlusService service = ConnectivityPlusService(
        checkConnectivity: () async => <ConnectivityResult>[
          ConnectivityResult.none,
        ],
        connectivityChanges: changes.stream,
      );

      final List<bool> values = <bool>[];
      final StreamSubscription<bool> subscription = service.online.listen(
        values.add,
      );
      addTearDown(subscription.cancel);

      await Future<void>.delayed(Duration.zero);
      changes.add(<ConnectivityResult>[ConnectivityResult.wifi]);
      changes.add(<ConnectivityResult>[ConnectivityResult.mobile]);
      changes.add(<ConnectivityResult>[ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);

      expect(values, <bool>[false, true, false]);
    });
  });

  group('DeviceInfoPlusService', () {
    test('creates one stable secure device id', () async {
      final Map<String, String> secureValues = <String, String>{};
      final DeviceInfoPlusService service = DeviceInfoPlusService(
        platformOverride: DevicePlatform.android,
        readSecureValue: (String key) async => secureValues[key],
        writeSecureValue: (String key, String value) async {
          secureValues[key] = value;
        },
        deviceNameLoader: () async => 'Pixel test device',
        freeStorageLoader: () async => 1024,
      );

      final String first = await service.deviceId;
      final String second = await service.deviceId;

      expect(first, startsWith('dev_'));
      expect(first.length, 36);
      expect(second, first);
      expect(secureValues.values.single, first);
    });

    test('uses injected native device values', () async {
      final DeviceInfoPlusService service = DeviceInfoPlusService(
        platformOverride: DevicePlatform.ios,
        readSecureValue: (String key) async => 'dev_existing',
        writeSecureValue: (String key, String value) async {},
        deviceNameLoader: () async => 'iPhone test device',
        freeStorageLoader: () async => 4096,
      );

      expect(service.platform, DevicePlatform.ios);
      expect(await service.deviceId, 'dev_existing');
      expect(await service.deviceName, 'iPhone test device');
      expect(await service.freeStorageBytes, 4096);
    });
  });
}
