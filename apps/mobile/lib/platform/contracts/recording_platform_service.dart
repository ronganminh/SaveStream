import '../../features/devices/domain/models/device_registration.dart';

enum AndroidBatteryMode { optimized, unrestricted }

enum AndroidOemFamily { generic, xiaomi, samsung, oppoRealmeVivo, huawei }

enum RecordingNotificationKind {
  recording,
  reconnecting,
  minuteWarning,
  finalizing,
  completed,
  interrupted,
}

class AndroidRecordingPlatformState {
  const AndroidRecordingPlatformState({
    required this.batteryMode,
    required this.oemFamily,
    required this.deviceName,
    this.osName,
  });

  final AndroidBatteryMode batteryMode;
  final AndroidOemFamily oemFamily;
  final String deviceName;
  final String? osName;
}

class RecordingNotificationSpec {
  const RecordingNotificationSpec({
    required this.kind,
    required this.creatorName,
    required this.title,
    required this.body,
    this.elapsedSeconds,
    this.remainingFreeSeconds,
    this.recordingId,
  });

  final RecordingNotificationKind kind;
  final String creatorName;
  final String title;
  final String body;
  final int? elapsedSeconds;
  final int? remainingFreeSeconds;
  final String? recordingId;
}

abstract interface class RecordingPlatformService {
  DevicePlatform get platform;

  Future<AndroidRecordingPlatformState> get androidState;

  Future<void> openBatterySettings();

  Future<void> openAppSettings();

  Future<void> updateRecordingNotification(RecordingNotificationSpec spec);

  Future<void> clearOngoingRecordingNotification();

  Future<bool> get iosReturnReminderEnabled;

  Future<void> setIosReturnReminderEnabled(bool enabled);

  Future<void> scheduleIosReturnReminder({
    required String creatorName,
  });

  Future<void> cancelIosReturnReminder();

  Future<void> setIosScreenAwake(bool enabled);
}
