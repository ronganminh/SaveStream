import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/api/api_client.dart';
import 'package:savestream_mobile/core/api/api_exception.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/app_status/data/repositories/api_app_status_repository.dart';
import 'package:savestream_mobile/features/channels/data/repositories/api_watch_repository.dart';
import 'package:savestream_mobile/features/channels/domain/models/watch_summary.dart';
import 'package:savestream_mobile/features/devices/data/repositories/api_device_repository.dart';
import 'package:savestream_mobile/features/devices/domain/models/device_registration.dart';
import 'package:savestream_mobile/features/entitlement/data/repositories/api_entitlement_repository.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/recordings/data/repositories/api_recording_repository.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/settings/data/repositories/api_notification_preferences_repository.dart';
import 'package:savestream_mobile/features/settings/data/repositories/api_notifications_repository.dart';
import 'package:savestream_mobile/features/settings/domain/models/app_notification.dart';
import 'package:savestream_mobile/features/settings/domain/models/notification_preferences.dart';

void main() {
  test('entitlement decodes V2 minutes and limits', () async {
    final ApiClient client = _clientFor(
      _FakeAdapter((RequestOptions options, int call) {
        expect(options.path, '/v1/me/entitlement');
        return _jsonResponse(200, _entitlementJson());
      }),
    );

    final Entitlement entitlement = await ApiEntitlementRepository(
      apiClient: client,
    ).getEntitlement();

    expect(entitlement.plan, Plan.pro);
    expect(entitlement.cloudMinutesAvailable, 125);
    expect(entitlement.limits.maxWatches, 20);
    expect(entitlement.limits.maxConcurrentCloudRecordings, 3);
    expect(entitlement.local.unlimited, isTrue);
  });

  test('501 entitlement falls back to a safe Free snapshot', () async {
    final ApiClient client = _clientFor(
      _FakeAdapter(
        (RequestOptions options, int call) =>
            _errorResponse(501, code: 'NOT_IMPLEMENTED'),
      ),
    );

    final Entitlement entitlement = await ApiEntitlementRepository(
      apiClient: client,
    ).getEntitlement();

    expect(entitlement.plan, Plan.free);
    expect(entitlement.hasPurchased, isFalse);
    expect(entitlement.cloudMinutesAvailable, 0);
    expect(entitlement.limits.maxConcurrentCloudRecordings, 0);
  });

  test('501 app status never forces update or maintenance', () async {
    final ApiClient client = _clientFor(
      _FakeAdapter(
        (RequestOptions options, int call) =>
            _errorResponse(501, code: 'NOT_IMPLEMENTED'),
      ),
    );

    final status = await ApiAppStatusRepository(apiClient: client).getStatus();

    expect(status.minSupportedVersion.android, '0.0.0');
    expect(status.minSupportedVersion.ios, '0.0.0');
    expect(status.maintenance.active, isFalse);
  });

  test('device registration uses V2 PUT payload and accepts 204', () async {
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      expect(options.method, 'PUT');
      expect(options.path, '/v1/me/devices/dev%2F1');
      expect(options.data, <String, Object?>{
        'platform': 'android',
        'push_token': 'push-token',
        'device_name': 'Pixel',
        'app_version': '2.0.0',
        'locale': 'vi',
      });
      return ResponseBody.fromString('', 204);
    });
    const DeviceRegistration device = DeviceRegistration(
      deviceId: 'dev/1',
      platform: DevicePlatform.android,
      pushToken: 'push-token',
      deviceName: 'Pixel',
      appVersion: '2.0.0',
      locale: 'vi',
    );

    final DeviceRegistration stored = await ApiDeviceRepository(
      apiClient: _clientFor(adapter),
    ).register(device);

    expect(stored, same(device));
  });

  test('watch create sends notify_on_live and paginates', () async {
    final _FakeAdapter createAdapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      expect(options.path, '/v1/watches');
      expect((options.data as Map)['notify_on_live'], isFalse);
      return _jsonResponse(
        201,
        _watchJson(id: 'watch-created', notifyOnLive: false),
      );
    });
    final ApiWatchRepository createRepository = ApiWatchRepository(
      apiClient: _clientFor(createAdapter),
    );

    final WatchSummary created = await createRepository.createWatch(
      const CreateWatchCommand(
        sourceType: WatchSourceType.roomId,
        sourceValue: 'room-created',
        autoRecord: false,
        notifyOnLive: false,
      ),
    );
    expect(created.notifyOnLive, isFalse);
    expect(created.autoRecordState, AutoRecordState.off);

    final _FakeAdapter listAdapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      if (call == 1) {
        expect(options.queryParameters['cursor'], isNull);
        return _jsonResponse(200, <String, Object?>{
          'items': <Object?>[_watchJson(id: 'watch-1')],
          'pagination': <String, Object?>{
            'next_cursor': 'next-1',
            'has_more': true,
          },
        });
      }

      expect(options.queryParameters['cursor'], 'next-1');
      return _jsonResponse(200, <String, Object?>{
        'items': <Object?>[_watchJson(id: 'watch-2')],
        'pagination': <String, Object?>{'next_cursor': null, 'has_more': false},
      });
    });

    final List<WatchSummary> watches = await ApiWatchRepository(
      apiClient: _clientFor(listAdapter),
    ).listWatches();

    expect(watches.map((WatchSummary item) => item.id), <String>[
      'watch-1',
      'watch-2',
    ]);
    expect(listAdapter.calls, 2);
  });

  test('new watch errors are keyed by error.code, not message text', () async {
    final ApiException limitError = await _watchError(
      status: 409,
      code: 'WATCH_LIMIT_REACHED',
    );
    final ApiException planError = await _watchError(
      status: 403,
      code: 'PLAN_REQUIRED',
    );

    expect(limitError.code, 'WATCH_LIMIT_REACHED');
    expect(planError.code, 'PLAN_REQUIRED');
    expect(limitError.message, isNotEmpty);
    expect(planError.message, isNotEmpty);
  });

  test('notification preferences map V2 fields in both directions', () async {
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      if (call == 1) {
        expect(options.method, 'GET');
        return _jsonResponse(
          200,
          _notificationPreferencesJson(
            creatorLive: false,
            recordingExpiring: true,
            freeMinutesLow: false,
          ),
        );
      }

      expect(options.method, 'PATCH');
      expect(options.data, <String, Object?>{
        'recording_started': true,
        'recording_ready': true,
        'recording_failed': true,
        'creator_live': true,
        'recording_expiring': false,
        'free_minutes_low': true,
      });
      return _jsonResponse(
        200,
        _notificationPreferencesJson(
          creatorLive: true,
          recordingExpiring: false,
          freeMinutesLow: true,
        ),
      );
    });
    final ApiNotificationPreferencesRepository repository =
        ApiNotificationPreferencesRepository(apiClient: _clientFor(adapter));

    final NotificationPreferences initial = await repository.getPreferences();
    expect(initial.creatorLive, isFalse);
    expect(initial.recordingExpiring, isTrue);
    expect(initial.freeMinutesLow, isFalse);

    final NotificationPreferences updated = await repository.updatePreferences(
      initial.copyWith(
        creatorLive: true,
        recordingExpiring: false,
        freeMinutesLow: true,
      ),
    );
    expect(updated.creatorLive, isTrue);
    expect(updated.recordingExpiring, isFalse);
    expect(updated.freeMinutesLow, isTrue);
  });

  test(
    'notification feed maps exposed V2 types and tolerates others',
    () async {
      final ApiNotificationsRepository repository = ApiNotificationsRepository(
        apiClient: _clientFor(
          _FakeAdapter((RequestOptions options, int call) {
            return _jsonResponse(200, <String, Object?>{
              'items': <Object?>[
                _notificationJson(id: 'n1', type: 'creator_live'),
                _notificationJson(id: 'n2', type: 'recording_expiring'),
                _notificationJson(id: 'n3', type: 'free_minutes_low'),
                _notificationJson(id: 'n4', type: 'recording_missed'),
              ],
              'pagination': <String, Object?>{
                'next_cursor': null,
                'has_more': false,
              },
            });
          }),
        ),
      );

      final page = await repository.listNotifications();

      expect(page.items, hasLength(4));
      expect(page.items[0].type, AppNotificationType.other);
      expect(page.items[0].v2Type, AppNotificationV2Type.creatorLive);
      expect(page.items[1].v2Type, AppNotificationV2Type.recordingExpiring);
      expect(page.items[2].v2Type, AppNotificationV2Type.freeMinutesLow);
      expect(page.items[3].type, AppNotificationType.other);
      expect(page.items[3].v2Type, isNull);
    },
  );

  test(
    'recording maps V2 queue/retention fields and tolerates new status',
    () async {
      final ApiClient client = _clientFor(
        _FakeAdapter((RequestOptions options, int call) {
          return _jsonResponse(200, <String, Object?>{
            'items': <Object?>[
              _recordingJson(
                id: 'rec-waiting',
                status: 'waiting_for_cloud_slot',
                expiresAt: '2026-11-03T00:00:00Z',
                minutesCharged: 7,
                queuePosition: 2,
              ),
              _recordingJson(id: 'rec-future', status: 'future_backend_state'),
              _recordingJson(id: 'rec-missed', status: 'missed_no_cloud_slot'),
            ],
            'pagination': <String, Object?>{
              'next_cursor': null,
              'has_more': false,
            },
          });
        }),
      );

      final List<RecordingSummary> recordings = await ApiRecordingRepository(
        apiClient: client,
        realtimeBaseDelay: Duration.zero,
        realtimeMaxDelay: Duration.zero,
      ).listRecordings();

      expect(recordings, hasLength(3));
      expect(recordings[0].status, RecordingStatus.waitingForCloudSlot);
      expect(recordings[0].queuePosition, 2);
      expect(recordings[0].minutesCharged, 7);
      expect(recordings[0].expiresAt, DateTime.utc(2026, 11, 3));
      expect(recordings[1].status, RecordingStatus.failed);
      expect(recordings[2].status, RecordingStatus.missedNoCloudSlot);
    },
  );
}

