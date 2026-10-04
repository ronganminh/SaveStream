import 'dart:async';

import '../../features/local_recordings/domain/models/local_recording_models.dart';
import '../contracts/local_recorder.dart';

final class FakeLocalRecorder implements LocalRecorder {
  final StreamController<LocalRecorderState> _states =
      StreamController<LocalRecorderState>.broadcast();

  LocalRecordingSession? _session;
  Timer? _ticker;
  int _recordedSeconds = 0;
  int _sizeBytes = 0;

  @override
  Stream<LocalRecorderState> watch() => _states.stream;

  @override
  Future<void> start(LocalRecordingSession session) async {
    _ticker?.cancel();
    _session = session;
    _recordedSeconds = 0;
    _sizeBytes = 0;

    _states.add(const LocalRecorderState(phase: LocalRecorderPhase.starting));
    await Future<void>.delayed(Duration.zero);

    if (_session?.sessionId != session.sessionId) return;
    _emit(LocalRecorderPhase.recording);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_session == null) return;
      _recordedSeconds += 1;
      _sizeBytes += 640 * 1024;
      _emit(LocalRecorderPhase.recording);
    });
  }

  @override
  Future<void> stop() async {
    if (_session == null) return;
    _ticker?.cancel();
    _ticker = null;
    _emit(LocalRecorderPhase.finalizing);
    _session = null;
    _emit(LocalRecorderPhase.stopped);
  }

  @override
  Future<void> recover() async {
    if (_session == null) return;
    _ticker?.cancel();
    _ticker = null;
    _emit(LocalRecorderPhase.reconnecting);
    await Future<void>.delayed(Duration.zero);

    if (_session == null) return;
    _emit(LocalRecorderPhase.recording);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_session == null) return;
      _recordedSeconds += 1;
      _sizeBytes += 640 * 1024;
      _emit(LocalRecorderPhase.recording);
    });
  }

  void _emit(LocalRecorderPhase phase) {
    _states.add(
      LocalRecorderState(
        phase: phase,
        recordedSeconds: _recordedSeconds,
        sizeBytes: _sizeBytes,
      ),
    );
  }
}
