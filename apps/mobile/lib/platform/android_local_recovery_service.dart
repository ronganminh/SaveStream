import 'dart:async';

import '../features/local_recordings/domain/models/local_recording_models.dart';
import '../features/local_recordings/domain/repositories/local_recording_repository.dart';
import '../features/recordings/domain/models/recording_summary.dart';
import 'android_local_recording_channels.dart';
import 'contracts/local_recovery_service.dart';

final class AndroidLocalRecoveryService implements LocalRecoveryService {
  AndroidLocalRecoveryService({
    required LocalRecordingRepository repository,
  }) : _repository = repository;

  final LocalRecordingRepository _repository;
  final StreamController<LocalRecoveryProgress> _progress =
      StreamController<LocalRecoveryProgress>.broadcast();

  @override
  Future<LocalRecoveryCandidate?> findInterrupted() async {
    final Map<dynamic, dynamic>? raw =
        await androidLocalRecordingMethodChannel
            .invokeMapMethod<dynamic, dynamic>('findInterrupted');
    if (raw == null) {
      return null;
    }
    final String watchId = raw['watch_id'] as String? ?? '';
    return LocalRecoveryCandidate(
      tempId: raw['temp_id'] as String,
      watchId: watchId,
      creatorDisplayName: watchId,
      creatorHandle: watchId,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (raw['started_at_ms'] as num).toInt(),
        isUtc: true,
      ),
      interruptedAt: DateTime.fromMillisecondsSinceEpoch(
        (raw['interrupted_at_ms'] as num).toInt(),
        isUtc: true,
      ),
      recordedSeconds: (raw['recorded_seconds'] as num?)?.toInt() ?? 0,
      sizeBytes: (raw['size_bytes'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Stream<LocalRecoveryProgress> watchProgress() => _progress.stream;

  @override
  Future<LocalRecoveryResult> recover(LocalRecoveryCandidate candidate) async {
    _progress.add(
      const LocalRecoveryProgress(step: LocalRecoveryStep.findTemporaryFile),
    );
    final Future<Map<dynamic, dynamic>> completed = androidLocalRecordingEvents
        .where((dynamic raw) => raw is Map)
        .cast<Map<dynamic, dynamic>>()
        .firstWhere(
          (Map<dynamic, dynamic> raw) =>
              raw['phase'] == 'stopped' || raw['phase'] == 'error',
        );

    _progress.add(
      const LocalRecoveryProgress(step: LocalRecoveryStep.repairTail),
    );
    await androidLocalRecordingMethodChannel.invokeMethod<void>(
      'recover',
      <String, Object?>{'session_id': candidate.tempId},
    );
    final Map<dynamic, dynamic> event = await completed.timeout(
      const Duration(seconds: 30),
    );

    _progress.add(
      const LocalRecoveryProgress(step: LocalRecoveryStep.verifyDuration),
    );
    final int recordedSeconds =
        (event['recorded_seconds'] as num?)?.toInt() ??
        candidate.recordedSeconds;
    final int sizeBytes =
        (event['size_bytes'] as num?)?.toInt() ?? candidate.sizeBytes;
    final bool nativeFailed = event['phase'] == 'error';

    if (nativeFailed) {
      return LocalRecoveryResult(
        outcome: LocalRecoveryOutcome.failed,
        candidate: candidate,
        recordedSeconds: recordedSeconds,
        sizeBytes: sizeBytes,
      );
    }

    _progress.add(
      const LocalRecoveryProgress(step: LocalRecoveryStep.registerRecording),
    );
    final RecordingStatus status = sizeBytes > 0
        ? RecordingStatus.recovered
        : RecordingStatus.partial;
    final LocalRecordingSummary summary = await _repository.finish(
      candidate.tempId,
      recordedSeconds: recordedSeconds,
      sizeBytes: sizeBytes,
      endReason: RecordingEndReason.interrupted,
      status: status,
    );
    await androidLocalRecordingMethodChannel.invokeMethod<void>(
      'markRegistered',
      <String, Object?>{'session_id': candidate.tempId},
    );

    return LocalRecoveryResult(
      outcome: status == RecordingStatus.recovered
          ? LocalRecoveryOutcome.recovered
          : LocalRecoveryOutcome.partial,
      candidate: candidate,
      recordedSeconds: recordedSeconds,
      sizeBytes: sizeBytes,
      recordingId: summary.id,
    );
  }

  @override
  Future<void> deleteTemporary(String tempId) {
    return androidLocalRecordingMethodChannel.invokeMethod<void>(
      'deleteInterrupted',
      <String, Object?>{'session_id': tempId},
    );
  }

  Future<void> dispose() => _progress.close();
}
