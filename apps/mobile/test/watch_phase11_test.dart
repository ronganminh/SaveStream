import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/api/api_client.dart';
import 'package:savestream_mobile/core/api/api_exception.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/channels/data/repositories/api_watch_repository.dart';
import 'package:savestream_mobile/features/channels/domain/models/watch_summary.dart';
import 'package:savestream_mobile/features/channels/domain/repositories/watch_repository.dart';
import 'package:savestream_mobile/features/channels/presentation/controllers/watch_providers.dart';

void main() {
  AppConfig config() {
    return AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    );
  }

  ApiWatchRepository repositoryFor(_FakeAdapter adapter) {
    final Dio dio = Dio()..httpClientAdapter = adapter;
    return ApiWatchRepository(
      apiClient: ApiClient(config: config(), dio: dio),
    );
  }

  test('maps every backend WatchStatus without message parsing', () async {
    final List<String> apiStatuses = <String>[
      'active',
      'paused',
      'paused_insufficient_credit',
      'paused_error',
      'disabled',
    ];
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      return _jsonResponse(200, <String, Object?>{
        'items': <Object?>[
          for (int index = 0; index < apiStatuses.length; index += 1)
            _watchJson(
              id: 'watch-$index',
              status: apiStatuses[index],
              liveStatus: index == 0 ? 'live' : 'offline',
            ),
        ],
        'pagination': <String, Object?>{'next_cursor': null, 'has_more': false},
      });
    });

    final List<WatchSummary> watches = await repositoryFor(
      adapter,
    ).listWatches();

    expect(
      watches.map((WatchSummary item) => item.status).toList(),
      <WatchStatus>[
        WatchStatus.active,
        WatchStatus.paused,
        WatchStatus.pausedInsufficientCredit,
        WatchStatus.pausedError,
        WatchStatus.disabled,
      ],
    );
    expect(watches.first.isLive, isTrue);
  });

  test(
    'walks cursor pagination while keeping screen-facing API unchanged',
    () async {
      final _FakeAdapter adapter = _FakeAdapter((
        RequestOptions options,
        int call,
      ) {
        expect(options.path, '/v1/watches');
        expect(options.queryParameters['limit'], 100);

        if (call == 1) {
          expect(options.queryParameters.containsKey('cursor'), isFalse);
          return _jsonResponse(200, <String, Object?>{
            'items': <Object?>[_watchJson(id: 'watch-1')],
            'pagination': <String, Object?>{
              'next_cursor': 'cursor-2',
              'has_more': true,
            },
          });
        }

        expect(options.queryParameters['cursor'], 'cursor-2');
        return _jsonResponse(200, <String, Object?>{
          'items': <Object?>[
            _watchJson(
              id: 'watch-2',
              creator: null,
              sourceType: 'url',
              sourceValue: 'https://www.tiktok.com/@fallback_creator',
            ),
          ],
          'pagination': <String, Object?>{
            'next_cursor': null,
            'has_more': false,
          },
        });
      });

      final List<WatchSummary> watches = await repositoryFor(
        adapter,
      ).listWatches();

      expect(adapter.calls, 2);
      expect(watches.map((WatchSummary item) => item.id), <String>[
        'watch-1',
        'watch-2',
      ]);
      expect(watches.last.creatorUsername, '@fallback_creator');
      expect(watches.last.creatorDisplayName, 'fallback_creator');
    },
  );

  test('create sends typed source and auto_record payload', () async {
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      expect(options.method, 'POST');
      expect(options.path, '/v1/watches');
      final Map<String, Object?> data = options.data! as Map<String, Object?>;
      expect(data['auto_record'], isTrue);
      expect(data['source'], <String, Object?>{
        'type': 'username',
        'value': '@ada_live',
      });
      return _jsonResponse(
        201,
        _watchJson(id: 'watch-new', sourceValue: 'ada_live'),
      );
    });

    final WatchSummary created = await repositoryFor(adapter).createWatch(
      const CreateWatchCommand(
        sourceType: WatchSourceType.username,
        sourceValue: '@ada_live',
        autoRecord: true,
      ),
    );

    expect(created.id, 'watch-new');
    expect(created.creatorUsername, '@ada_live');
  });

  test('maps Watch mutation endpoints exactly', () async {
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      switch (call) {
        case 1:
          expect(options.method, 'PATCH');
          expect(options.path, '/v1/watches/watch-1');
          expect(options.data, <String, Object?>{'auto_record': false});
          return _jsonResponse(
            200,
            _watchJson(id: 'watch-1', autoRecord: false),
          );
        case 2:
          expect(options.method, 'PATCH');
          expect(options.path, '/v1/watches/watch-1');
          expect(options.data, <String, Object?>{'status': 'paused'});
          return _jsonResponse(
            200,
            _watchJson(id: 'watch-1', status: 'paused'),
          );
        case 3:
          expect(options.method, 'POST');
          expect(options.path, '/v1/watches/watch-1/resume');
          return _jsonResponse(200, _watchJson(id: 'watch-1'));
        case 4:
          expect(options.method, 'DELETE');
          expect(options.path, '/v1/watches/watch-1');
          return ResponseBody.fromString('', 204);
        default:
          throw StateError('Unexpected Watch API call.');
      }
    });
    final ApiWatchRepository repository = repositoryFor(adapter);

    final WatchSummary? autoRecord = await repository.setAutoRecord(
      'watch-1',
      enabled: false,
    );
    final WatchSummary? paused = await repository.pauseWatch('watch-1');
    final WatchSummary? resumed = await repository.resumeWatch('watch-1');
    await repository.deleteWatch('watch-1');

    expect(autoRecord?.autoRecord, isFalse);
    expect(paused?.status, WatchStatus.paused);
    expect(resumed?.status, WatchStatus.active);
    expect(adapter.calls, 4);
  });

  test('getWatch maps RESOURCE_NOT_FOUND to null', () async {
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      return _errorResponse(
        404,
        code: 'RESOURCE_NOT_FOUND',
        message: 'Watch not found',
      );
    });

    expect(await repositoryFor(adapter).getWatch('missing'), isNull);
  });

  test('resume preserves typed 402 insufficient-credit failure', () async {
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      return _errorResponse(
        402,
        code: 'INSUFFICIENT_CREDITS',
        message: 'Localized text may change',
      );
    });

    await expectLater(
      repositoryFor(adapter).resumeWatch('watch-1'),
      throwsA(
        isA<ApiException>()
            .having(
              (ApiException error) => error.kind,
              'kind',
              ApiExceptionKind.insufficientCredits,
            )
            .having(
              (ApiException error) => error.code,
              'code',
              'INSUFFICIENT_CREDITS',
            ),
      ),
    );
  });

  test('malformed Watch status becomes typed malformed response', () async {
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      return _jsonResponse(
        200,
        _watchJson(id: 'watch-1', status: 'paused_quota'),
      );
    });

    await expectLater(
      repositoryFor(adapter).getWatch('watch-1'),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.kind,
          'kind',
          ApiExceptionKind.malformedResponse,
        ),
      ),
    );
  });

  test(
    'failed mutation still invalidates list/detail and Home revision',
    () async {
      final _ThrowingWatchRepository repository = _ThrowingWatchRepository();
      int listInvalidations = 0;
      int detailInvalidations = 0;
      int revisions = 0;
      final WatchController controller = WatchController(
        repository: repository,
        invalidateList: () => listInvalidations += 1,
        invalidateDetail: (String id) {
          expect(id, 'watch-1');
          detailInvalidations += 1;
        },
        notifyChanged: () => revisions += 1,
      );

      await expectLater(
        controller.resume('watch-1'),
        throwsA(isA<ApiException>()),
      );

      expect(listInvalidations, 1);
      expect(detailInvalidations, 1);
      expect(revisions, 1);
    },
  );
}

