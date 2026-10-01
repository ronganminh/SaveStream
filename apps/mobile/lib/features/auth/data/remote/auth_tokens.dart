final class AuthTokenPair {
  const AuthTokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory AuthTokenPair.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('Expected auth token response object.');
    }

    final Object? accessToken = json['access_token'];
    final Object? refreshToken = json['refresh_token'];
    final Object? expiresIn = json['expires_in'];
    final Object? tokenType = json['token_type'];

    if (accessToken is! String ||
        accessToken.trim().isEmpty ||
        refreshToken is! String ||
        refreshToken.trim().isEmpty ||
        expiresIn is! int ||
        expiresIn <= 0 ||
        (tokenType != null && tokenType != 'Bearer')) {
      throw const FormatException('Malformed mobile auth token response.');
    }

    return AuthTokenPair(
      accessToken: accessToken.trim(),
      refreshToken: refreshToken.trim(),
      expiresIn: expiresIn,
    );
  }
}
