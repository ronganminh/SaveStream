enum LocalRecoveryStep {
  findTemporaryFile,
  repairTail,
  verifyDuration,
  registerRecording,
}

enum LocalRecoveryOutcome { recovered, partial, failed }

class LocalRecoveryCandidate {
  const LocalRecoveryCandidate({
    required this.tempId,
    required this.watchId,
    required this.creatorDisplayName,
    required this.creatorHandle,
    required this.startedAt,
    required this.interruptedAt,
    required this.recordedSeconds,
    required this.sizeBytes,
  });

  final String tempId;
  final String watchId;
  final String creatorDisplayName;
  final String creatorHandle;
  final DateTime startedAt;
  final DateTime interruptedAt;
  final int recordedSeconds;
  final int sizeBytes;
}

class LocalRecoveryProgress {
  const LocalRecoveryProgress({required this.step});

  final LocalRecoveryStep step;
}

class LocalRecoveryResult {
  const LocalRecoveryResult({
    required this.outcome,
    required this.candidate,
    required this.recordedSeconds,
    required this.sizeBytes,
    this.recordingId,
  });

  final LocalRecoveryOutcome outcome;
  final LocalRecoveryCandidate candidate;
  final int recordedSeconds;
  final int sizeBytes;
  final String? recordingId;
}

abstract interface class LocalRecoveryService {
  Future<LocalRecoveryCandidate?> findInterrupted();

  Stream<LocalRecoveryProgress> watchProgress();

  Future<LocalRecoveryResult> recover(LocalRecoveryCandidate candidate);

  Future<void> deleteTemporary(String tempId);
}
