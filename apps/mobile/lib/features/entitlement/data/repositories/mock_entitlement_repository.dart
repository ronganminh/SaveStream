import '../../../../core/mock/mock_repository_base.dart';
import '../../domain/models/entitlement.dart';
import '../../domain/repositories/entitlement_repository.dart';

enum EntitlementMockState { free, freeExhausted, pro, proExhausted }

final class MockEntitlementRepository extends MockRepositoryBase
    implements EntitlementRepository {
  const MockEntitlementRepository(
    super.behavior, {
    this.state = EntitlementMockState.free,
  });

  final EntitlementMockState state;

  @override
  Future<Entitlement> getEntitlement() {
    return respond<Entitlement>(
      success: () => _snapshot(state),
      empty: () => _snapshot(EntitlementMockState.free),
    );
  }

  Entitlement _snapshot(EntitlementMockState value) {
    final DateTime now = DateTime.utc(2026, 10, 3, 13, 5);
    final DateTime reset = DateTime.utc(2026, 10, 4);
    return switch (value) {
      EntitlementMockState.free => Entitlement(
        plan: Plan.free,
        hasPurchased: false,
        cloudMinutesAvailable: 0,
        limits: const EntitlementLimits(
          maxWatches: 3,
          maxConcurrentCloudRecordings: 0,
          cloudRetentionDays: 7,
        ),
        watchCount: 2,
        local: LocalEntitlement(
          enabled: true,
          unlimited: false,
          dailyMinutes: 10,
          minutesRemaining: 6,
          resetsAt: reset,
          rewardsUsedToday: 2,
          rewardsCapPerDay: 8,
          minutesPerReward: 10,
          extensionsCapPerRecording: 4,
        ),
        updatedAt: now,
      ),
      EntitlementMockState.freeExhausted => Entitlement(
        plan: Plan.free,
        hasPurchased: false,
        cloudMinutesAvailable: 0,
        limits: const EntitlementLimits(
          maxWatches: 3,
          maxConcurrentCloudRecordings: 0,
          cloudRetentionDays: 7,
        ),
        watchCount: 3,
        local: LocalEntitlement(
          enabled: true,
          unlimited: false,
          dailyMinutes: 10,
          minutesRemaining: 0,
          resetsAt: reset,
          rewardsUsedToday: 8,
          rewardsCapPerDay: 8,
          minutesPerReward: 10,
          extensionsCapPerRecording: 4,
        ),
        updatedAt: now,
      ),
      EntitlementMockState.pro => Entitlement(
        plan: Plan.pro,
        hasPurchased: true,
        cloudMinutesAvailable: 7980,
        limits: const EntitlementLimits(
          maxWatches: 20,
          maxConcurrentCloudRecordings: 3,
          cloudRetentionDays: 30,
        ),
        watchCount: 8,
        local: LocalEntitlement(
          enabled: true,
          unlimited: true,
          dailyMinutes: 0,
          minutesRemaining: 0,
          resetsAt: reset,
          rewardsUsedToday: 0,
          rewardsCapPerDay: 8,
          minutesPerReward: 10,
          extensionsCapPerRecording: 4,
        ),
        updatedAt: now,
      ),
      EntitlementMockState.proExhausted => Entitlement(
        plan: Plan.free,
        hasPurchased: true,
        cloudMinutesAvailable: 0,
        limits: const EntitlementLimits(
          maxWatches: 3,
          maxConcurrentCloudRecordings: 0,
          cloudRetentionDays: 7,
        ),
        watchCount: 8,
        local: LocalEntitlement(
          enabled: true,
          unlimited: false,
          dailyMinutes: 10,
          minutesRemaining: 10,
          resetsAt: reset,
          rewardsUsedToday: 0,
          rewardsCapPerDay: 8,
          minutesPerReward: 10,
          extensionsCapPerRecording: 4,
        ),
        updatedAt: now,
      ),
    };
  }
}
