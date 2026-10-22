enum DevicePlatform { android, ios }

class DeviceRegistration {
  const DeviceRegistration({
    required this.deviceId,
    required this.platform,
    required this.appVersion,
    required this.locale,
    this.pushToken,
  });

  final String deviceId;
  final DevicePlatform platform;
  final String? pushToken;
  final String appVersion;
  final String locale;

  DeviceRegistration copyWith({String? pushToken}) {
    return DeviceRegistration(
      deviceId: deviceId,
      platform: platform,
      pushToken: pushToken ?? this.pushToken,
      appVersion: appVersion,
      locale: locale,
    );
  }
}