AppConfig _testConfig() {
  return AppConfig(
    environment: AppEnvironment.local,
    apiBaseUrl: Uri.parse('http://localhost:8000'),
  );
}

ApiClient _clientFor(_FakeAdapter adapter) {
  final Dio dio = Dio();
  dio.httpClientAdapter = adapter;
  return ApiClient(config: _testConfig(), dio: dio);
}

Future<ApiException> _watchError({required int status, required String code}) {
  final ApiClient client = _clientFor(
    _FakeAdapter(
      (RequestOptions options, int call) => _errorResponse(
        status,
        code: code,
        message: 'This text is intentionally unrelated and can change.',
      ),
    ),
  );
  return _capture(
    client.post<Object?>('/v1/watches', decoder: (Object? json) => json),
  );
}

Future<ApiException> _capture(Future<Object?> future) async {
  try {
    await future;
    fail('Expected ApiException.');
  } on ApiException catch (error) {
    return error;
  }
}

Map<String, Object?> _entitlementJson() {
  return <String, Object?>{
    'plan': 'pro',
    'has_purchased': true,
    'cloud_minutes_available': 125,
    'limits': <String, Object?>{
      'max_watches': 20,
      'max_concurrent_cloud_recordings': 3,
      'cloud_retention_days': 30,
    },
    'watch_count': 4,
    'local': <String, Object?>{
      'enabled': true,
      'unlimited': true,
      'daily_minutes': 0,
      'minutes_remaining': 0,
      'resets_at': '2026-10-05T00:00:00Z',
      'rewards_used_today': 0,
      'rewards_cap_per_day': 8,
      'minutes_per_reward': 10,
      'extensions_cap_per_recording': 4,
    },
    'updated_at': '2026-10-04T00:00:00Z',
  };
}

