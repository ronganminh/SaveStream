import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/api/api_client.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/settings/data/repositories/api_notification_preferences_repository.dart';
import 'package:savestream_mobile/features/settings/domain/models/notification_preferences.dart';

void main() {
  AppConfig config() {
    return AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    );
  }

  test('notification preferences map GET contract', () async {
    final Dio dio = Dio()
      ..httpClientAdapter = _FakeAdapter((RequestOptions options) {
        expect(options.method, 'GET');
        expect(options.path, '/v1/me/notification-preferences');
        return _jsonResponse(200, <String, Object?>{
          'recording_started': true,
          'recording_ready': false,
          'recording_failed': true,
          'email_supported': false,
          'updated_at': '2026-10-03T00:00:00Z',
        });
      });
    final repository = ApiNotificationPreferencesRepository(
      apiClient: ApiClient(config: config(), dio: dio),
    );

    final preferences = await repository.getPreferences();

    expect(preferences.recordingStarted, isTrue);
    expect(preferences.recordingReady, isFalse);
    expect(preferences.recordingFailed, isTrue);
  });

  test('notification preferences PATCH sends all persisted toggles', () async {
    final Dio dio = Dio()
      ..httpClientAdapter = _FakeAdapter((RequestOptions options) {
        expect(options.method, 'PATCH');
        expect(options.path, '/v1/me/notification-preferences');
        expect(options.data, <String, Object?>{
          'recording_started': false,
          'recording_ready': true,
          'recording_failed': false,
        });
        return _jsonResponse(200, <String, Object?>{
          'recording_started': false,
          'recording_ready': true,
          'recording_failed': false,
          'email_supported': false,
          'updated_at': '2026-10-03T00:00:00Z',
        });
      });
    final repository = ApiNotificationPreferencesRepository(
      apiClient: ApiClient(config: config(), dio: dio),
    );

    final saved = await repository.updatePreferences(
      const NotificationPreferences(
        recordingStarted: false,
        recordingReady: true,
        recordingFailed: false,
      ),
    );

    expect(saved.recordingStarted, isFalse);
    expect(saved.recordingReady, isTrue);
    expect(saved.recordingFailed, isFalse);
  });

  test('release config keeps store-sensitive defaults explicit', () {
    final config = AppConfig(
      environment: AppEnvironment.production,
      apiBaseUrl: Uri.parse('https://api.savestream.online'),
      externalCheckoutEnabled: false,
    );

    expect(config.isProduction, isTrue);
    expect(config.developerToolsEnabled, isFalse);
    expect(config.externalCheckoutEnabled, isFalse);
    expect(
      config.privacyPolicyUrl,
      Uri.parse('https://savestream.online/privacy'),
    );
    expect(config.termsOfUseUrl, Uri.parse('https://savestream.online/terms'));
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
