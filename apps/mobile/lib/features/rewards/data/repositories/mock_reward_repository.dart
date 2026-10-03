import '../../../../core/mock/mock_repository_base.dart';
import '../../domain/models/reward.dart';
import '../../domain/repositories/reward_repository.dart';

final class MockRewardRepository extends MockRepositoryBase
    implements RewardRepository {
  MockRewardRepository(super.behavior);

  final Map<String, Reward> _items = <String, Reward>{};

  @override
  Future<Reward> create({required RewardPurpose purpose, String? sessionId}) {
    return respond<Reward>(
      success: () {
        final String id = 'rwd_${_items.length + 1}';
        final Reward reward = Reward(
          rewardId: id,
          purpose: purpose,
          status: RewardStatus.pending,
          ssvUserId: 'usr_mock',
          ssvCustomData: id,
          expiresAt: DateTime.utc(2026, 10, 3, 14),
          sessionId: sessionId,
        );
        _items[id] = reward;
        return reward;
      },
      empty: () => Reward(
        rewardId: 'rwd_empty',
        purpose: purpose,
        status: RewardStatus.expired,
        ssvUserId: 'usr_mock',
        ssvCustomData: 'rwd_empty',
        expiresAt: DateTime.utc(2026, 10, 3, 14),
        sessionId: sessionId,
      ),
    );
  }

  @override
  Future<Reward> getStatus(String rewardId) {
    return respond<Reward>(
      success: () {
        final Reward current =
            _items[rewardId] ?? (throw StateError('Unknown reward.'));
        final Reward valid = current.copyWith(status: RewardStatus.valid);
        _items[rewardId] = valid;
        return valid;
      },
      empty: () => Reward(
        rewardId: rewardId,
        purpose: RewardPurpose.localMinutes,
        status: RewardStatus.expired,
        ssvUserId: 'usr_mock',
        ssvCustomData: rewardId,
        expiresAt: DateTime.utc(2026, 10, 3, 14),
      ),
    );
  }
}
