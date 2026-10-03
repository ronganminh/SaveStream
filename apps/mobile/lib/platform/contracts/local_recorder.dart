import '../../features/local_recordings/domain/models/local_recording_models.dart';

enum LocalRecorderPhase {
  idle,
  starting,
  recording,
  reconnecting,
  finalizing,
  stopped,
  error,
}

class LocalRecorderState {
  const LocalRecorderState({
    required this.phase,
    this.recordedSeconds = 0,
    this.sizeBytes = 0,
    this.errorMessage,
  });

  final LocalRecorderPhase phase;
  final int recordedSeconds;
  final int sizeBytes;
  final String? errorMessage;
}

abstract interface class LocalRecorder {
  Stream<LocalRecorderState> watch();

  Future<void> start(LocalRecordingSession session);

  Future<void> stop();

  Future<void> recover();
}
