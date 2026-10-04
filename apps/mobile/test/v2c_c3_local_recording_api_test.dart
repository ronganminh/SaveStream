import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/api/api_client.dart';
import 'package:savestream_mobile/core/api/idempotency.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/local_recordings/data/repositories/api_local_recording_repository.dart';
import 'package:savestream_mobile/features/local_recordings/domain/models/local_recording_models.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';

void main() {
  test('start sends idempotency key and decodes server lease', () async {
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      expect(options.method, 'POST');
      expect(options.path, '/v1/local-recordings/sessions');
      expect(options.headers['Idempotency-Key'], 'c3-idempotency-key');
      expect(options.data, <String, Object?>{
        'watch_id': 'watch-1',
        'device_id': 'device-1',
        'reward_id': 'reward-1',
      });
      return _jsonResponse(201, _sessionJson());
    });

    final ApiLocalRecordingRepository repository = ApiLocalRecordingRepository(
      apiClient: _clientFor(adapter),
      idempotencyKeyGenerator: const _FixedIdempotencyKeyGenerator(),
    );

    final LocalRecordingSession session = await repository.start(
      watchId: 'watch-1',
      deviceId: 'device-1',
      rewardId: 'reward-1',
    );

    expect(session.sessionId, 'session-1');
    expect(session.grantedSeconds, 600);
    expect(session.streamFormat, LocalStreamFormat.flv);
    expect(session.streamHeaders['User-Agent'], 'SaveStream');
  });

  test('extend sends reward and mirrors the locked ten-minute grant', () async {
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      if (call == 1) {
        return _jsonResponse(201, _sessionJson());
      }
      expect(options.path, '/v1/local-recordings/sessions/session-1/extend');
      expect(options.data, <String, Object?>{'reward_id': 'reward-2'});
      return ResponseBody.fromString('', 204);
    });
    final ApiLocalRecordingRepository repository = ApiLocalRecordingRepository(
      apiClient: _clientFor(adapter),
      idempotencyKeyGenerator: const _FixedIdempotencyKeyGenerator(),
    );
    final LocalRecordingSession initial = await repository.start(
      watchId: 'watch-1',
      deviceId: 'device-1',
    );

    final LocalRecordingSession extended = await repository.extend(
      initial.sessionId,
      rewardId: 'reward-2',
    );

    expect(extended.grantedSeconds, initial.grantedSeconds + 600);
    expect(
      extended.leaseExpiresAt,
      initial.leaseExpiresAt.add(const Duration(minutes: 10)),
    );
  });

  test(
    'finish maps stopped to completed and returns listed metadata',
    () async {
      final _FakeAdapter adapter = _FakeAdapter((
        RequestOptions options,
        int call,
      ) {
        if (call == 1) {
          expect(options.method, 'POST');
          expect(
            options.path,
            '/v1/local-recordings/sessions/session-1/finish',
          );
          expect(options.data, <String, Object?>{
            'recorded_seconds': 42,
            'size_bytes': 1234,
            'end_reason': 'user_stopped',
            'status': 'completed',
          });
          return ResponseBody.fromString('', 204);
        }
        expect(options.method, 'GET');
        expect(options.path, '/v1/local-recordings');
        return _jsonResponse(200, <String, Object?>{
          'items': <Object?>[_summaryJson()],
          'pagination': <String, Object?>{
            'next_cursor': null,
            'has_more': false,
          },
        });
      });
      final ApiLocalRecordingRepository repository =
          ApiLocalRecordingRepository(
            apiClient: _clientFor(adapter),
            idempotencyKeyGenerator: const _FixedIdempotencyKeyGenerator(),
          );

      final summary = await repository.finish(
        'session-1',
        recordedSeconds: 42,
        sizeBytes: 1234,
        endReason: RecordingEndReason.userStopped,
        status: RecordingStatus.stopped,
      );

      expect(summary.id, 'session-1');
      expect(summary.status, RecordingStatus.completed);
      expect(summary.recordedSeconds, 42);
    },
  );
}

Map<String, Object?> _sessionJson() {
  return <String, Object?>{
    'session_id': 'session-1',
    'granted_seconds': 600,
    'lease_expires_at': '2026-10-04T11:00:00Z',
    'stream': <String, Object?>{
      'url': 'https://example.test/live.flv',
      'format': 'flv',
      'headers': <String, Object?>{'User-Agent': 'SaveStream'},
    },
  };
}

Map<String, Object?> _summaryJson() {
  return <String, Object?>{
    'id': 'session-1',
    'watch_id': 'watch-1',
    'creator': <String, Object?>{
      'platform': 'tiktok',
      'username': 'creator',
      'display_name': 'Creator',
      'avatar_url': null,
    },
    'device_id': 'device-1',
    'device_name': 'Pixel',
    'started_at': '2026-10-04T10:00:00Z',
    'recorded_seconds': 42,
    'size_bytes': 1234,
    'status': 'completed',
  };
}

ApiClient _clientFor(_FakeAdapter adapter) {
  final Dio dio = Dio();
  dio.httpClientAdapter = adapter;
  return ApiClient(
    config: AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    ),
    dio: dio,
  );
}

ResponseBody _jsonResponse(int statusCode, Object? body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
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

final class _FixedIdempotencyKeyGenerator implements IdempotencyKeyGenerator {
  const _FixedIdempotencyKeyGenerator();

  @override
  String nextKey() => 'c3-idempotency-key';
}