Map<String, Object?> _watchJson({
  required String id,
  bool notifyOnLive = true,
}) {
  return <String, Object?>{
    'id': id,
    'source': <String, Object?>{'type': 'room_id', 'value': 'room-$id'},
    'creator': null,
    'status': 'active',
    'live_status': 'offline',
    'auto_record': false,
    'notify_on_live': notifyOnLive,
    'auto_record_state': 'off',
    'last_checked_at': null,
    'next_check_at': null,
    'last_live_at': null,
    'created_at': '2026-10-04T00:00:00Z',
    'updated_at': '2026-10-04T00:00:00Z',
  };
}

Map<String, Object?> _notificationPreferencesJson({
  required bool creatorLive,
  required bool recordingExpiring,
  required bool freeMinutesLow,
}) {
  return <String, Object?>{
    'recording_started': true,
    'recording_ready': true,
    'recording_failed': true,
    'creator_live': creatorLive,
    'recording_expiring': recordingExpiring,
    'free_minutes_low': freeMinutesLow,
    'email_supported': false,
    'updated_at': '2026-10-04T00:00:00Z',
  };
}

Map<String, Object?> _notificationJson({
  required String id,
  required String type,
}) {
  return <String, Object?>{
    'id': id,
    'type': type,
    'title': 'Title',
    'body': 'Body',
    'read': false,
    'created_at': '2026-10-04T00:00:00Z',
    'resource_type': type == 'creator_live' ? 'watch' : 'recording',
    'resource_id': 'resource-$id',
  };
}

Map<String, Object?> _recordingJson({
  required String id,
  required String status,
  String? expiresAt,
  int minutesCharged = 0,
  int? queuePosition,
}) {
  return <String, Object?>{
    'id': id,
    'source': <String, Object?>{'type': 'room_id', 'value': 'room-$id'},
    'creator': null,
    'status': status,
    'started_at': null,
    'ended_at': null,
    'duration_seconds': 0,
    'bytes_recorded': 0,
    'estimated_max_cost': 10,
    'actual_cost': null,
    'credit_reservation_id': null,
    'actions': <String, Object?>{
      'can_stop': false,
      'can_retry': false,
      'can_delete': true,
    },
    'error': null,
    'created_at': '2026-10-04T00:00:00Z',
    'updated_at': '2026-10-04T00:00:00Z',
    'expires_at': expiresAt,
    'engine': 'cloud',
    'minutes_charged': minutesCharged,
    'queue_position': queuePosition,
  };
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

ResponseBody _errorResponse(
  int statusCode, {
  required String code,
  String message = 'Request failed.',
}) {
  return _jsonResponse(statusCode, <String, Object?>{
    'error': <String, Object?>{
      'code': code,
      'message': message,
      'request_id': 'req-c1',
      'retryable': false,
      'details': const <String, Object?>{},
    },
  });
}

typedef _FakeHandler = FutureOr<ResponseBody> Function(
  RequestOptions options,
  int call,
);

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
