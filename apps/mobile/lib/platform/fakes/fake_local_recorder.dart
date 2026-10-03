import 'dart:async';

import '../../features/local_recordings/domain/models/local_recording_models.dart';
import '../contracts/local_recorder.dart';

final class FakeLocalRecorder implements LocalRecorder {
  final StreamController<LocalRecorderState> _states =
      StreamController<LocalRecorderState>.broadcast();
  LocalRecordingSession? _session;

  @override
  Stream<LocalRecorderState> watch() => _states.stream;

  @override
  Future<void> start(LocalRecordingSession session) async {
    _session = session;
    _states.add(const LocalRecorderState(phase: LocalRecorderPhase.starting));
    _states.add(const LocalRecorderState(phase: LocalRecorderPhase.recording));
  }

  @override
  Future<void> stop() async {
    if (_session == null) return;
    _states.add(const LocalRecorderState(phase: LocalRecorderPhase.finalizing));
    _session = null;
    _states.add(const LocalRecorderState(phase: LocalRecorderPhase.stopped));
  }

  @override
  Future<void> recover() async {
    _states.add(const LocalRecorderState(phase: LocalRecorderPhase.reconnecting));
    _states.add(const LocalRecorderState(phase: LocalRecorderPhase.recording));
  }
}
