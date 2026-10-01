import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/api/api.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';

void main() {
  AppConfig testConfig() {
    return AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    );
  }

  ApiClient clientFor(
    _FakeAdapter adapter, {
    AccessTokenProvider? accessTokenProvider,
    ApiRetryPolicy retryPolicy = const ApiRetryPolicy(
      maxRetries: 0,
      baseDelay: Duration.zero,
    ),
  }) {
    final Dio dio = Dio();
    dio.httpClientAdapter = adapter;
    return ApiClient(
      config: testConfig(),
      dio: dio,
      accessTokenProvider: accessTokenProvider,
      retryPolicy: retryPolicy,
    );
  }

  test('decodes a successful JSON response and keeps request ID', () async {
    final _FakeAdapter adapter = _FakeAdapter(
      (RequestOptions options, int call) => _jsonResponse(
        200,
        <String, Object?>{'name': 'SaveStream'},
        requestId: 'req_success',
      ),
    );
    final ApiClient client = clientFor(adapter);

    final ApiResponse<_Payload> response = await client.get<_Payload>(
      '/v1/example',
      decoder: _Payload.fromJson,
    );

    expect(response.data.name, 'SaveStream');
    expect(response.statusCode, 200);
    expect(response.requestId, 'req_success');
    expect(adapter.requests.single.uri.toString(), 'http://localhost:8000/v1/example');
  });

  test('attaches bearer token without exposing token to typed errors', () async {
    final _FakeAdapter adapter = _FakeAdapter(
      (RequestOptions options, int call) {
        expect(options.headers['Authorization'], 'Bearer secret-token');
        return _jsonResponse(200, <String, Object?>{'name': 'ok'});
      },
    );
    final ApiClient client = clientFor(
      adapter,
      accessTokenProvider: const _StaticTokenProvider('secret-token'),
    );

    await client.get<_Payload>('/v1/auth-check', decoder: _Payload.fromJson);
  });

  test('maps 401 to unauthorized and preserves envelope request ID', () async {
    final ApiException exception = await _capture(
      clientFor(
        _FakeAdapter(
          (RequestOptions options, int call) => _errorResponse(
            401,
            code: 'AUTH_REQUIRED',
            requestId: 'req_401',
          ),
        ),
      ).get<_Payload>('/v1/private', decoder: _Payload.fromJson),
    );

    expect(exception.kind, ApiExceptionKind.unauthorized);
    expect(exception.code, 'AUTH_REQUIRED');
    expect(exception.requestId, 'req_401');
    expect(exception.statusCode, 401);
  });

  test('maps 402 insufficient credits without parsing message text', () async {
    final ApiException exception = await _capture(
      clientFor(
        _FakeAdapter(
          (RequestOptions options, int call) => _errorResponse(
            402,
            code: 'INSUFFICIENT_CREDITS',
            message: 'Localized text can change.',
            requestId: 'req_402',
            details: <String, Object?>{'available': 1.2},
          ),
        ),
      ).post<_Payload>('/v1/recordings', decoder: _Payload.fromJson),
    );

    expect(exception.kind, ApiExceptionKind.insufficientCredits);
    expect(exception.code, 'INSUFFICIENT_CREDITS');
    expect(exception.apiError?.details['available'], 1.2);
  });

  test('maps 409 to typed conflict', () async {
    final ApiException exception = await _capture(
      clientFor(
        _FakeAdapter(
          (RequestOptions options, int call) =>
              _errorResponse(409, code: 'IDEMPOTENCY_CONFLICT'),
        ),
      ).post<_Payload>('/v1/command', decoder: _Payload.fromJson),
    );

    expect(exception.kind, ApiExceptionKind.conflict);
    expect(exception.code, 'IDEMPOTENCY_CONFLICT');
  });

  test('maps 429 and keeps retryable flag', () async {
    final ApiException exception = await _capture(
      clientFor(
        _FakeAdapter(
          (RequestOptions options, int call) => _errorResponse(
            429,
            code: 'RATE_LIMITED',
            retryable: true,
          ),
        ),
      ).get<_Payload>('/v1/limited', decoder: _Payload.fromJson),
    );

    expect(exception.kind, ApiExceptionKind.rateLimited);
    expect(exception.retryable, isTrue);
  });

  test('maps 5xx to typed server error', () async {
    final ApiException exception = await _capture(
      clientFor(
        _FakeAdapter(
          (RequestOptions options, int call) =>
              _errorResponse(503, code: 'SERVICE_UNAVAILABLE'),
        ),
      ).get<_Payload>('/v1/health', decoder: _Payload.fromJson),
    );

    expect(exception.kind, ApiExceptionKind.server);
    expect(exception.statusCode, 503);
  });

  test('maps connect and receive timeouts to typed timeout', () async {
    for (final DioExceptionType type in <DioExceptionType>[
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      final ApiException exception = await _capture(
        clientFor(
          _FakeAdapter((RequestOptions options, int call) {
            throw DioException(requestOptions: options, type: type);
          }),
        ).get<_Payload>('/v1/slow', decoder: _Payload.fromJson),
      );

      expect(exception.kind, ApiExceptionKind.timeout);
      expect(exception.retryable, isTrue);
    }
  });

  test('maps connection failures to typed network error', () async {
    final ApiException exception = await _capture(
      clientFor(
        _FakeAdapter((RequestOptions options, int call) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }),
      ).get<_Payload>('/v1/offline', decoder: _Payload.fromJson),
    );

    expect(exception.kind, ApiExceptionKind.network);
    expect(exception.retryable, isTrue);
  });

  test('malformed backend envelope never leaks raw Dio exception', () async {
    final ApiException exception = await _capture(
      clientFor(
        _FakeAdapter(
          (RequestOptions options, int call) => _jsonResponse(
            500,
            <String, Object?>{'unexpected': true},
            requestId: 'req_header_fallback',
          ),
        ),
      ).get<_Payload>('/v1/malformed', decoder: _Payload.fromJson),
    );

    expect(exception.kind, ApiExceptionKind.malformedResponse);
    expect(exception.requestId, 'req_header_fallback');
    expect(exception.toString(), isNot(contains('DioException')));
  });

  test('retries GET once for retryable server failure', () async {
    final _FakeAdapter adapter = _FakeAdapter(
      (RequestOptions options, int call) {
        if (call == 1) {
          return _errorResponse(
            503,
            code: 'TEMPORARY_FAILURE',
            retryable: true,
          );
        }
        return _jsonResponse(200, <String, Object?>{'name': 'recovered'});
      },
    );
    final ApiClient client = clientFor(
      adapter,
      retryPolicy: const ApiRetryPolicy(
        maxRetries: 1,
        baseDelay: Duration.zero,
      ),
    );

    final ApiResponse<_Payload> response = await client.get<_Payload>(
      '/v1/retry',
      decoder: _Payload.fromJson,
    );

    expect(response.data.name, 'recovered');
    expect(adapter.calls, 2);
  });

  test('does not automatically retry mutation commands', () async {
    final _FakeAdapter adapter = _FakeAdapter(
      (RequestOptions options, int call) =>
          _errorResponse(503, code: 'TEMPORARY_FAILURE', retryable: true),
    );
    final ApiClient client = clientFor(
      adapter,
      retryPolicy: const ApiRetryPolicy(
        maxRetries: 1,
        baseDelay: Duration.zero,
      ),
    );

    final ApiException exception = await _capture(
      client.post<_Payload>('/v1/command', decoder: _Payload.fromJson),
    );

    expect(exception.kind, ApiExceptionKind.server);
    expect(adapter.calls, 1);
  });

  test('reuses idempotency key for one logical operation', () async {
    final _SequenceKeyGenerator generator = _SequenceKeyGenerator();
    final IdempotencyContext first = IdempotencyContext.create(generator);
    final IdempotencyContext second = IdempotencyContext.create(generator);
    final _FakeAdapter adapter = _FakeAdapter(
      (RequestOptions options, int call) =>
          _jsonResponse(200, <String, Object?>{'name': 'ok'}),
    );
    final ApiClient client = clientFor(adapter);

    await client.post<_Payload>(
      '/v1/command',
      decoder: _Payload.fromJson,
      idempotency: first,
    );
    await client.post<_Payload>(
      '/v1/command',
      decoder: _Payload.fromJson,
      idempotency: first,
    );
    await client.post<_Payload>(
      '/v1/command',
      decoder: _Payload.fromJson,
      idempotency: second,
    );

    final List<Object?> keys = adapter.requests
        .map((RequestOptions request) => request.headers['Idempotency-Key'])
        .toList();
    expect(keys[0], first.key);
    expect(keys[1], first.key);
    expect(keys[2], second.key);
    expect(first.key, isNot(second.key));
  });
}

