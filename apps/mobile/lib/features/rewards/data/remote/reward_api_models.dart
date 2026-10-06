import '../../domain/models/reward.dart';

Reward rewardCreateFromJson(
  Object? json, {
  required RewardPurpose purpose,
  String? sessionId,
}) {
  final Map<Object?, Object?> map = _requiredMap(json, 'reward');
  return Reward(
    rewardId: _requiredString(map['reward_id'], 'reward_id'),
    purpose: purpose,
    status: RewardStatus.pending,
    ssvUserId: _requiredString(map['ssv_user_id'], 'ssv_user_id'),
    ssvCustomData: _requiredString(map['ssv_custom_data'], 'ssv_custom_data'),
    expiresAt: _requiredDateTime(map['expires_at'], 'expires_at'),
    sessionId: sessionId,
  );
}

RewardStatus rewardStatusFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'reward status');
  return switch (_requiredString(map['status'], 'status')) {
    'pending' => RewardStatus.pending,
    'valid' => RewardStatus.valid,
    'invalid' => RewardStatus.invalid,
    'expired' => RewardStatus.expired,
    final String value => throw FormatException(
      'Unsupported reward status: $value',
    ),
  };
}

Map<Object?, Object?> _requiredMap(Object? value, String name) {
  if (value is! Map) {
    throw FormatException('Expected $name object.');
  }
  return value;
}

String _requiredString(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Expected non-empty $name.');
  }
  return value.trim();
}

DateTime _requiredDateTime(Object? value, String name) {
  final String raw = _requiredString(value, name);
  final DateTime? parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('Expected ISO-8601 $name.');
  }
  return parsed.toUtc();
}
