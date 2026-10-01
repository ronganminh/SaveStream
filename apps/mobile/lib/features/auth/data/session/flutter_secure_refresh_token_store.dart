import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'refresh_token_store.dart';

final class FlutterSecureRefreshTokenStore implements RefreshTokenStore {
  FlutterSecureRefreshTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'savestream.auth.refresh_token.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) {
    final String normalized = token.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        token,
        'token',
        'Refresh token cannot be empty.',
      );
    }
    return _storage.write(key: _key, value: normalized);
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
