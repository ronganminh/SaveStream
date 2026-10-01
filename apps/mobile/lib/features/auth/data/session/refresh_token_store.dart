abstract interface class RefreshTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

final class MemoryRefreshTokenStore implements RefreshTokenStore {
  MemoryRefreshTokenStore([String? token]) : _token = token;

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async {
    final String normalized = token.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        token,
        'token',
        'Refresh token cannot be empty.',
      );
    }
    _token = normalized;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}
