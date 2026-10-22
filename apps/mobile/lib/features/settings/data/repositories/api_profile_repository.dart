import '../../../../core/api/api_client.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../remote/profile_api_models.dart';

final class ApiProfileRepository implements ProfileRepository {
  const ApiProfileRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<UserProfile> getProfile() async {
    final response = await _apiClient.get<UserProfile>(
      '/v1/me',
      decoder: userProfileFromJson,
    );
    return response.data;
  }

  @override
  Future<UserProfile> updateDisplayName(String? displayName) async {
    final String? value = displayName?.trim();
    final response = await _apiClient.patch<UserProfile>(
      '/v1/me',
      data: <String, Object?>{
        'display_name': value == null || value.isEmpty ? null : value,
      },
      decoder: userProfileFromJson,
    );
    return response.data;
  }
}
