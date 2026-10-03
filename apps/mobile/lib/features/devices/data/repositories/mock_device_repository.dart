import '../../../../core/mock/mock_repository_base.dart';
import '../../domain/models/device_registration.dart';
import '../../domain/repositories/device_repository.dart';

final class MockDeviceRepository extends MockRepositoryBase
    implements DeviceRepository {
  MockDeviceRepository(super.behavior);

  final Map<String, DeviceRegistration> _items = <String, DeviceRegistration>{};

  @override
  Future<DeviceRegistration> register(DeviceRegistration device) {
    return respond<DeviceRegistration>(
      success: () {
        _items[device.deviceId] = device;
        return device;
      },
      empty: () => device,
    );
  }

  @override
  Future<void> unregister(String deviceId) {
    return respond<void>(success: () => _items.remove(deviceId), empty: () {});
  }
}
