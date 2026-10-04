import '../features/devices/domain/models/device_registration.dart';
import 'android_local_recording_channels.dart';
import 'contracts/recording_platform_service.dart';

final class AndroidRecordingPlatformService
    implements RecordingPlatformService {
  @override
  DevicePlatform get platform => DevicePlatform.android;

  @override
  Stream<RecordingPlatformAction> get actionStream =>
      androidRecordingPlatformActionEventChannel
          .receiveBroadcastStream()
          .where((dynamic event) => event is String)
          .map<RecordingPlatformAction>((dynamic event) => switch (event) {
                'stop_recording' => RecordingPlatformAction.stopRecording,
                'open_recording' => RecordingPlatformAction.openRecording,
                'recover_interrupted' =>
                  RecordingPlatformAction.recoverInterrupted,
                _ => throw FormatException(
                    'Unknown recording platform action: $event',
                  ),
              });

  @override
  Future<AndroidRecordingPlatformState> get androidState async {
    final Map<dynamic, dynamic>? raw =
        await androidRecordingPlatformMethodChannel
            .invokeMapMethod<dynamic, dynamic>('androidState');
    if (raw == null) {
      throw const FormatException('Missing Android recording platform state.');
    }
    return AndroidRecordingPlatformState(
      batteryMode: raw['battery_mode'] == 'unrestricted'
          ? AndroidBatteryMode.unrestricted
          : AndroidBatteryMode.optimized,
      oemFamily: switch (raw['oem_family']) {
        'xiaomi' => AndroidOemFamily.xiaomi,
        'samsung' => AndroidOemFamily.samsung,
        'oppo_realme_vivo' => AndroidOemFamily.oppoRealmeVivo,
        'huawei' => AndroidOemFamily.huawei,
        _ => AndroidOemFamily.generic,
      },
      deviceName: raw['device_name'] as String? ?? 'Android',
      osName: raw['os_name'] as String?,
    );
  }

  @override
  Future<void> openBatterySettings() =>
      androidRecordingPlatformMethodChannel.invokeMethod<void>(
        'openBatterySettings',
      );

  @override
  Future<void> openAppSettings() =>
      androidRecordingPlatformMethodChannel.invokeMethod<void>(
        'openAppSettings',
      );

  @override
  Future<void> updateRecordingNotification(
    RecordingNotificationSpec spec,
  ) {
    final bool ongoing =
        spec.kind != RecordingNotificationKind.completed &&
        spec.kind != RecordingNotificationKind.interrupted;
    return androidRecordingPlatformMethodChannel.invokeMethod<void>(
      'updateNotification',
      <String, Object?>{
        'title': spec.title,
        'body': spec.body,
        'ongoing': ongoing,
      },
    );
  }

  @override
  Future<void> clearOngoingRecordingNotification() =>
      androidRecordingPlatformMethodChannel.invokeMethod<void>(
        'clearNotification',
      );

  @override
  Future<bool> get iosReturnReminderEnabled async => false;

  @override
  Future<void> setIosReturnReminderEnabled(bool enabled) async {}

  @override
  Future<void> scheduleIosReturnReminder({
    required String creatorName,
  }) async {}

  @override
  Future<void> cancelIosReturnReminder() async {}

  @override
  Future<void> setIosScreenAwake(bool enabled) async {}
}
