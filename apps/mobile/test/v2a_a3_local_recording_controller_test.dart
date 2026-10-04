import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/local_recordings/domain/models/local_recording_models.dart';
import 'package:savestream_mobile/features/local_recordings/domain/repositories/local_recording_repository.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/controllers/local_recording_controller.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/platform/contracts/local_recorder.dart';
import 'package:savestream_mobile/platform/fakes/fake_device_info_service.dart';

void main() {
  group('A3 local recording controller', () {
    late _RecordingRepositorySpy repository;
    late _RecorderSpy recorder;
    late LocalRecordingController controller;

    setUp(() {
      repository = _RecordingRepositorySpy();
      recorder = _RecorderSpy();
      controller = LocalRecordingController(
        repository: repository,
        recorder: recorder,
        deviceInfo: const FakeDeviceInfoService(id: 'device_a3'),
      );
    });

    tearDown(() async {
      controller.dispose();
      await recorder.dispose();
    });

    test('starts server lease before starting the local recorder', () async {
      final LocalRecordingSession session = await controller.start(
        watchId: 'watch_a3',
      );

      expect(repository.startWatchId, 'watch_a3');
      expect(repository.startDeviceId, 'device_a3');
      expect(repository.startRewardId, isNull);
      expect(recorder.startedSession, same(session));
      expect(controller.activeSession, same(session));
    });

    test('passes reward id into rewarded start', () async {
      await controller.start(watchId: 'watch_rewarded', rewardId: 'reward_123');

      expect(repository.startRewardId, 'reward_123');
    });

    test('finishes with recorder seconds and bytes', () async {
      await controller.start(watchId: 'watch_finish');
      recorder.emit(
        const LocalRecorderState(
          phase: LocalRecorderPhase.recording,
          recordedSeconds: 42,
          sizeBytes: 8 * 1024 * 1024,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final LocalRecordingSummary summary = await controller.stop();

      expect(recorder.stopCalls, 1);
      expect(repository.finishedSessionId, 'session_a3');
      expect(repository.finishedSeconds, 42);
      expect(repository.finishedBytes, 8 * 1024 * 1024);
      expect(repository.finishedEndReason, RecordingEndReason.userStopped);
      expect(repository.finishedStatus, RecordingStatus.stopped);
      expect(summary.recordedSeconds, 42);
      expect(controller.activeSession, isNull);
    });

    test('rejects a second local session while one is active', () async {
      await controller.start(watchId: 'watch_first');

      expect(() => controller.start(watchId: 'watch_second'), throwsStateError);
      expect(repository.startCalls, 1);
    });

    test('recover requires and delegates an active session', () async {
      expect(controller.recover, throwsStateError);

      await controller.start(watchId: 'watch_recover');
      await controller.recover();

      expect(recorder.recoverCalls, 1);
    });
  });
}

final class _RecorderSpy implements LocalRecorder {
  final StreamController<LocalRecorderState> _states =
      StreamController<LocalRecorderState>.broadcast();

  LocalRecordingSession? startedSession;
  int stopCalls = 0;
  int recoverCalls = 0;

  @override
  Stream<LocalRecorderState> watch() => _states.stream;

  @override
  Future<void> start(LocalRecordingSession session) async {
    startedSession = session;
    emit(const LocalRecorderState(phase: LocalRecorderPhase.starting));
    emit(const LocalRecorderState(phase: LocalRecorderPhase.recording));
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    emit(const LocalRecorderState(phase: LocalRecorderPhase.finalizing));
    emit(const LocalRecorderState(phase: LocalRecorderPhase.stopped));
  }

  @override
  Future<void> recover() async {
    recoverCalls += 1;
    emit(const LocalRecorderState(phase: LocalRecorderPhase.reconnecting));
    emit(const LocalRecorderState(phase: LocalRecorderPhase.recording));
  }

  void emit(LocalRecorderState state) {
    _states.add(state);
  }

  Future<void> dispose() => _states.close();
}

final class _RecordingRepositorySpy implements LocalRecordingRepository {
  int startCalls = 0;
  String? startWatchId;
  String? startDeviceId;
  String? startRewardId;

  String? finishedSessionId;
  int? finishedSeconds;
  int? finishedBytes;
  RecordingEndReason? finishedEndReason;
  RecordingStatus? finishedStatus;

  @override
  Future<LocalRecordingSession> start({
    required String watchId,
    required String deviceId,
    String? rewardId,
  }) async {
    startCalls += 1;
    startWatchId = watchId;
    startDeviceId = deviceId;
    startRewardId = rewardId;
    return LocalRecordingSession(
      sessionId: 'session_a3',
      watchId: watchId,
      deviceId: deviceId,
      grantedSeconds: 600,
      leaseExpiresAt: DateTime.utc(2026, 10, 4, 9),
      streamUrl: Uri.parse('https://example.test/live.flv'),
      streamFormat: LocalStreamFormat.flv,
    );
  }

  @override
  Future<LocalRecordingSession> extend(String sessionId, {String? rewardId}) {
    throw UnimplementedError();
  }

  @override
  Future<LocalRecordingSummary> finish(
    String sessionId, {
    required int recordedSeconds,
    required int sizeBytes,
    required RecordingEndReason endReason,
    required RecordingStatus status,
  }) async {
    finishedSessionId = sessionId;
    finishedSeconds = recordedSeconds;
    finishedBytes = sizeBytes;
    finishedEndReason = endReason;
    finishedStatus = status;
    return LocalRecordingSummary(
      id: sessionId,
      watchId: 'watch_finish',
      creatorDisplayName: 'A3 creator',
      creatorHandle: '@a3_creator',
      deviceId: 'device_a3',
      deviceName: 'Test device',
      startedAt: DateTime.utc(2026, 10, 4, 8),
      recordedSeconds: recordedSeconds,
      sizeBytes: sizeBytes,
      status: status,
    );
  }

  @override
  Future<List<LocalRecordingSummary>> list() async =>
      const <LocalRecordingSummary>[];

  @override
  Future<void> delete(String id, {required String deviceId}) async {}
}
