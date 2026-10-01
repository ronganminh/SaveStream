import 'access_token_provider.dart';

final class MemoryAccessTokenStore implements AccessTokenProvider {
  String? _token;

  @override
  Future<String?> getAccessToken() async => _token;

  void setAccessToken(String token) {
    final String normalized = token.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(token, 'token', 'Access token cannot be empty.');
    }
    _token = normalized;
  }

  void clear() {
    _token = null;
  }
}
