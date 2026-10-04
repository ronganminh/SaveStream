import 'dart:async';

import '../contracts/local_recovery_service.dart';

final class FakeLocalRecoveryService implements LocalRecoveryService {
  FakeLocalRecoveryService({
    this.candidate,
    this.outcome = LocalRecoveryOutcome.partial,
  });

  LocalRecoveryCandidate? candidate;
  final LocalRecoveryOutcome outcome;
  final StreamController<LocalRecoveryProgress> _progress =
      StreamController<LocalRecoveryProgress>.broadcast();

  @override
  Future<LocalRecoveryCandidate?> findInterrupted() async => candidate;

  @override
  Stream<LocalRecoveryProgress> watchProgress() => _progress.stream;

  @override
  Future<LocalRecoveryResult> recover(LocalRecoveryCandidate candidate) async {
    for (final LocalRecoveryStep step in LocalRecoveryStep.values) {
      _progress.add(LocalRecoveryProgress(step: step));
      await Future<void>.delayed(Duration.zero);
    }
    final LocalRecoveryResult result = LocalRecoveryResult(
      outcome: outcome,
      candidate: candidate,
      recordedSeconds: candidate.recordedSeconds,
      sizeBytes: candidate.sizeBytes,
      recordingId: outcome == LocalRecoveryOutcome.failed
          ? null
          : 'recovered_${candidate.tempId}',
    );
    if (outcome != LocalRecoveryOutcome.failed) {
      this.candidate = null;
    }
    return result;
  }

  @override
  Future<void> deleteTemporary(String tempId) async {
    if (candidate?.tempId == tempId) {
      candidate = null;
    }
  }

  Future<void> dispose() => _progress.close();
}
