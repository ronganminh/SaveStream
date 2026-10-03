import '../../features/devices/domain/models/device_registration.dart';
import '../contracts/device_info_service.dart';

final class FakeDeviceInfoService implements DeviceInfoService {
  const FakeDeviceInfoService({
    this.platform = DevicePlatform.android,
    this.id = 'dev_fake',
    this.name = 'Mock device',
    this.storageBytes = 20 * 1024 * 1024 * 1024,
  });

  @override
  final DevicePlatform platform;

  final String id;
  final String name;
  final int storageBytes;

  @override
  Future<String> get deviceId async => id;

  @override
  Future<String> get deviceName async => name;

  @override
  Future<int> get freeStorageBytes async => storageBytes;
}
