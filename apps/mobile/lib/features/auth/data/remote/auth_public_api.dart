import '../../../../core/api/api_client.dart';
import 'auth_tokens.dart';

abstract interface class AuthPublicApi {
  Future<void> register({
    required String email,
    required String password,
  });
  Future<void> verifyEmail({required String token});
  Future<void> resendVerification({required String email});
  Future<AuthTokenPair> login({
    required String email,
    required String password,
  });
  Future<AuthTokenPair> refresh({required String refreshToken});
  Future<void> forgotPassword({required String email});
  Future<void> resetPassword({
    required String token,
    required String password,
  });
}

final class DioAuthPublicApi implements AuthPublicApi {
  const DioAuthPublicApi(this._client);

  final ApiClient _client;

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {
    await _client.post<String>(
      '/v1/auth/register',
      data: <String, Object?>{
        'email': email,
        'password': password,
        'display_name': null,
      },
      decoder: _decodeMessage,
    );
  }

  @override
  Future<void> verifyEmail({required String token}) async {
    await _client.post<String>(
      '/v1/auth/verify-email',
      data: <String, Object?>{'token': token},
      decoder: _decodeMessage,
    );
  }

  @override
  Future<void> resendVerification({required String email}) async {
    await _client.post<String>(
      '/v1/auth/resend-verification',
      data: <String, Object?>{'email': email},
      decoder: _decodeMessage,
    );
  }

  @override
  Future<AuthTokenPair> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post<AuthTokenPair>(
      '/v1/auth/login',
      data: <String, Object?>{
        'email': email,
        'password': password,
        'client_type': 'mobile',
      },
      decoder: AuthTokenPair.fromJson,
    );
    return response.data;
  }

  @override
  Future<AuthTokenPair> refresh({required String refreshToken}) async {
    final response = await _client.post<AuthTokenPair>(
      '/v1/auth/refresh',
      data: <String, Object?>{'refresh_token': refreshToken},
      decoder: AuthTokenPair.fromJson,
    );
    return response.data;
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    await _client.post<String>(
      '/v1/auth/forgot-password',
      data: <String, Object?>{'email': email},
      decoder: _decodeMessage,
    );
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await _client.post<String>(
      '/v1/auth/reset-password',
      data: <String, Object?>{'token': token, 'password': password},
      decoder: _decodeMessage,
    );
  }
}

String _decodeMessage(Object? json) {
  if (json is! Map || json['message'] is! String) {
    throw const FormatException('Expected auth message response.');
  }
  return json['message'] as String;
}
