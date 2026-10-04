import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/local_recordings/domain/models/local_recording_models.dart';
import 'package:savestream_mobile/features/local_recordings/domain/repositories/local_recording_repository.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/controllers/local_recording_controller.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/controllers/rewarded_minutes_controller.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/rewards/domain/models/reward.dart';
import 'package:savestream_mobile/features/rewards/domain/repositories/reward_repository.dart';
import 'package:savestream_mobile/platform/contracts/ads_service.dart';
import 'package:savestream_mobile/platform/contracts/local_recorder.dart';
import 'package:savestream_mobile/platform/fakes/fake_device_info_service.dart';
import 'package:savestream_mobile/platform/platform_providers.dart';

void main() {
  final LocalEntitlement entitlement = LocalEntitlement(
    enabled: true,
    unlimited: false,
    dailyMinutes: 10,
    minutesRemaining: 1,
    resetsAt: _resetAt,
    rewardsUsedToday: 2,
    rewardsCapPerDay: 8,
    minutesPerReward: 10,
    extensionsCapPerRecording: 4,
  );

  test('valid SSV extends the active lease exactly once', () async {
    final _LocalRepositorySpy localRepository = _LocalRepositorySpy();
    final _RecorderSpy recorder = _RecorderSpy();
    final LocalRecordingController localController = LocalRecordingController(
      repository: localRepository,
      recorder: recorder,
      deviceInfo: const FakeDeviceInfoService(id: 'device_reward'),
    );
    await localController.start(watchId: 'watch_reward');

    final _RewardRepositorySpy rewards = _RewardRepositorySpy(
      statuses: <RewardStatus>[RewardStatus.valid],
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        localRecordingControllerProvider.overrideWithValue(localController),
        rewardRepositoryProvider.overrideWithValue(rewards),
        adsServiceProvider.overrideWithValue(const _AdsSpy(result: true)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      localController.dispose();
      await recorder.dispose();
    });

    await container
        .read(rewardedMinutesControllerProvider.notifier)
        .start(entitlement: entitlement, extensionsUsed: 1);

    final RewardedMinutesState state = container.read(
      rewardedMinutesControllerProvider,
    );
    expect(state.phase, RewardedMinutesPhase.success);
    expect(state.extensionCount, 2);
    expect(rewards.createdSessionId, 'session_reward');
    expect(localRepository.extendCalls, 1);
    expect(localRepository.extendRewardId, 'reward_1');
    expect(localController.activeSession?.grantedSeconds, 1200);
  });

  test('no-fill never asks server status or extends the lease', () async {
    final _Harness harness = await _Harness.create(
      adResult: false,
      statuses: <RewardStatus>[RewardStatus.valid],
    );
    addTearDown(harness.dispose);

    await harness.run(entitlement);

    expect(harness.state.phase, RewardedMinutesPhase.noFill);
    expect(harness.rewards.statusCalls, 0);
    expect(harness.localRepository.extendCalls, 0);
  });

  test('invalid SSV never extends the lease', () async {
    final _Harness harness = await _Harness.create(
      adResult: true,
      statuses: <RewardStatus>[RewardStatus.invalid],
    );
    addTearDown(harness.dispose);

    await harness.run(entitlement);

    expect(harness.state.phase, RewardedMinutesPhase.invalid);
    expect(harness.localRepository.extendCalls, 0);
  });

  test('pending SSV times out without granting client-side minutes', () async {
    final _Harness harness = await _Harness.create(
      adResult: true,
      statuses: <RewardStatus>[RewardStatus.pending],
      verificationTimeout: Duration.zero,
    );
    addTearDown(harness.dispose);

    await harness.run(entitlement);

    expect(harness.state.phase, RewardedMinutesPhase.pending);
    expect(harness.localRepository.extendCalls, 0);
  });

  test('extension and daily caps block before creating a reward', () async {
    final _Harness extensionCap = await _Harness.create(
      adResult: true,
      statuses: <RewardStatus>[RewardStatus.valid],
    );
    addTearDown(extensionCap.dispose);

    await extensionCap.run(entitlement, extensionsUsed: 4);
    expect(extensionCap.state.phase, RewardedMinutesPhase.maxExtensions);
    expect(extensionCap.rewards.createCalls, 0);

    final _Harness dailyCap = await _Harness.create(
      adResult: true,
      statuses: <RewardStatus>[RewardStatus.valid],
    );
    addTearDown(dailyCap.dispose);

    final LocalEntitlement capped = LocalEntitlement(
      enabled: true,
      unlimited: false,
      dailyMinutes: 10,
      minutesRemaining: 1,
      resetsAt: _resetAt,
      rewardsUsedToday: 8,
      rewardsCapPerDay: 8,
      minutesPerReward: 10,
      extensionsCapPerRecording: 4,
    );
    await dailyCap.run(capped);
    expect(dailyCap.state.phase, RewardedMinutesPhase.dailyCap);
    expect(dailyCap.rewards.createCalls, 0);
  });
}

final DateTime _resetAt = DateTime.utc(2026, 10, 5);

final class _Harness {
  _Harness({
    required this.container,
    required this.localController,
    required this.localRepository,
    required this.recorder,
    required this.rewards,
  });

  final ProviderContainer container;
  final LocalRecordingController localController;
  final _LocalRepositorySpy localRepository;
  final _RecorderSpy recorder;
  final _RewardRepositorySpy rewards;

