import '../../../core/api/api_client.dart';

final class CurrentUserIdSource {
  const CurrentUserIdSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<String> get() async {
    final response = await _apiClient.get<String>(
      '/v1/me',
      decoder: (Object? json) {
        if (json is! Map) {
          throw const FormatException('Expected current-user response object.');
        }
        final Object? id = json['id'];
        if (id is! String || id.trim().isEmpty) {
          throw const FormatException('Current-user id is missing.');
        }
        return id.trim();
      },
    );
    return response.data;
  }
}
