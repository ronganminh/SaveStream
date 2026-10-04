import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/mock/mock_scenario.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/entitlement/domain/repositories/entitlement_repository.dart';
import 'package:savestream_mobile/features/entitlement/presentation/entitlement_providers.dart';
import 'package:savestream_mobile/features/local_recordings/data/repositories/mock_local_recording_repository.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/controllers/local_recording_controller.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/controllers/rewarded_minutes_controller.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/controllers/second_local_slot_controller.dart';
import 'package:savestream_mobile/features/rewards/data/repositories/mock_reward_repository.dart';
import 'package:savestream_mobile/platform/fakes/fake_ads_service.dart';
import 'package:savestream_mobile/platform/fakes/fake_device_info_service.dart';
import 'package:savestream_mobile/platform/fakes/fake_local_recorder.dart';
import 'package:savestream_mobile/platform/platform_providers.dart';

void main() {
  const MockBehavior success = MockBehavior(
    scenario: MockScenario.success,
    latency: Duration.zero,
  );

  test('R13-R15 unlocks slot only after two server-valid rewards', () async {
    final DateTime expiresAt = DateTime.now().add(const Duration(hours: 1));
    final _UnlockedEntitlementRepository entitlementRepository =
        _UnlockedEntitlementRepository(expiresAt);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        rewardRepositoryProvider.overrideWithValue(
          MockRewardRepository(success),
        ),
        adsServiceProvider.overrideWithValue(const FakeAdsService()),
        entitlementRepositoryProvider.overrideWithValue(
          entitlementRepository,
        ),
        rewardVerificationPollIntervalProvider.overrideWithValue(
          Duration.zero,
        ),
      ],
    );
    addTearDown(container.dispose);

    final SecondLocalSlotController controller = container.read(
      secondLocalSlotControllerProvider.notifier,
    );
    final LocalEntitlement local = _localEntitlement();

    await controller.start(local);
    expect(
      container.read(secondLocalSlotControllerProvider).phase,
      SecondLocalSlotPhase.progress,
    );
    expect(
      container.read(secondLocalSlotControllerProvider).verifiedRewards,
      1,
    );
    expect(entitlementRepository.calls, 0);

    await controller.start(local);
    final SecondLocalSlotState unlocked = container.read(
      secondLocalSlotControllerProvider,
    );
    expect(unlocked.phase, SecondLocalSlotPhase.unlocked);
    expect(unlocked.verifiedRewards, 2);
    expect(unlocked.expiresAt, expiresAt);
    expect(entitlementRepository.calls, 1);
  });

  test('R16 detects an expired server slot without inventing a new expiry', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final DateTime expiredAt = DateTime.now().subtract(
      const Duration(minutes: 5),
    );
    container
        .read(secondLocalSlotControllerProvider.notifier)
        .syncEntitlement(
          _localEntitlement(
            maxConcurrentSessions: 1,
            secondSlotExpiresAt: expiredAt,
          ),
        );

    final SecondLocalSlotState state = container.read(
      secondLocalSlotControllerProvider,
    );
    expect(state.phase, SecondLocalSlotPhase.expired);
    expect(state.expiresAt, expiredAt);
  });

  test('Local recording controller runs primary and secondary recorders', () async {
    final FakeLocalRecorder primary = FakeLocalRecorder();
    final FakeLocalRecorder secondary = FakeLocalRecorder();
    final LocalRecordingController controller = LocalRecordingController(
      repository: MockLocalRecordingRepository(success),
      recorder: primary,
      secondaryRecorder: secondary,
      deviceInfo: const FakeDeviceInfoService(id: 'device_slot_test'),
    );
    addTearDown(controller.dispose);

    await controller.start(watchId: 'watch_primary');
    await controller.startSecond(watchId: 'watch_secondary');

    expect(controller.activeSessionCount, 2);
    expect(controller.activeSession?.watchId, 'watch_primary');
    expect(controller.secondarySession?.watchId, 'watch_secondary');

    await controller.stopSecond();
    expect(controller.activeSessionCount, 1);

    await controller.stop();
    expect(controller.activeSessionCount, 0);
  });
}

LocalEntitlement _localEntitlement({
  int maxConcurrentSessions = 1,
  DateTime? secondSlotExpiresAt,
}) {
  return LocalEntitlement(
    enabled: true,
    unlimited: false,
    dailyMinutes: 10,
    minutesRemaining: 6,
    resetsAt: DateTime.now().add(const Duration(hours: 12)),
    rewardsUsedToday: 2,
    rewardsCapPerDay: 8,
    minutesPerReward: 10,
    extensionsCapPerRecording: 4,
    maxConcurrentSessions: maxConcurrentSessions,
    secondSlotExpiresAt: secondSlotExpiresAt,
  );
}

final class _UnlockedEntitlementRepository implements EntitlementRepository {
  _UnlockedEntitlementRepository(this.expiresAt);

  final DateTime expiresAt;
  int calls = 0;

  @override
  Future<Entitlement> getEntitlement() async {
    calls += 1;
    return Entitlement(
      plan: Plan.free,
      hasPurchased: false,
      cloudMinutesAvailable: 0,
      limits: const EntitlementLimits(
        maxWatches: 3,
        maxConcurrentCloudRecordings: 0,
        cloudRetentionDays: 7,
      ),
      watchCount: 2,
      local: _localEntitlement(
        maxConcurrentSessions: 2,
        secondSlotExpiresAt: expiresAt,
      ),
      updatedAt: DateTime.now(),
    );
  }
}
