import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/api/access_token_provider.dart';
import 'package:savestream_mobile/core/api/api_client.dart';
import 'package:savestream_mobile/core/api/idempotency.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/recordings/data/remote/recording_event_source.dart';
import 'package:savestream_mobile/features/recordings/data/repositories/api_recording_repository.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';

void main() {
  AppConfig config() {
    return AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    );
  }

  ApiRecordingRepository repositoryFor(
    _FakeAdapter adapter, {
    RecordingEventSource? eventSource,
    IdempotencyKeyGenerator? keyGenerator,
  }) {
    final Dio dio = Dio()..httpClientAdapter = adapter;
    return ApiRecordingRepository(
      apiClient: ApiClient(config: config(), dio: dio),
      eventSource: eventSource,
      idempotencyKeyGenerator: keyGenerator,
      realtimeBaseDelay: Duration.zero,
      realtimeMaxDelay: Duration.zero,
    );
  }

  test('secure idempotency generator produces UUID v4 keys', () {
    final String key = SecureIdempotencyKeyGenerator().nextKey();
    expect(
      key,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test(
    'create recording sends backend UUID idempotency and frozen payload',
    () async {
      final _FakeAdapter adapter = _FakeAdapter((
        RequestOptions options,
        int call,
      ) {
        expect(options.method, 'POST');
        expect(options.path, '/v1/recordings');
        expect(
          options.headers['Idempotency-Key'],
          '00000000-0000-4000-8000-000000000001',
        );
        expect(options.data, <String, Object?>{
          'source': <String, Object?>{'type': 'username', 'value': 'ada_live'},
          'max_duration_seconds': 3600,
          'quality': 'best',
          'container': 'mp4',
        });
        return _jsonResponse(
          202,
          _recordingJson(id: 'rec-create', status: 'queued'),
        );
      });

      final RecordingSummary created =
          await repositoryFor(
            adapter,
            keyGenerator: const _FixedKeyGenerator(
              '00000000-0000-4000-8000-000000000001',
            ),
          ).createRecording(
            const CreateRecordingCommand(
              sourceType: RecordingSourceType.username,
              sourceValue: 'ada_live',
              maxDurationSeconds: 3600,
            ),
          );

      expect(created.id, 'rec-create');
      expect(created.status, RecordingStatus.queued);
      expect(created.actions.canStop, isTrue);
    },
  );

  test('maps all recording statuses and server action flags', () async {
    final List<String> statuses = <String>[
      'queued',
      'resolving',
      'waiting_live',
      'recording',
      'processing',
      'uploading',
      'completed',
      'failed',
      'stop_requested',
      'stopped',
    ];
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      return _jsonResponse(200, <String, Object?>{
        'items': <Object?>[
          for (int index = 0; index < statuses.length; index += 1)
            _recordingJson(
              id: 'rec-$index',
              status: statuses[index],
              canStop: index == 0,
              canRetry: index == 7,
              canDelete: index >= 6,
            ),
        ],
        'pagination': <String, Object?>{'next_cursor': null, 'has_more': false},
      });
    });

    final List<RecordingSummary> items = await repositoryFor(
      adapter,
    ).listRecordings();

    expect(
      items.map((RecordingSummary item) => item.status).toList(),
      RecordingStatus.values,
    );
    expect(items.first.actions.canStop, isTrue);
    expect(items[7].actions.canRetry, isTrue);
    expect(items.last.actions.canDelete, isTrue);
  });

  test('recording list consumes backend cursor pagination', () async {
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      expect(options.path, '/v1/recordings');
      if (call == 1) {
        expect(options.queryParameters.containsKey('cursor'), isFalse);
        return _jsonResponse(200, <String, Object?>{
          'items': <Object?>[_recordingJson(id: 'rec-1')],
          'pagination': <String, Object?>{
            'next_cursor': 'cursor-2',
            'has_more': true,
          },
        });
      }
      expect(options.queryParameters['cursor'], 'cursor-2');
      return _jsonResponse(200, <String, Object?>{
        'items': <Object?>[_recordingJson(id: 'rec-2')],
        'pagination': <String, Object?>{'next_cursor': null, 'has_more': false},
      });
    });

    final List<RecordingSummary> items = await repositoryFor(
      adapter,
    ).listRecordings();

    expect(items.map((RecordingSummary item) => item.id), <String>[
      'rec-1',
      'rec-2',
    ]);
    expect(adapter.calls, 2);
  });

  test(
    'active filter skips empty backend pages without losing cursor',
    () async {
      final _FakeAdapter adapter = _FakeAdapter((
        RequestOptions options,
        int call,
      ) {
        if (call == 1) {
          return _jsonResponse(200, <String, Object?>{
            'items': <Object?>[
              _recordingJson(id: 'completed', status: 'completed'),
            ],
            'pagination': <String, Object?>{
              'next_cursor': 'cursor-active',
              'has_more': true,
            },
          });
        }
        expect(options.queryParameters['cursor'], 'cursor-active');
        return _jsonResponse(200, <String, Object?>{
          'items': <Object?>[
            _recordingJson(id: 'recording', status: 'recording'),
          ],
          'pagination': <String, Object?>{
            'next_cursor': null,
            'has_more': false,
          },
        });
      });

      final RecordingPage page = await repositoryFor(
        adapter,
      ).listRecordingPage(filter: RecordingFilter.active, limit: 4);

      expect(page.items.single.id, 'recording');
      expect(page.nextCursor, isNull);
      expect(adapter.calls, 2);
    },
  );

  test('stop and delete use exact recording endpoints', () async {
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      if (call == 1) {
        expect(options.method, 'POST');
        expect(options.path, '/v1/recordings/rec-1/stop');
        return _jsonResponse(
          202,
          _recordingJson(id: 'rec-1', status: 'stop_requested', canStop: false),
        );
      }
      expect(options.method, 'DELETE');
      expect(options.path, '/v1/recordings/rec-1');
      return ResponseBody.fromString('', 204);
    });
    final ApiRecordingRepository repository = repositoryFor(adapter);

    final RecordingSummary? stopped = await repository.stopRecording('rec-1');
    await repository.deleteRecording('rec-1');

    expect(stopped?.status, RecordingStatus.stopRequested);
    expect(adapter.calls, 2);
  });

  test('retry creates a new recording from the failed source', () async {
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      if (call == 1) {
        expect(options.method, 'GET');
        return _jsonResponse(
          200,
          _recordingJson(
            id: 'failed-1',
            status: 'failed',
            canRetry: true,
            canDelete: true,
            sourceValue: 'ada_live',
          ),
        );
      }
      expect(options.method, 'POST');
      expect(options.path, '/v1/recordings');
      return _jsonResponse(
        202,
        _recordingJson(id: 'retry-2', status: 'queued'),
      );
    });

    final RecordingSummary? retried = await repositoryFor(
      adapter,
      keyGenerator: const _FixedKeyGenerator(
        '00000000-0000-4000-8000-000000000002',
      ),
    ).retryRecording('failed-1');

    expect(retried?.id, 'retry-2');
    expect(adapter.calls, 2);
  });

  test('artifacts and presigned URLs are requested fresh', () async {
    int downloadCalls = 0;
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      if (options.path.endsWith('/artifacts')) {
        return _jsonResponse(200, <String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'id': 'artifact-1',
              'recording_id': 'rec-1',
              'kind': 'video',
              'container': 'mp4',
              'size_bytes': 1234,
              'checksum_sha256': 'abc123',
              'created_at': '2026-10-01T04:00:00Z',
            },
          ],
        });
      }
      downloadCalls += 1;
      return _jsonResponse(200, <String, Object?>{
        'url': 'https://storage.example.com/video.mp4?token=$downloadCalls',
        'expires_at': '2026-10-01T05:00:00Z',
      });
    });
    final ApiRecordingRepository repository = repositoryFor(adapter);

    final List<RecordingArtifactSummary> artifacts = await repository
        .listArtifacts('rec-1');
    final ArtifactDownloadUrl first = await repository
        .createArtifactDownloadUrl(artifacts.single.id);
    final ArtifactDownloadUrl second = await repository
        .createArtifactDownloadUrl(artifacts.single.id);

    expect(artifacts.single.sizeBytes, 1234);
    expect(first.uri, isNot(second.uri));
    expect(downloadCalls, 2);
  });

  test('SSE supplies bearer and Last-Event-ID and decodes progress', () async {
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      expect(options.headers['Authorization'], 'Bearer access-token');
      expect(options.headers['Last-Event-ID'], 'event-0');
      expect(options.headers['Accept'], 'text/event-stream');
      return _sseResponse(
        'id: event-1\n'
        'event: recording.recording\n'
        'data: ${jsonEncode(_eventJson(id: 'event-1', sequence: 1))}\n\n',
      );
    });
    final Dio dio = Dio()..httpClientAdapter = adapter;
    final RecordingEventSource source = DioRecordingEventSource(
      ApiClient(
        config: config(),
        dio: dio,
        accessTokenProvider: const _StaticTokenProvider('access-token'),
      ),
    );

    final List<RecordingEvent> events = await source
        .connect('rec-1', lastEventId: 'event-0')
        .toList();

    expect(events.single.id, 'event-1');
    expect(events.single.sequence, 1);
    expect(events.single.status, RecordingStatus.recording);
    expect(events.single.durationSeconds, 12);
    expect(events.single.bytesRecorded, 3456);
  });

  test('realtime reconnects with Last-Event-ID and dedupes sequence', () async {
    final _ScriptedEventSource eventSource = _ScriptedEventSource(
      <List<RecordingEvent>>[
        <RecordingEvent>[_event(id: 'event-1', sequence: 1)],
        <RecordingEvent>[
          _event(id: 'event-1', sequence: 1),
          _event(id: 'event-2', sequence: 2, status: RecordingStatus.completed),
        ],
      ],
    );

    int getCalls = 0;
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      getCalls += 1;
      final bool terminal = getCalls >= 4;
      return _jsonResponse(
        200,
        _recordingJson(
          id: 'rec-1',
          status: terminal ? 'completed' : 'recording',
          canStop: !terminal,
          canDelete: terminal,
        ),
      );
    });

    final List<RecordingSummary?> snapshots = await repositoryFor(
      adapter,
      eventSource: eventSource,
    ).watchRecording('rec-1').toList();

    expect(eventSource.lastEventIds, <String?>[null, 'event-1']);
    expect(
      snapshots.whereType<RecordingSummary>().last.status,
      RecordingStatus.completed,
    );
    expect(
      snapshots
          .whereType<RecordingSummary>()
          .where(
            (RecordingSummary item) => item.status == RecordingStatus.completed,
          )
          .length,
      1,
    );
  });
}

