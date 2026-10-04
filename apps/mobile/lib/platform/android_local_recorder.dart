import 'dart:async';

import '../features/local_recordings/domain/models/local_recording_models.dart';
import 'android_local_recording_channels.dart';
import 'contracts/local_recorder.dart';

final class AndroidLocalRecorder implements LocalRecorder {
  AndroidLocalRecorder() {
    _states = androidLocalRecordingEvents
        .map<LocalRecorderState>(_decodeState)
        .asBroadcastStream();
  }

  late final Stream<LocalRecorderState> _states;
  LocalRecordingSession? _session;

  @override
  Stream<LocalRecorderState> watch() => _states;

  @override
  Future<void> start(LocalRecordingSession session) async {
    _session = session;
    await androidLocalRecordingMethodChannel.invokeMethod<void>(
      'start',
      <String, Object?>{
        'session_id': session.sessionId,
        'watch_id': session.watchId,
        'device_id': session.deviceId,
        'stream_url': session.streamUrl.toString(),
        'stream_format': session.streamFormat.name,
        'stream_headers': session.streamHeaders,
        'granted_seconds': session.grantedSeconds,
      },
    );
  }

  @override
  Future<void> stop() async {
    final Future<LocalRecorderState> completed = _states.firstWhere(
      (LocalRecorderState state) =>
          state.phase == LocalRecorderPhase.stopped ||
          state.phase == LocalRecorderPhase.error,
    );
    await androidLocalRecordingMethodChannel.invokeMethod<void>('stop');
    await completed.timeout(const Duration(seconds: 30));
    _session = null;
  }

  @override
  Future<void> recover() async {
    final LocalRecordingSession session =
        _session ??
        (throw StateError('There is no interrupted local recording session.'));
    await start(session);
  }

  Future<void> markRegistered(String sessionId) {
    return androidLocalRecordingMethodChannel.invokeMethod<void>(
      'markRegistered',
      <String, Object?>{'session_id': sessionId},
    );
  }

  LocalRecorderState _decodeState(dynamic raw) {
    if (raw is! Map) {
      throw const FormatException('Invalid Android local recording event.');
    }
    final Map<dynamic, dynamic> map = raw;
    return LocalRecorderState(
      phase: switch (map['phase']) {
        'starting' => LocalRecorderPhase.starting,
        'recording' => LocalRecorderPhase.recording,
        'reconnecting' => LocalRecorderPhase.reconnecting,
        'finalizing' => LocalRecorderPhase.finalizing,
        'stopped' => LocalRecorderPhase.stopped,
        'error' => LocalRecorderPhase.error,
        _ => LocalRecorderPhase.idle,
      },
      recordedSeconds: (map['recorded_seconds'] as num?)?.toInt() ?? 0,
      sizeBytes: (map['size_bytes'] as num?)?.toInt() ?? 0,
      storageState: switch (map['storage_state']) {
        'critical' => LocalStorageState.critical,
        'low' => LocalStorageState.low,
        _ => LocalStorageState.ok,
      },
      freeStorageBytes: (map['free_storage_bytes'] as num?)?.toInt(),
      estimatedStorageMinutes:
          (map['estimated_storage_minutes'] as num?)?.toInt(),
      finalizationStep: switch (map['finalization_step']) {
        'stopCapture' => LocalFinalizationStep.stopCapture,
        'flushFile' => LocalFinalizationStep.flushFile,
        'verifyFile' => LocalFinalizationStep.verifyFile,
        'registerRecording' => LocalFinalizationStep.registerRecording,
        _ => null,
      },
      errorMessage: map['error_message'] as String?,
    );
  }
}
