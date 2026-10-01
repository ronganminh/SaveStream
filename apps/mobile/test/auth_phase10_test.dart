import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/api/api_client.dart';
import 'package:savestream_mobile/core/api/api_error.dart';
import 'package:savestream_mobile/core/api/api_exception.dart';
import 'package:savestream_mobile/core/api/api_session_refresh_interceptor.dart';
import 'package:savestream_mobile/core/api/memory_access_token_store.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/auth/data/remote/auth_protected_api.dart';
import 'package:savestream_mobile/features/auth/data/remote/auth_public_api.dart';
import 'package:savestream_mobile/features/auth/data/remote/auth_tokens.dart';
import 'package:savestream_mobile/features/auth/data/repositories/api_auth_repository.dart';
import 'package:savestream_mobile/features/auth/data/session/auth_session_manager.dart';
import 'package:savestream_mobile/features/auth/data/session/refresh_token_store.dart';
import 'package:savestream_mobile/features/auth/domain/repositories/auth_repository.dart';

void main() {
  AppConfig config() {
    return AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    );
  }

  test('mobile login sends client_type and decodes refresh token', () async {
    final _FakeAdapter adapter = _FakeAdapter(
      (RequestOptions options, int call) {
        expect(options.path, '/v1/auth/login');
        expect(options.data, isA<Map<String, Object?>>());
        final Map<String, Object?> data =
            options.data! as Map<String, Object?>;
        expect(data['client_type'], 'mobile');
        expect(data['email'], 'alex@example.com');

        return _jsonResponse(200, <String, Object?>{
          'access_token': 'access-1',
          'token_type': 'Bearer',
          'expires_in': 900,
          'refresh_token': 'refresh-1',
        });
      },
    );
    final Dio dio = Dio()..httpClientAdapter = adapter;
    final DioAuthPublicApi api = DioAuthPublicApi(
      ApiClient(config: config(), dio: dio),
    );

    final AuthTokenPair tokens = await api.login(
      email: 'alex@example.com',
      password: 'password-123',
    );

    expect(tokens.accessToken, 'access-1');
    expect(tokens.refreshToken, 'refresh-1');
    expect(tokens.expiresIn, 900);
  });

  test('restore rotates refresh token and restores authenticated session', () async {
    final _StubPublicApi api = _StubPublicApi()
      ..refreshHandler = (String token) async {
        expect(token, 'refresh-old');
        return const AuthTokenPair(
          accessToken: 'access-new',
          refreshToken: 'refresh-new',
          expiresIn: 900,
        );
      };
    final MemoryAccessTokenStore accessStore = MemoryAccessTokenStore();
    final MemoryRefreshTokenStore refreshStore = MemoryRefreshTokenStore(
      'refresh-old',
    );
    final AppSessionController session = AppSessionController(
      authStatus: AppAuthStatus.unauthenticated,
    );
    final AuthSessionManager manager = AuthSessionManager(
      publicApi: api,
      accessTokenStore: accessStore,
      refreshTokenStore: refreshStore,
      appSession: session,
    );

    expect(await manager.restoreSession(), isTrue);
    expect(await accessStore.getAccessToken(), 'access-new');
    expect(await refreshStore.read(), 'refresh-new');
    expect(session.isAuthenticated, isTrue);
    expect(api.refreshCalls, 1);
  });

  test('concurrent refresh requests serialize into one rotation', () async {
    final Completer<AuthTokenPair> completer = Completer<AuthTokenPair>();
    final _StubPublicApi api = _StubPublicApi()
      ..refreshHandler = (String token) {
        return completer.future;
      };
    final MemoryAccessTokenStore accessStore = MemoryAccessTokenStore();
    final MemoryRefreshTokenStore refreshStore = MemoryRefreshTokenStore(
      'refresh-old',
    );
    final AppSessionController session = AppSessionController(
      authStatus: AppAuthStatus.authenticated,
    );
    final AuthSessionManager manager = AuthSessionManager(
      publicApi: api,
      accessTokenStore: accessStore,
      refreshTokenStore: refreshStore,
      appSession: session,
    );

    final Future<String?> first = manager.refreshAccessToken();
    final Future<String?> second = manager.refreshAccessToken();
    await Future<void>.delayed(Duration.zero);

    expect(api.refreshCalls, 1);
    completer.complete(
      const AuthTokenPair(
        accessToken: 'access-new',
        refreshToken: 'refresh-new',
        expiresIn: 900,
      ),
    );

    expect(await first, 'access-new');
    expect(await second, 'access-new');
    expect(await refreshStore.read(), 'refresh-new');
  });

  test('refresh reuse or revoked session clears local credentials', () async {
    final _StubPublicApi api = _StubPublicApi()
      ..refreshHandler = (String token) async {
        throw _revoked();
      };
    final MemoryAccessTokenStore accessStore = MemoryAccessTokenStore()
      ..setAccessToken('access-old');
    final MemoryRefreshTokenStore refreshStore = MemoryRefreshTokenStore(
      'refresh-old',
    );
    final AppSessionController session = AppSessionController();
    final AuthSessionManager manager = AuthSessionManager(
      publicApi: api,
      accessTokenStore: accessStore,
      refreshTokenStore: refreshStore,
      appSession: session,
    );

    await expectLater(
      manager.refreshAccessToken(),
      throwsA(isA<ApiException>()),
    );

    expect(await accessStore.getAccessToken(), isNull);
    expect(await refreshStore.read(), isNull);
    expect(session.isAuthenticated, isFalse);
  });

  test('authenticated client refreshes one expired request and replays it', () async {
    final _StubPublicApi publicApi = _StubPublicApi()
      ..refreshHandler = (String token) async {
        return const AuthTokenPair(
          accessToken: 'access-fresh',
          refreshToken: 'refresh-fresh',
          expiresIn: 900,
        );
      };
    final MemoryAccessTokenStore accessStore = MemoryAccessTokenStore()
      ..setAccessToken('access-expired');
    final MemoryRefreshTokenStore refreshStore = MemoryRefreshTokenStore(
      'refresh-old',
    );
    final AppSessionController session = AppSessionController();
    final AuthSessionManager manager = AuthSessionManager(
      publicApi: publicApi,
      accessTokenStore: accessStore,
      refreshTokenStore: refreshStore,
      appSession: session,
    );

    final _FakeAdapter adapter = _FakeAdapter(
      (RequestOptions options, int call) {
        if (options.headers['Authorization'] == 'Bearer access-expired') {
          return _errorResponse(
            401,
            code: 'AUTH_SESSION_REVOKED',
          );
        }
        expect(options.headers['Authorization'], 'Bearer access-fresh');
        return _jsonResponse(200, <String, Object?>{'ok': true});
      },
    );
    final Dio dio = Dio()..httpClientAdapter = adapter;
    final ApiClient client = ApiClient(
      config: config(),
      dio: dio,
      accessTokenProvider: accessStore,
    );
    dio.interceptors.add(
      ApiSessionRefreshInterceptor(dio: dio, sessionManager: manager),
    );

    final response = await client.get<bool>(
      '/v1/me',
      decoder: (Object? json) {
        if (json is! Map || json['ok'] is! bool) {
          throw const FormatException();
        }
        return json['ok'] as bool;
      },
    );

    expect(response.data, isTrue);
    expect(publicApi.refreshCalls, 1);
    expect(adapter.calls, 2);
    expect(await refreshStore.read(), 'refresh-fresh');
  });

  test('logout clears local credentials even when remote revoke fails', () async {
    final _StubPublicApi publicApi = _StubPublicApi();
    final _StubProtectedApi protectedApi = _StubProtectedApi()
      ..logoutError = const ApiException(
        kind: ApiExceptionKind.network,
        retryable: true,
      );
    final MemoryAccessTokenStore accessStore = MemoryAccessTokenStore();
    final MemoryRefreshTokenStore refreshStore = MemoryRefreshTokenStore();
    final AppSessionController session = AppSessionController();
    final AuthSessionManager manager = AuthSessionManager(
      publicApi: publicApi,
      accessTokenStore: accessStore,
      refreshTokenStore: refreshStore,
      appSession: session,
    );
    await manager.storeAuthenticatedTokens(
      const AuthTokenPair(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 900,
      ),
    );
    final ApiAuthRepository repository = ApiAuthRepository(
      publicApi: publicApi,
      protectedApi: protectedApi,
      sessionManager: manager,
    );

    await repository.logout();

    expect(await accessStore.getAccessToken(), isNull);
    expect(await refreshStore.read(), isNull);
    expect(session.isAuthenticated, isFalse);
  });

  test('backend auth error codes map without parsing message text', () async {
    final _StubPublicApi publicApi = _StubPublicApi()
      ..loginError = const ApiException(
        kind: ApiExceptionKind.api,
        retryable: false,
        apiError: ApiError(
          code: 'AUTH_EMAIL_NOT_VERIFIED',
          message: 'Any localized message',
          retryable: false,
          details: <String, Object?>{},
          httpStatus: 403,
        ),
        statusCode: 403,
      );
    final AppSessionController session = AppSessionController(
      authStatus: AppAuthStatus.unauthenticated,
    );
    final ApiAuthRepository repository = ApiAuthRepository(
      publicApi: publicApi,
      protectedApi: _StubProtectedApi(),
      sessionManager: AuthSessionManager(
        publicApi: publicApi,
        accessTokenStore: MemoryAccessTokenStore(),
        refreshTokenStore: MemoryRefreshTokenStore(),
        appSession: session,
      ),
    );

    await expectLater(
      repository.signIn(
        email: 'alex@example.com',
        password: 'password-123',
      ),
      throwsA(
        isA<AuthException>().having(
          (AuthException error) => error.code,
          'code',
          AuthFailureCode.emailNotVerified,
        ),
      ),
    );
  });
}

