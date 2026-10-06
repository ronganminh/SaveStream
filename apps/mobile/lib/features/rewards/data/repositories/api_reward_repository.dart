import '../../../../core/api/api_client.dart';
import '../../domain/models/reward.dart';
import '../../domain/repositories/reward_repository.dart';
import '../remote/reward_api_models.dart';

final class ApiRewardRepository implements RewardRepository {
  ApiRewardRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final Map<String, Reward> _created = <String, Reward>{};

  @override
  Future<Reward> create({
    required RewardPurpose purpose,
    String? sessionId,
  }) async {
    final response = await _apiClient.post<Reward>(
      '/v1/rewards',
      data: <String, Object?>{
        'purpose': switch (purpose) {
          RewardPurpose.localMinutes => 'local_minutes',
          RewardPurpose.localSlot => 'local_slot',
        },
        if (sessionId != null) 'session_id': sessionId,
      },
      decoder: (Object? json) =>
          rewardCreateFromJson(json, purpose: purpose, sessionId: sessionId),
    );
    _created[response.data.rewardId] = response.data;
    return response.data;
  }

  @override
  Future<Reward> getStatus(String rewardId) async {
    final Reward existing =
        _created[rewardId] ??
        (throw StateError('Reward $rewardId was not created by this client.'));
    final response = await _apiClient.get<RewardStatus>(
      '/v1/rewards/$rewardId',
      decoder: rewardStatusFromJson,
    );
    final Reward updated = existing.copyWith(status: response.data);
    _created[rewardId] = updated;
    return updated;
  }
}