Map<String, Object?> _watchJson({
  required String id,
  String status = 'active',
  String liveStatus = 'unknown',
  String sourceType = 'username',
  String sourceValue = 'ada_live',
  bool autoRecord = true,
  Object? creator = _defaultCreator,
}) {
  return <String, Object?>{
    'id': id,
    'source': <String, Object?>{'type': sourceType, 'value': sourceValue},
    'creator': creator,
    'status': status,
    'live_status': liveStatus,
    'auto_record': autoRecord,
    'last_checked_at': '2026-10-01T03:00:00Z',
    'next_check_at': '2026-10-01T03:00:30Z',
    'last_live_at': '2026-09-30T18:30:00Z',
    'created_at': '2026-09-29T00:00:00Z',
    'updated_at': '2026-10-01T03:00:00Z',
  };
}

const Map<String, Object?> _defaultCreator = <String, Object?>{
  'platform': 'tiktok',
  'username': 'ada_live',
  'display_name': 'Ada Live',
  'avatar_url': null,
};

ResponseBody _jsonResponse(int statusCode, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

ResponseBody _errorResponse(
  int statusCode, {
  required String code,
  required String message,
}) {
  return _jsonResponse(statusCode, <String, Object?>{
    'error': <String, Object?>{
      'code': code,
      'message': message,
      'request_id': 'req_watch_test',
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

final class _ThrowingWatchRepository implements WatchRepository {
  @override
  Future<List<WatchSummary>> listWatches() async => const <WatchSummary>[];

  @override
  Future<WatchSummary?> getWatch(String id) async => null;

  @override
  Future<WatchSummary> createWatch(CreateWatchCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<WatchSummary?> setAutoRecord(String id, {required bool enabled}) {
    throw UnimplementedError();
  }

  @override
  Future<WatchSummary?> pauseWatch(String id) {
    throw UnimplementedError();
  }

  @override
  Future<WatchSummary?> resumeWatch(String id) async {
    throw const ApiException(
      kind: ApiExceptionKind.insufficientCredits,
      retryable: false,
    );
  }

  @override
  Future<void> deleteWatch(String id) {
    throw UnimplementedError();
  }
}
