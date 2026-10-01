import 'package:dio/dio.dart';

import '../../../app/session/app_session_controller.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_session_refresh_interceptor.dart';
import '../../../core/api/memory_access_token_store.dart';
import '../../../core/config/app_config.dart';
import '../domain/repositories/auth_repository.dart';
import 'remote/auth_protected_api.dart';
import 'remote/auth_public_api.dart';
import 'repositories/api_auth_repository.dart';
import 'session/auth_session_manager.dart';
import 'session/flutter_secure_refresh_token_store.dart';

final class AuthRuntime {
  AuthRuntime._({
    required this.repository,
    required this.sessionManager,
    required this.authenticatedApiClient,
    required ApiClient publicApiClient,
  }) : _publicApiClient = publicApiClient;

  factory AuthRuntime.create({
    required AppConfig config,
    required AppSessionController appSession,
  }) {
    final MemoryAccessTokenStore accessTokenStore = MemoryAccessTokenStore();
    final FlutterSecureRefreshTokenStore refreshTokenStore =
        FlutterSecureRefreshTokenStore();

    final ApiClient publicClient = ApiClient(config: config);
    final DioAuthPublicApi publicApi = DioAuthPublicApi(publicClient);
    final AuthSessionManager sessionManager = AuthSessionManager(
      publicApi: publicApi,
      accessTokenStore: accessTokenStore,
      refreshTokenStore: refreshTokenStore,
      appSession: appSession,
    );

    final Dio authenticatedDio = Dio();
    final ApiClient authenticatedClient = ApiClient(
      config: config,
      dio: authenticatedDio,
      accessTokenProvider: accessTokenStore,
    );
    authenticatedDio.interceptors.add(
      ApiSessionRefreshInterceptor(
        dio: authenticatedDio,
        sessionManager: sessionManager,
      ),
    );

    return AuthRuntime._(
      repository: ApiAuthRepository(
        publicApi: publicApi,
        protectedApi: DioAuthProtectedApi(authenticatedClient),
        sessionManager: sessionManager,
      ),
      sessionManager: sessionManager,
      authenticatedApiClient: authenticatedClient,
      publicApiClient: publicClient,
    );
  }

  final AuthRepository repository;
  final AuthSessionManager sessionManager;
  final ApiClient authenticatedApiClient;
  final ApiClient _publicApiClient;

  void close() {
    authenticatedApiClient.close(force: true);
    _publicApiClient.close(force: true);
  }
}
