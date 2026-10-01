import '../../../../core/api/api_client.dart';

abstract interface class AuthProtectedApi {
  Future<void> logout();
  Future<void> deleteAccount();
}

final class DioAuthProtectedApi implements AuthProtectedApi {
  const DioAuthProtectedApi(this._client);

  final ApiClient _client;

  @override
  Future<void> logout() async {
    await _client.post<Object?>('/v1/auth/logout', decoder: (_) => null);
  }

  @override
  Future<void> deleteAccount() async {
    await _client.delete<String>(
      '/v1/me',
      decoder: (Object? json) {
        if (json is! Map || json['message'] is! String) {
          throw const FormatException('Expected account deletion response.');
        }
        return json['message'] as String;
      },
    );
  }
}
