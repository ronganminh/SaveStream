import '../../../../app/session/app_session_controller.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/api/memory_access_token_store.dart';
import '../remote/auth_public_api.dart';
import '../remote/auth_tokens.dart';
import 'refresh_token_store.dart';

final class AuthSessionManager {
  AuthSessionManager({
    required AuthPublicApi publicApi,
    required MemoryAccessTokenStore accessTokenStore,
    required RefreshTokenStore refreshTokenStore,
    required AppSessionController appSession,
  }) : _publicApi = publicApi,
       _accessTokenStore = accessTokenStore,
       _refreshTokenStore = refreshTokenStore,
       _appSession = appSession;

  final AuthPublicApi _publicApi;
  final MemoryAccessTokenStore _accessTokenStore;
  final RefreshTokenStore _refreshTokenStore;
  final AppSessionController _appSession;

  Future<String?>? _refreshInFlight;

  Future<bool> restoreSession() async {
    try {
      final String? refreshToken = await _refreshTokenStore.read();
      if (refreshToken == null || refreshToken.trim().isEmpty) {
        _accessTokenStore.clear();
        _appSession.markUnauthenticated();
        return false;
      }

      return await refreshAccessToken() != null;
    } on Object {
      _accessTokenStore.clear();
      _appSession.markUnauthenticated();
      return false;
    }
  }

  Future<void> storeAuthenticatedTokens(AuthTokenPair tokens) async {
    try {
      await _refreshTokenStore.write(tokens.refreshToken);
    } on Object {
      await _invalidateLocalSessionBestEffort();
      rethrow;
    }

    _accessTokenStore.setAccessToken(tokens.accessToken);
    _appSession.markAuthenticated();
  }

  Future<String?> refreshAccessToken() {
    final Future<String?>? active = _refreshInFlight;
    if (active != null) {
      return active;
    }

    final Future<String?> operation = _performRefresh();
    _refreshInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<String?> _performRefresh() async {
    final String? refreshToken = await _refreshTokenStore.read();
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      await clearLocalSession();
      return null;
    }

    try {
      final AuthTokenPair rotated = await _publicApi.refresh(
        refreshToken: refreshToken,
      );
      try {
        await _refreshTokenStore.write(rotated.refreshToken);
      } on Object {
        await _invalidateLocalSessionBestEffort();
        rethrow;
      }
      _accessTokenStore.setAccessToken(rotated.accessToken);
      _appSession.markAuthenticated();
      return rotated.accessToken;
    } on ApiException catch (error) {
      if (error.code == 'AUTH_SESSION_REVOKED' ||
          error.kind == ApiExceptionKind.unauthorized) {
        await _invalidateLocalSessionBestEffort();
      }
      rethrow;
    }
  }

  Future<void> clearLocalSession() async {
    _accessTokenStore.clear();
    _appSession.markUnauthenticated();
    await _refreshTokenStore.clear();
  }

  Future<void> _invalidateLocalSessionBestEffort() async {
    _accessTokenStore.clear();
    _appSession.markUnauthenticated();
    try {
      await _refreshTokenStore.clear();
    } on Object {
      // Local auth state stays invalid even if secure-storage cleanup fails.
    }
  }
}