Map<String, Object?> _recordingJson({
  required String id,
  String status = 'recording',
  String sourceType = 'username',
  String sourceValue = 'ada_live',
  bool canStop = true,
  bool canRetry = false,
  bool canDelete = false,
}) {
  return <String, Object?>{
    'id': id,
    'source': <String, Object?>{'type': sourceType, 'value': sourceValue},
    'creator': <String, Object?>{
      'platform': 'tiktok',
      'username': 'ada_live',
      'display_name': 'Ada Live',
      'avatar_url': null,
    },
    'status': status,
    'started_at': status == 'queued' ? null : '2026-10-01T03:00:00Z',
    'ended_at': status == 'completed' ? '2026-10-01T04:00:00Z' : null,
    'duration_seconds': 120,
    'bytes_recorded': 4096,
    'estimated_max_cost': 4,
    'actual_cost': status == 'completed' ? 2 : null,
    'credit_reservation_id': 'reservation-1',
    'actions': <String, Object?>{
      'can_stop': canStop,
      'can_retry': canRetry,
      'can_delete': canDelete,
    },
    'error': status == 'failed'
        ? <String, Object?>{
            'code': 'STREAM_UNAVAILABLE',
            'message': 'Stream ended.',
            'retryable': true,
          }
        : null,
    'created_at': '2026-10-01T02:59:00Z',
    'updated_at': '2026-10-01T03:02:00Z',
  };
}

