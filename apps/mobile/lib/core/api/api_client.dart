import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'access_token_provider.dart';
import 'api_auth_interceptor.dart';
import 'api_error_parser.dart';
import 'api_exception.dart';
import 'api_request_id.dart';
import 'api_response.dart';
import 'api_retry_policy.dart';
import 'api_timeouts.dart';
import 'idempotency.dart';

typedef ApiDecoder<T> = T Function(Object? json);

final class ApiClient {
  ApiClient({
    required AppConfig config,
    Dio? dio,
    AccessTokenProvider? accessTokenProvider,
    ApiTimeouts timeouts = const ApiTimeouts(),
    ApiRetryPolicy retryPolicy = const ApiRetryPolicy(),
    ApiErrorParser errorParser = const ApiErrorParser(),
  }) : _dio = dio ?? Dio(),
       _retryPolicy = retryPolicy,
       _errorParser = errorParser {
    _dio.options
      ..baseUrl = config.apiBaseUrl.toString()
      ..connectTimeout = timeouts.connect
      ..sendTimeout = timeouts.send
      ..receiveTimeout = timeouts.receive;

    if (accessTokenProvider != null) {
      _dio.interceptors.add(ApiAuthInterceptor(accessTokenProvider));
    }
  }

  final Dio _dio;
  final ApiRetryPolicy _retryPolicy;
  final ApiErrorParser _errorParser;

  Future<ApiResponse<T>> get<T>(
    String path, {
    required ApiDecoder<T> decoder,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    return request<T>(
      'GET',
      path,
      decoder: decoder,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    required ApiDecoder<T> decoder,
    Object? data,
    Map<String, dynamic>? queryParameters,
    IdempotencyContext? idempotency,
    CancelToken? cancelToken,
  }) {
    return request<T>(
      'POST',
      path,
      decoder: decoder,
      data: data,
      queryParameters: queryParameters,
      idempotency: idempotency,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<T>> put<T>(
    String path, {
    required ApiDecoder<T> decoder,
    Object? data,
    Map<String, dynamic>? queryParameters,
    IdempotencyContext? idempotency,
    CancelToken? cancelToken,
  }) {
    return request<T>(
      'PUT',
      path,
      decoder: decoder,
      data: data,
      queryParameters: queryParameters,
      idempotency: idempotency,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<T>> patch<T>(
    String path, {
    required ApiDecoder<T> decoder,
    Object? data,
    Map<String, dynamic>? queryParameters,
    IdempotencyContext? idempotency,
    CancelToken? cancelToken,
  }) {
    return request<T>(
      'PATCH',
      path,
      decoder: decoder,
      data: data,
      queryParameters: queryParameters,
      idempotency: idempotency,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    required ApiDecoder<T> decoder,
    Object? data,
    Map<String, dynamic>? queryParameters,
    IdempotencyContext? idempotency,
    CancelToken? cancelToken,
  }) {
    return request<T>(
      'DELETE',
      path,
      decoder: decoder,
      data: data,
      queryParameters: queryParameters,
      idempotency: idempotency,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<T>> request<T>(
    String method,
    String path, {
    required ApiDecoder<T> decoder,
    Object? data,
    Map<String, dynamic>? queryParameters,
    IdempotencyContext? idempotency,
    CancelToken? cancelToken,
  }) async {
    int retriesSoFar = 0;

    while (true) {
      try {
        final Response<Object?> response = await _dio.request<Object?>(
          path,
          data: data,
          queryParameters: queryParameters,
          cancelToken: cancelToken,
          options: Options(
            method: method,
            headers: <String, dynamic>{
              if (idempotency != null) 'Idempotency-Key': idempotency.key,
            },
          ),
        );

        final T decoded;
        try {
          decoded = decoder(response.data);
        } on Object {
          throw ApiException(
            kind: ApiExceptionKind.malformedResponse,
            statusCode: response.statusCode,
            requestId: requestIdFromHeaders(response.headers),
            retryable: false,
          );
        }

        return ApiResponse<T>(
          data: decoded,
          statusCode: response.statusCode ?? 0,
          requestId: requestIdFromHeaders(response.headers),
        );
      } on ApiException {
        rethrow;
      } on DioException catch (exception) {
        final ApiException mapped = _errorParser.fromDioException(exception);
        if (!_retryPolicy.shouldRetry(
          method: method,
          retriesSoFar: retriesSoFar,
          exception: mapped,
        )) {
          throw mapped;
        }

        final Duration delay = _retryPolicy.delayForRetry(
          retriesSoFar: retriesSoFar,
        );
        retriesSoFar += 1;
        if (delay != Duration.zero) {
          await Future<void>.delayed(delay);
        }
      }
    }
  }

  void close({bool force = false}) {
    _dio.close(force: force);
  }
}
