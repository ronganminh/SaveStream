import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_providers.dart';
import '../../../../platform/contracts/device_info_service.dart';
import '../../../../platform/contracts/local_recorder.dart';
import '../../../../platform/platform_providers.dart';
import '../../../recordings/domain/models/recording_summary.dart';
import '../../../rewards/data/repositories/mock_reward_repository.dart';
import '../../../rewards/domain/repositories/reward_repository.dart';
import '../../data/repositories/mock_local_recording_repository.dart';
import '../../domain/models/local_recording_models.dart';
import '../../domain/repositories/local_recording_repository.dart';

final Provider<LocalRecordingRepository> localRecordingRepositoryProvider =
    Provider<LocalRecordingRepository>(
      (ref) => MockLocalRecordingRepository(ref.watch(mockBehaviorProvider)),
    );

final Provider<RewardRepository> rewardRepositoryProvider =
    Provider<RewardRepository>(
      (ref) => MockRewardRepository(ref.watch(mockBehaviorProvider)),
    );

final StreamProvider<LocalRecorderState> localRecorderStateProvider =
    StreamProvider<LocalRecorderState>(
      (ref) => ref.watch(localRecorderProvider).watch(),
    );

final Provider<LocalRecordingController> localRecordingControllerProvider =
    Provider<LocalRecordingController>((ref) {
      final LocalRecordingController controller = LocalRecordingController(
        repository: ref.watch(localRecordingRepositoryProvider),
        recorder: ref.watch(localRecorderProvider),
        deviceInfo: ref.watch(deviceInfoServiceProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

class LocalRecordingController {
  LocalRecordingController({
    required LocalRecordingRepository repository,
    required LocalRecorder recorder,
    required DeviceInfoService deviceInfo,
  }) : _repository = repository,
       _recorder = recorder,
       _deviceInfo = deviceInfo {
    _recorderSubscription = _recorder.watch().listen((LocalRecorderState next) {
      _latestRecorderState = next;
    });
  }

  final LocalRecordingRepository _repository;
  final LocalRecorder _recorder;
  final DeviceInfoService _deviceInfo;

  late final StreamSubscription<LocalRecorderState> _recorderSubscription;
  LocalRecordingSession? _activeSession;
  LocalRecorderState _latestRecorderState = const LocalRecorderState(
    phase: LocalRecorderPhase.idle,
  );

  LocalRecordingSession? get activeSession => _activeSession;

  LocalRecorderState get recorderState => _latestRecorderState;

  bool get hasActiveSession => _activeSession != null;

  Future<LocalRecordingSession> start({
    required String watchId,
    String? rewardId,
  }) async {
    if (_activeSession != null) {
      throw StateError('A local recording session is already active.');
    }

    final String deviceId = await _deviceInfo.deviceId;
    final LocalRecordingSession session = await _repository.start(
      watchId: watchId,
      deviceId: deviceId,
      rewardId: rewardId,
    );

    _activeSession = session;
    try {
      await _recorder.start(session);
      return session;
    } on Object {
      _activeSession = null;
      rethrow;
    }
  }

  Future<LocalRecordingSummary> stop({
    RecordingEndReason endReason = RecordingEndReason.userStopped,
    RecordingStatus status = RecordingStatus.stopped,
  }) async {
    final LocalRecordingSession session =
        _activeSession ??
        (throw StateError('There is no active local recording session.'));
    final LocalRecorderState snapshot = _latestRecorderState;

    await _recorder.stop();
    final LocalRecordingSummary summary = await _repository.finish(
      session.sessionId,
      recordedSeconds: snapshot.recordedSeconds,
      sizeBytes: snapshot.sizeBytes,
      endReason: endReason,
      status: status,
    );
    _activeSession = null;
    return summary;
  }

  Future<LocalRecordingSession> extendWithReward(String rewardId) async {
    final LocalRecordingSession session =
        _activeSession ??
        (throw StateError('There is no active local recording session.'));
    final LocalRecordingSession extended = await _repository.extend(
      session.sessionId,
      rewardId: rewardId,
    );
    _activeSession = extended;
    return extended;
  }

  Future<void> recover() {
    if (_activeSession == null) {
      throw StateError('There is no active local recording session.');
    }
    return _recorder.recover();
  }

  void dispose() {
    unawaited(_recorderSubscription.cancel());
  }
}
