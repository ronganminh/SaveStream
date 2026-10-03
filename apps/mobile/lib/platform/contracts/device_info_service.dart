import '../../features/devices/domain/models/device_registration.dart';

abstract interface class DeviceInfoService {
  Future<String> get deviceId;

  Future<String> get deviceName;

  Future<int> get freeStorageBytes;

  DevicePlatform get platform;
}
