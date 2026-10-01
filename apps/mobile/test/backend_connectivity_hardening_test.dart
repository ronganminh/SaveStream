import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/api/api_client.dart';
import 'package:savestream_mobile/core/api/api_exception.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/settings/data/repositories/api_profile_repository.dart';

void main() {
  AppConfig config() {
    return AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    );
  }

  test('profile repository maps the authenticated /v1/me contract', () async {
    final Dio dio = Dio()
      ..httpClientAdapter = _FakeAdapter((RequestOptions options) {
        expect(options.method, 'GET');
        expect(options.path, '/v1/me');
        return _jsonResponse(200, <String, Object?>{
          'id': 'user_1',
          'email': 'alex@example.com',
          'email_verified': true,
          'display_name': ' Alex Nguyen ',
          'locale': 'en',
          'created_at': '2026-10-01T00:00:00Z',
        });
      });
    final repository = ApiProfileRepository(
      apiClient: ApiClient(config: config(), dio: dio),
    );

    final profile = await repository.getProfile();

    expect(profile.email, 'alex@example.com');
    expect(profile.emailVerified, isTrue);
    expect(profile.displayName, 'Alex Nguyen');
  });

  test('profile repository rejects malformed backend responses', () async {
    final Dio dio = Dio()
      ..httpClientAdapter = _FakeAdapter((RequestOptions options) {
        return _jsonResponse(200, <String, Object?>{
          'email': 'alex@example.com',
          'email_verified': 'yes',
        });
      });
    final repository = ApiProfileRepository(
      apiClient: ApiClient(config: config(), dio: dio),
    );

    await expectLater(
      repository.getProfile(),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.kind,
          'kind',
          ApiExceptionKind.malformedResponse,
        ),
      ),
    );
  });
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

typedef _Handler = FutureOr<ResponseBody> Function(RequestOptions options);

final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final _Handler _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return Future<ResponseBody>.value(_handler(options));
  }

  @override
  void close({bool force = false}) {}
}