  RewardedMinutesState get state =>
      container.read(rewardedMinutesControllerProvider);

  static Future<_Harness> create({
    required bool adResult,
    required List<RewardStatus> statuses,
    Duration verificationTimeout = const Duration(seconds: 15),
  }) async {
    final _LocalRepositorySpy localRepository = _LocalRepositorySpy();
    final _RecorderSpy recorder = _RecorderSpy();
    final LocalRecordingController localController = LocalRecordingController(
      repository: localRepository,
      recorder: recorder,
      deviceInfo: const FakeDeviceInfoService(id: 'device_reward'),
    );
    await localController.start(watchId: 'watch_reward');

    final _RewardRepositorySpy rewards = _RewardRepositorySpy(
      statuses: statuses,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        localRecordingControllerProvider.overrideWithValue(localController),
        rewardRepositoryProvider.overrideWithValue(rewards),
        adsServiceProvider.overrideWithValue(_AdsSpy(result: adResult)),
        rewardVerificationTimeoutProvider.overrideWithValue(
          verificationTimeout,
        ),
        rewardVerificationPollIntervalProvider.overrideWithValue(Duration.zero),
      ],
    );
    return _Harness(
      container: container,
      localController: localController,
      localRepository: localRepository,
      recorder: recorder,
      rewards: rewards,
    );
  }

  Future<void> run(LocalEntitlement entitlement, {int extensionsUsed = 1}) {
    return container
        .read(rewardedMinutesControllerProvider.notifier)
        .start(entitlement: entitlement, extensionsUsed: extensionsUsed);
  }

  Future<void> dispose() async {
    container.dispose();
    localController.dispose();
    await recorder.dispose();
  }
}

final class _AdsSpy implements AdsService {
  const _AdsSpy({required this.result});

  final bool result;

  @override
  AdConsentState get consentState => AdConsentState.granted;

  @override
  Widget? bannerFor(AdPlacement placement) => null;

  @override
  Future<bool> showRewarded(Reward reward) async => result;
}

final class _RewardRepositorySpy implements RewardRepository {
  _RewardRepositorySpy({required List<RewardStatus> statuses})
    : _statuses = List<RewardStatus>.from(statuses);

  final List<RewardStatus> _statuses;
  int createCalls = 0;
  int statusCalls = 0;
  String? createdSessionId;

  @override
  Future<Reward> create({
    required RewardPurpose purpose,
    String? sessionId,
  }) async {
    createCalls += 1;
    createdSessionId = sessionId;
    return Reward(
      rewardId: 'reward_1',
      purpose: purpose,
      status: RewardStatus.pending,
      ssvUserId: 'user_reward',
      ssvCustomData: 'reward_1',
      expiresAt: DateTime.utc(2026, 10, 4, 10),
      sessionId: sessionId,
    );
  }

  @override
  Future<Reward> getStatus(String rewardId) async {
    statusCalls += 1;
    final RewardStatus status = _statuses.length == 1
        ? _statuses.single
        : _statuses.removeAt(0);
    return Reward(
      rewardId: rewardId,
      purpose: RewardPurpose.localMinutes,
      status: status,
      ssvUserId: 'user_reward',
      ssvCustomData: rewardId,
      expiresAt: DateTime.utc(2026, 10, 4, 10),
      sessionId: 'session_reward',
    );
  }
}

final class _LocalRepositorySpy implements LocalRecordingRepository {
  int extendCalls = 0;
  String? extendRewardId;
  LocalRecordingSession? _session;

  @override
  Future<LocalRecordingSession> start({
    required String watchId,
    required String deviceId,
    String? rewardId,
  }) async {
    final LocalRecordingSession session = LocalRecordingSession(
      sessionId: 'session_reward',
      watchId: watchId,
      deviceId: deviceId,
      grantedSeconds: 600,
      leaseExpiresAt: DateTime.utc(2026, 10, 4, 10),
      streamUrl: Uri.parse('https://example.test/reward.flv'),
      streamFormat: LocalStreamFormat.flv,
    );
    _session = session;
    return session;
  }

  @override
  Future<LocalRecordingSession> extend(
    String sessionId, {
    String? rewardId,
  }) async {
    extendCalls += 1;
    extendRewardId = rewardId;
    final LocalRecordingSession current = _session!;
    final LocalRecordingSession extended = current.copyWith(
      grantedSeconds: current.grantedSeconds + 600,
    );
    _session = extended;
    return extended;
  }

  @override
  Future<void> delete(String id, {required String deviceId}) async {}

  @override
  Future<LocalRecordingSummary> finish(
    String sessionId, {
    required int recordedSeconds,
    required int sizeBytes,
    required RecordingEndReason endReason,
    required RecordingStatus status,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<LocalRecordingSummary>> list() async =>
      const <LocalRecordingSummary>[];
}

final class _RecorderSpy implements LocalRecorder {
  final StreamController<LocalRecorderState> _states =
      StreamController<LocalRecorderState>.broadcast();

  @override
  Stream<LocalRecorderState> watch() => _states.stream;

  @override
  Future<void> start(LocalRecordingSession session) async {
    _states.add(const LocalRecorderState(phase: LocalRecorderPhase.recording));
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> recover() async {}

  Future<void> dispose() => _states.close();
}
