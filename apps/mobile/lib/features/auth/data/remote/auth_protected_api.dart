import '../../../../core/api/api_client.dart';

abstract interface class AuthProtectedApi {
  Future<void> logout();
  Future<void> deleteAccount();
}

abstract interface class SocialLinkApi {
  Future<void> linkSocial({required String idToken, required String password});
}

final class DioAuthProtectedApi implements AuthProtectedApi, SocialLinkApi {
  const DioAuthProtectedApi(this._client);

  final ApiClient _client;

  @override
  Future<void> linkSocial({
    required String idToken,
    required String password,
  }) async {
    await _client.post<Object?>(
      '/v1/auth/social/link',
      data: <String, Object?>{'id_token': idToken, 'password': password},
      decoder: (_) => null,
    );
  }

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
