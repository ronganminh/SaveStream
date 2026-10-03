import '../models/reward.dart';

abstract interface class RewardRepository {
  Future<Reward> create({required RewardPurpose purpose, String? sessionId});

  Future<Reward> getStatus(String rewardId);
}