Map<String, Object?> _eventJson({
  required String id,
  required int sequence,
  String status = 'recording',
}) {
  return <String, Object?>{
    'id': id,
    'sequence': sequence,
    'type': 'recording.$status',
    'recording_id': 'rec-1',
    'created_at': '2026-10-01T03:00:00Z',
    'data': <String, Object?>{
      'status': status,
      'duration_seconds': 12,
      'bytes_recorded': 3456,
    },
  };
}

RecordingEvent _event({
  required String id,
  required int sequence,
  RecordingStatus status = RecordingStatus.recording,
}) {
  return RecordingEvent(
    id: id,
    sequence: sequence,
    type: 'recording.${status.apiValue}',
    recordingId: 'rec-1',
    createdAt: DateTime.utc(2026, 10, 1, 3),
    status: status,
    durationSeconds: 12,
    bytesRecorded: 3456,
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

ResponseBody _sseResponse(String body) {
  return ResponseBody(
    Stream<Uint8List>.value(Uint8List.fromList(utf8.encode(body))),
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['text/event-stream'],
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

final class _StaticTokenProvider implements AccessTokenProvider {
  const _StaticTokenProvider(this.token);

  final String token;

  @override
  Future<String?> getAccessToken() async => token;
}

final class _FixedKeyGenerator implements IdempotencyKeyGenerator {
  const _FixedKeyGenerator(this.key);

  final String key;

  @override
  String nextKey() => key;
}

final class _ScriptedEventSource implements RecordingEventSource {
  _ScriptedEventSource(this.events);

  final List<List<RecordingEvent>> events;
  final List<String?> lastEventIds = <String?>[];
  int _calls = 0;

  @override
  Stream<RecordingEvent> connect(
    String recordingId, {
    String? lastEventId,
  }) async* {
    lastEventIds.add(lastEventId);
    final int index = _calls;
    _calls += 1;
    if (index >= events.length) {
      return;
    }
    for (final RecordingEvent event in events[index]) {
      yield event;
    }
  }
}
