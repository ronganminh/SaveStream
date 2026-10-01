import 'package:dio/dio.dart';

import '../../features/auth/data/session/auth_session_manager.dart';

final class ApiSessionRefreshInterceptor extends Interceptor {
  ApiSessionRefreshInterceptor({
    required Dio dio,
    required AuthSessionManager sessionManager,
  }) : _dio = dio,
       _sessionManager = sessionManager;

  static const String _retriedKey = 'savestream.auth.refresh_retried';

  final Dio _dio;
  final AuthSessionManager _sessionManager;

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) async {
    final RequestOptions options = error.requestOptions;
    if (error.response?.statusCode != 401 ||
        options.extra[_retriedKey] == true) {
      handler.next(error);
      return;
    }

    try {
      final String? accessToken = await _sessionManager.refreshAccessToken();
      if (accessToken == null) {
        handler.next(error);
        return;
      }

      options
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..extra[_retriedKey] = true;

      final Response<dynamic> response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on Object {
      handler.next(error);
    }
  }
}
