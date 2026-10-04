import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n.dart';
import '../../../../platform/contracts/local_recorder.dart';
import '../../../../platform/contracts/recording_platform_service.dart';
import '../../../../platform/platform_providers.dart';
import '../../../devices/domain/models/device_registration.dart';

final Provider<RecordingPlatformController> recordingPlatformControllerProvider =
    Provider<RecordingPlatformController>((Ref ref) {
      return RecordingPlatformController(
        service: ref.watch(recordingPlatformServiceProvider),
      );
    });

final StreamProvider<RecordingPlatformAction> recordingPlatformActionProvider =
    StreamProvider<RecordingPlatformAction>(
      (Ref ref) => ref.watch(recordingPlatformServiceProvider).actionStream,
    );

class RecordingPlatformController {
  const RecordingPlatformController({
    required RecordingPlatformService service,
  }) : _service = service;

  final RecordingPlatformService _service;

  Future<void> syncAndroidNotification({
    required AppLocalizations l10n,
    required String creatorName,
    required LocalRecorderState state,
    required bool unlimited,
    required int remainingSeconds,
  }) async {
    if (_service.platform != DevicePlatform.android) return;

    final RecordingNotificationSpec spec;
    if (state.phase == LocalRecorderPhase.finalizing) {
      spec = RecordingNotificationSpec(
        kind: RecordingNotificationKind.finalizing,
        creatorName: creatorName,
        title: l10n.nativeRecordingFinalizingTitle,
        body: l10n.nativeRecordingFinalizingBody(creatorName),
      );
    } else if (state.phase == LocalRecorderPhase.reconnecting) {
      spec = RecordingNotificationSpec(
        kind: RecordingNotificationKind.reconnecting,
        creatorName: creatorName,
        title: l10n.nativeRecordingReconnectTitle(creatorName),
        body: l10n.nativeRecordingReconnectBody,
        elapsedSeconds: state.recordedSeconds,
      );
    } else if (!unlimited &&
        remainingSeconds > 0 &&
        remainingSeconds <= 60 &&
        state.phase == LocalRecorderPhase.recording) {
      spec = RecordingNotificationSpec(
        kind: RecordingNotificationKind.minuteWarning,
        creatorName: creatorName,
        title: l10n.nativeRecordingMinuteWarningTitle(creatorName),
        body: l10n.nativeRecordingMinuteWarningBody,
        elapsedSeconds: state.recordedSeconds,
        remainingFreeSeconds: remainingSeconds,
      );
    } else {
      spec = RecordingNotificationSpec(
        kind: RecordingNotificationKind.recording,
        creatorName: creatorName,
        title: l10n.nativeRecordingNotificationTitle,
        body: unlimited
            ? l10n.nativeRecordingActiveUnlimitedBody(
                creatorName,
                _elapsed(state.recordedSeconds),
              )
            : l10n.nativeRecordingActiveBody(
                creatorName,
                _elapsed(state.recordedSeconds),
                _remaining(remainingSeconds),
              ),
        elapsedSeconds: state.recordedSeconds,
        remainingFreeSeconds: unlimited ? null : remainingSeconds,
      );
    }

    await _service.updateRecordingNotification(spec);
  }

  Future<void> showCompleted({
    required AppLocalizations l10n,
    required String creatorName,
    required int recordedSeconds,
    required int sizeBytes,
    required String recordingId,
  }) {
    if (_service.platform != DevicePlatform.android) {
      return Future<void>.value();
    }
    return _service.updateRecordingNotification(
      RecordingNotificationSpec(
        kind: RecordingNotificationKind.completed,
        creatorName: creatorName,
        title: l10n.nativeRecordingSavedTitle,
        body: l10n.nativeRecordingSavedBody(
          creatorName,
          _elapsed(recordedSeconds),
          _fileSize(sizeBytes),
        ),
        elapsedSeconds: recordedSeconds,
        recordingId: recordingId,
      ),
    );
  }

  Future<void> showInterrupted({
    required AppLocalizations l10n,
    required String creatorName,
  }) {
    if (_service.platform != DevicePlatform.android) {
      return Future<void>.value();
    }
    return _service.updateRecordingNotification(
      RecordingNotificationSpec(
        kind: RecordingNotificationKind.interrupted,
        creatorName: creatorName,
        title: l10n.nativeRecordingInterruptedTitle,
        body: l10n.nativeRecordingInterruptedBody,
      ),
    );
  }

  Future<void> handleIosLifecycle({
    required AppLifecycleState state,
    required String creatorName,
    required bool activeRecording,
  }) async {
    if (_service.platform != DevicePlatform.ios) return;

    if (!activeRecording) {
      await _service.cancelIosReturnReminder();
      await _service.setIosScreenAwake(false);
      return;
    }

    if (state == AppLifecycleState.resumed) {
      await _service.cancelIosReturnReminder();
      await _service.setIosScreenAwake(true);
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      await _service.setIosScreenAwake(false);
      if (await _service.iosReturnReminderEnabled) {
        await _service.scheduleIosReturnReminder(creatorName: creatorName);
      }
    }
  }

  Future<void> clear() async {
    await _service.cancelIosReturnReminder();
    await _service.setIosScreenAwake(false);
    await _service.clearOngoingRecordingNotification();
  }

  String _elapsed(int seconds) {
    final Duration duration = Duration(seconds: seconds);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(duration.inHours)}:'
        '${two(duration.inMinutes.remainder(60))}:'
        '${two(duration.inSeconds.remainder(60))}';
  }

  String _remaining(int seconds) {
    final int safe = seconds < 0 ? 0 : seconds;
    final Duration duration = Duration(seconds: safe);
    final int minutes = duration.inMinutes;
    final int secs = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  String _fileSize(int bytes) {
    final double mib = bytes / (1024 * 1024);
    if (mib >= 1024) {
      return '${(mib / 1024).toStringAsFixed(1)} GB';
    }
    return '${mib.toStringAsFixed(0)} MB';
  }
}