ApiException _revoked() {
  return const ApiException(
    kind: ApiExceptionKind.unauthorized,
    retryable: false,
    apiError: ApiError(
      code: 'AUTH_SESSION_REVOKED',
      message: 'Authentication session is invalid or revoked',
      retryable: false,
      details: <String, Object?>{},
      httpStatus: 401,
    ),
    statusCode: 401,
  );
}

ResponseBody _jsonResponse(int statusCode, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

ResponseBody _errorResponse(int statusCode, {required String code}) {
  return _jsonResponse(statusCode, <String, Object?>{
    'error': <String, Object?>{
      'code': code,
      'message': 'Request failed.',
      'request_id': 'req_auth_test',
      'retryable': false,
      'details': <String, Object?>{},
    },
  });
}

typedef _FakeHandler =
    FutureOr<ResponseBody> Function(RequestOptions options, int call);

final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final _FakeHandler _handler;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    return _handler(options, calls);
  }

  @override
  void close({bool force = false}) {}
}

final class _StubPublicApi implements AuthPublicApi {
  Future<AuthTokenPair> Function(String token)? refreshHandler;
  ApiException? loginError;
  int refreshCalls = 0;

  @override
  Future<AuthTokenPair> login({
    required String email,
    required String password,
  }) async {
    final ApiException? error = loginError;
    if (error != null) throw error;
    return const AuthTokenPair(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 900,
    );
  }

  @override
  Future<AuthTokenPair> refresh({required String refreshToken}) {
    refreshCalls += 1;
    final handler = refreshHandler;
    if (handler != null) return handler(refreshToken);
    return Future<AuthTokenPair>.value(
      const AuthTokenPair(
        accessToken: 'access-new',
        refreshToken: 'refresh-new',
        expiresIn: 900,
      ),
    );
  }

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> verifyEmail({required String token}) async {}

  @override
  Future<void> resendVerification({required String email}) async {}

  @override
  Future<void> forgotPassword({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {}
}

final class _StubProtectedApi implements AuthProtectedApi {
  ApiException? logoutError;

  @override
  Future<void> logout() async {
    final ApiException? error = logoutError;
    if (error != null) throw error;
  }

  @override
  Future<void> deleteAccount() async {}
}
