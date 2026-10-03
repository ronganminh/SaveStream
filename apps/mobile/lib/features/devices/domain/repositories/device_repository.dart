import '../models/device_registration.dart';

abstract interface class DeviceRepository {
  Future<DeviceRegistration> register(DeviceRegistration device);

  Future<void> unregister(String deviceId);
}
