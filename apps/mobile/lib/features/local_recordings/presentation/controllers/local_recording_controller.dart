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

final StreamProvider<LocalRecorderState> secondaryLocalRecorderStateProvider =
    StreamProvider<LocalRecorderState>(
      (ref) => ref.watch(secondaryLocalRecorderProvider).watch(),
    );

final Provider<LocalRecordingController> localRecordingControllerProvider =
    Provider<LocalRecordingController>((ref) {
      final LocalRecordingController controller = LocalRecordingController(
        repository: ref.watch(localRecordingRepositoryProvider),
        recorder: ref.watch(localRecorderProvider),
        secondaryRecorder: ref.watch(secondaryLocalRecorderProvider),
        deviceInfo: ref.watch(deviceInfoServiceProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

class LocalRecordingController {
  LocalRecordingController({
    required LocalRecordingRepository repository,
    required LocalRecorder recorder,
    LocalRecorder? secondaryRecorder,
    required DeviceInfoService deviceInfo,
  }) : _repository = repository,
       _recorder = recorder,
       _secondaryRecorder = secondaryRecorder ?? recorder,
       _deviceInfo = deviceInfo {
    _recorderSubscription = _recorder.watch().listen((LocalRecorderState next) {
      _latestRecorderState = next;
    });
    _secondaryRecorderSubscription = _secondaryRecorder.watch().listen((
      LocalRecorderState next,
    ) {
      _latestSecondaryRecorderState = next;
    });
  }

  final LocalRecordingRepository _repository;
  final LocalRecorder _recorder;
  final LocalRecorder _secondaryRecorder;
  final DeviceInfoService _deviceInfo;

  late final StreamSubscription<LocalRecorderState> _recorderSubscription;
  late final StreamSubscription<LocalRecorderState>
  _secondaryRecorderSubscription;
  LocalRecordingSession? _activeSession;
  LocalRecordingSession? _secondarySession;
  LocalRecorderState _latestRecorderState = const LocalRecorderState(
    phase: LocalRecorderPhase.idle,
  );
  LocalRecorderState _latestSecondaryRecorderState = const LocalRecorderState(
    phase: LocalRecorderPhase.idle,
  );

  LocalRecordingSession? get activeSession => _activeSession;

  LocalRecordingSession? get secondarySession => _secondarySession;

  LocalRecorderState get recorderState => _latestRecorderState;

  LocalRecorderState get secondaryRecorderState =>
      _latestSecondaryRecorderState;

  bool get hasActiveSession => _activeSession != null;

  bool get hasSecondarySession => _secondarySession != null;

  int get activeSessionCount =>
      (_activeSession == null ? 0 : 1) + (_secondarySession == null ? 0 : 1);

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

  Future<LocalRecordingSession> startSecond({required String watchId}) async {
    if (_activeSession == null) {
      throw StateError('The primary local recording session is not active.');
    }
    if (_secondarySession != null) {
      throw StateError(
        'The secondary local recording session is already active.',
      );
    }

    final String deviceId = await _deviceInfo.deviceId;
    final LocalRecordingSession session = await _repository.start(
      watchId: watchId,
      deviceId: deviceId,
    );

    _secondarySession = session;
    try {
      await _secondaryRecorder.start(session);
      return session;
    } on Object {
      _secondarySession = null;
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
    try {
      await _recorder.stop();
      return await _repository.finish(
        session.sessionId,
        recordedSeconds: snapshot.recordedSeconds,
        sizeBytes: snapshot.sizeBytes,
        endReason: endReason,
        status: status,
      );
    } finally {
      // Preserve any recovery data on disk, but never block logout or a new
      // recording because native cleanup/registration threw.
      _activeSession = null;
    }
  }

  Future<LocalRecordingSummary> stopSecond({
    RecordingEndReason endReason = RecordingEndReason.userStopped,
    RecordingStatus status = RecordingStatus.stopped,
  }) async {
    final LocalRecordingSession session =
        _secondarySession ??
        (throw StateError('There is no secondary local recording session.'));
    final LocalRecorderState snapshot = _latestSecondaryRecorderState;
    try {
      await _secondaryRecorder.stop();
      return await _repository.finish(
        session.sessionId,
        recordedSeconds: snapshot.recordedSeconds,
        sizeBytes: snapshot.sizeBytes,
        endReason: endReason,
        status: status,
      );
    } finally {
      _secondarySession = null;
    }
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
    unawaited(_secondaryRecorderSubscription.cancel());
  }
}
