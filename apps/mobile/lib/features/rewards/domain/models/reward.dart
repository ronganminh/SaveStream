enum RewardPurpose { localMinutes, localSlot }

enum RewardStatus { pending, valid, invalid, expired }

class Reward {
  const Reward({
    required this.rewardId,
    required this.purpose,
    required this.status,
    required this.ssvUserId,
    required this.ssvCustomData,
    required this.expiresAt,
    this.sessionId,
  });

  final String rewardId;
  final RewardPurpose purpose;
  final RewardStatus status;
  final String ssvUserId;
  final String ssvCustomData;
  final DateTime expiresAt;
  final String? sessionId;

  Reward copyWith({RewardStatus? status}) {
    return Reward(
      rewardId: rewardId,
      purpose: purpose,
      status: status ?? this.status,
      ssvUserId: ssvUserId,
      ssvCustomData: ssvCustomData,
      expiresAt: expiresAt,
      sessionId: sessionId,
    );
  }
}
