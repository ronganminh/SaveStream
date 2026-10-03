import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/devices/domain/models/device_registration.dart';
import 'contracts/device_info_service.dart';

typedef SecureValueReader = Future<String?> Function(String key);
typedef SecureValueWriter = Future<void> Function(String key, String value);
typedef DeviceNameLoader = Future<String> Function();
typedef FreeStorageLoader = Future<int> Function();

final class DeviceInfoPlusService implements DeviceInfoService {
  DeviceInfoPlusService({
    DeviceInfoPlugin? deviceInfo,
    FlutterSecureStorage? secureStorage,
    SecureValueReader? readSecureValue,
    SecureValueWriter? writeSecureValue,
    DeviceNameLoader? deviceNameLoader,
    FreeStorageLoader? freeStorageLoader,
    DevicePlatform? platformOverride,
  }) : _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _readSecureValue = readSecureValue,
       _writeSecureValue = writeSecureValue,
       _deviceNameLoader = deviceNameLoader,
       _freeStorageLoader = freeStorageLoader,
       _platformOverride = platformOverride;

  static const String _deviceIdKey = 'savestream.device_id';
  static const MethodChannel _deviceChannel = MethodChannel(
    'savestream/device_info',
  );

  final DeviceInfoPlugin _deviceInfo;
  final FlutterSecureStorage _secureStorage;
  final SecureValueReader? _readSecureValue;
  final SecureValueWriter? _writeSecureValue;
  final DeviceNameLoader? _deviceNameLoader;
  final FreeStorageLoader? _freeStorageLoader;
  final DevicePlatform? _platformOverride;

  @override
  DevicePlatform get platform {
    final DevicePlatform? override = _platformOverride;
    if (override != null) {
      return override;
    }
    if (Platform.isAndroid) {
      return DevicePlatform.android;
    }
    if (Platform.isIOS) {
      return DevicePlatform.ios;
    }
    throw UnsupportedError('SaveStream mobile supports Android and iOS only.');
  }

  @override
  Future<String> get deviceId async {
    final SecureValueReader reader =
        _readSecureValue ??
        (String key) => _secureStorage.read(key: key);
    final SecureValueWriter writer =
        _writeSecureValue ??
        (String key, String value) {
          return _secureStorage.write(key: key, value: value);
        };

    final String? stored = await reader(_deviceIdKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    final String generated = _generateDeviceId();
    await writer(_deviceIdKey, generated);
    return generated;
  }

  @override
  Future<String> get deviceName async {
    final DeviceNameLoader? loader = _deviceNameLoader;
    if (loader != null) {
      return loader();
    }

    switch (platform) {
      case DevicePlatform.android:
        final AndroidDeviceInfo info = await _deviceInfo.androidInfo;
        final String manufacturer = info.manufacturer.trim();
        final String model = info.model.trim();
        if (manufacturer.isEmpty) {
          return model;
        }
        if (model.isEmpty) {
          return manufacturer;
        }
        return '$manufacturer $model';
      case DevicePlatform.ios:
        final IosDeviceInfo info = await _deviceInfo.iosInfo;
        final String name = info.name.trim();
        if (name.isNotEmpty) {
          return name;
        }
        return info.utsname.machine.trim();
    }
  }

  @override
  Future<int> get freeStorageBytes async {
    final FreeStorageLoader? loader = _freeStorageLoader;
    if (loader != null) {
      return loader();
    }

    final num? freeBytes = await _deviceChannel.invokeMethod<num>(
      'freeStorageBytes',
    );
    return freeBytes?.toInt() ?? 0;
  }

  static String _generateDeviceId() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(
      16,
      (int index) => random.nextInt(256),
      growable: false,
    );
    final String encoded = bytes
        .map((int value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'dev_$encoded';
  }
}
