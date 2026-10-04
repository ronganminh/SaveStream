import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/models/device_registration.dart';
import '../../domain/repositories/device_repository.dart';

final class ApiDeviceRepository implements DeviceRepository {
  const ApiDeviceRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<DeviceRegistration> register(DeviceRegistration device) async {
    try {
      final response = await _apiClient.put<DeviceRegistration>(
        '/v1/me/devices/${Uri.encodeComponent(device.deviceId)}',
        data: <String, Object?>{
          'platform': switch (device.platform) {
            DevicePlatform.android => 'android',
            DevicePlatform.ios => 'ios',
          },
          'push_token': device.pushToken,
          'device_name': device.deviceName,
          'app_version': device.appVersion,
          'locale': device.locale,
        },
        decoder: (_) => device,
      );
      return response.data;
    } on ApiException catch (error) {
      if (error.statusCode == 501 || error.code == 'NOT_IMPLEMENTED') {
        return device;
      }
      rethrow;
    }
  }

  @override
  Future<void> unregister(String deviceId) async {
    try {
      await _apiClient.delete<Object?>(
        '/v1/me/devices/${Uri.encodeComponent(deviceId)}',
        decoder: (_) => null,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 501 || error.code == 'NOT_IMPLEMENTED') {
        return;
      }
      rethrow;
    }
  }
}