Future<ApiException> _capture(Future<Object?> future) async {
  try {
    await future;
    fail('Expected ApiException.');
  } on ApiException catch (exception) {
    return exception;
  }
}

ResponseBody _jsonResponse(
  int statusCode,
  Object body, {
  String? requestId,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      if (requestId != null) 'x-request-id': <String>[requestId],
    },
  );
}

ResponseBody _errorResponse(
  int statusCode, {
  required String code,
  String message = 'Request failed.',
  String? requestId,
  bool retryable = false,
  Map<String, Object?> details = const <String, Object?>{},
}) {
  return _jsonResponse(statusCode, <String, Object?>{
    'error': <String, Object?>{
      'code': code,
      'message': message,
      'request_id': requestId,
      'retryable': retryable,
      'details': details,
    },
  });
}

typedef _FakeHandler =
    FutureOr<ResponseBody> Function(RequestOptions options, int call);

final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final _FakeHandler _handler;
  final List<RequestOptions> requests = <RequestOptions>[];
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    requests.add(options);
    return _handler(options, calls);
  }

  @override
  void close({bool force = false}) {}
}

final class _Payload {
  const _Payload(this.name);

  final String name;

  factory _Payload.fromJson(Object? json) {
    if (json is! Map || json['name'] is! String) {
      throw const FormatException('Expected payload name.');
    }
    return _Payload(json['name'] as String);
  }
}

final class _StaticTokenProvider implements AccessTokenProvider {
  const _StaticTokenProvider(this.token);

  final String token;

  @override
  Future<String?> getAccessToken() async => token;
}

final class _SequenceKeyGenerator implements IdempotencyKeyGenerator {
  int _value = 0;

  @override
  String nextKey() {
    _value += 1;
    return 'idem_test_$_value';
  }
}
