import 'dart:async';

import '../../features/devices/domain/models/device_registration.dart';
import '../contracts/recording_platform_service.dart';

final class FakeRecordingPlatformService implements RecordingPlatformService {
  FakeRecordingPlatformService({
    this.platform = DevicePlatform.android,
    AndroidRecordingPlatformState? androidState,
    this.returnReminderEnabled = true,
  }) : _androidState =
           androidState ??
           const AndroidRecordingPlatformState(
             batteryMode: AndroidBatteryMode.optimized,
             oemFamily: AndroidOemFamily.generic,
             deviceName: 'Mock Android device',
           );

  @override
  final DevicePlatform platform;

  AndroidRecordingPlatformState _androidState;
  bool returnReminderEnabled;
  bool screenAwake = false;
  bool iosReminderScheduled = false;
  bool batterySettingsOpened = false;
  bool appSettingsOpened = false;
  RecordingNotificationSpec? lastNotification;
  final StreamController<RecordingPlatformAction> _actions =
      StreamController<RecordingPlatformAction>.broadcast();

  @override
  Stream<RecordingPlatformAction> get actionStream => _actions.stream;

  void emitAction(RecordingPlatformAction action) {
    _actions.add(action);
  }

  void setAndroidState(AndroidRecordingPlatformState value) {
    _androidState = value;
  }

  @override
  Future<AndroidRecordingPlatformState> get androidState async => _androidState;

  @override
  Future<void> openBatterySettings() async {
    batterySettingsOpened = true;
  }

  @override
  Future<void> openAppSettings() async {
    appSettingsOpened = true;
  }

  @override
  Future<void> updateRecordingNotification(
    RecordingNotificationSpec spec,
  ) async {
    lastNotification = spec;
  }

  @override
  Future<void> clearOngoingRecordingNotification() async {
    lastNotification = null;
  }

  @override
  Future<bool> get iosReturnReminderEnabled async => returnReminderEnabled;

  @override
  Future<void> setIosReturnReminderEnabled(bool enabled) async {
    returnReminderEnabled = enabled;
  }

  @override
  Future<void> scheduleIosReturnReminder({required String creatorName}) async {
    if (returnReminderEnabled) {
      iosReminderScheduled = true;
    }
  }

  @override
  Future<void> cancelIosReturnReminder() async {
    iosReminderScheduled = false;
  }

  @override
  Future<void> setIosScreenAwake(bool enabled) async {
    screenAwake = enabled;
  }

  Future<void> dispose() => _actions.close();
}
