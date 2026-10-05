import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/api/api_client.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/settings/data/repositories/api_notification_preferences_repository.dart';
import 'package:savestream_mobile/features/settings/data/repositories/api_notifications_repository.dart';
import 'package:savestream_mobile/features/settings/domain/models/app_notification.dart';
import 'package:savestream_mobile/features/settings/domain/models/notification_preferences.dart';
import 'package:savestream_mobile/features/settings/domain/repositories/notifications_repository.dart';
import 'package:savestream_mobile/features/settings/presentation/controllers/notification_feed_providers.dart';
import 'package:savestream_mobile/features/settings/presentation/controllers/notification_preferences_providers.dart';

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
          'creator_live': false,
          'recording_expiring': true,
          'free_minutes_low': false,
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
    expect(preferences.creatorLive, isFalse);
    expect(preferences.recordingExpiring, isTrue);
    expect(preferences.freeMinutesLow, isFalse);
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
          'creator_live': true,
          'recording_expiring': true,
          'free_minutes_low': true,
        });
        return _jsonResponse(200, <String, Object?>{
          'recording_started': false,
          'recording_ready': true,
          'recording_failed': false,
          'creator_live': true,
          'recording_expiring': true,
          'free_minutes_low': true,
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
    expect(saved.creatorLive, isTrue);
    expect(saved.recordingExpiring, isTrue);
    expect(saved.freeMinutesLow, isTrue);
  });

  test('release config keeps store-sensitive defaults explicit', () {
    final config = AppConfig(
      environment: AppEnvironment.production,
      apiBaseUrl: Uri.parse('https://api.savestream.online'),
    );

    expect(config.isProduction, isTrue);
    expect(config.developerToolsEnabled, isFalse);
    expect(
      config.privacyPolicyUrl,
      Uri.parse('https://savestream.online/privacy'),
    );
    expect(config.termsOfUseUrl, Uri.parse('https://savestream.online/terms'));
  });

  Map<String, Object?> notificationJson(String id, String type) {
    return <String, Object?>{
      'id': id,
      'type': type,
      'title': 'Title $id',
      'body': 'Body $id',
      'read': false,
      'resource_type': 'recording',
      'resource_id': 'rec-$id',
      'created_at': '2026-10-03T00:00:00Z',
    };
  }

  test(
    'notification feed follows the cursor and keeps unknown kinds',
    () async {
      final List<Map<String, dynamic>> queries = <Map<String, dynamic>>[];
      final Dio dio = Dio()
        ..httpClientAdapter = _FakeAdapter((RequestOptions options) {
          expect(options.path, '/v1/notifications');
          queries.add(options.queryParameters);
          final bool first = options.queryParameters['cursor'] == null;
          return _jsonResponse(200, <String, Object?>{
            'items': <Object?>[
              notificationJson(
                first ? 'a' : 'b',
                first ? 'recording_ready' : 'credit_low',
              ),
            ],
            'pagination': <String, Object?>{
              'next_cursor': first ? 'cursor-2' : null,
              'has_more': first,
            },
          });
        });
      final repository = ApiNotificationsRepository(
        apiClient: ApiClient(config: config(), dio: dio),
      );

      final NotificationPage first = await repository.listNotifications();
      final NotificationPage second = await repository.listNotifications(
        cursor: first.nextCursor,
      );

      expect(queries.first.containsKey('cursor'), isFalse);
      expect(queries.last['cursor'], 'cursor-2');
      expect(first.hasMore, isTrue);
      expect(first.items.single.recordingId, 'rec-a');
      expect(second.hasMore, isFalse);
      expect(second.items.single.type, AppNotificationType.other);
    },
  );

  test(
    'feed controller appends pages and keeps them when load more fails',
    () async {
      final _FakeNotifications repository = _FakeNotifications();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(notificationFeedProvider.future);
      repository.failNext = true;
      await container.read(notificationFeedProvider.notifier).loadMore();

      NotificationFeedState state = container
          .read(notificationFeedProvider)
          .value!;
      expect(state.items.map((AppNotification item) => item.id), <String>[
        'n1',
      ]);
      expect(state.loadMoreError, isNotNull);
      expect(state.hasMore, isTrue);

      await container.read(notificationFeedProvider.notifier).loadMore();
      await container.read(notificationFeedProvider.notifier).markRead('n2');

      state = container.read(notificationFeedProvider).value!;
      expect(state.items.map((AppNotification item) => item.id), <String>[
        'n1',
        'n2',
      ]);
      expect(state.items.last.read, isTrue);
      expect(state.hasMore, isFalse);
      expect(state.loadMoreError, isNull);
    },
  );

  test(
    'preference save reports failure and restores previous values',
    () async {
      final _FakePreferences repository = _FakePreferences();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          notificationPreferencesRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);

      final NotificationPreferences initial = await container.read(
        notificationPreferencesProvider.future,
      );
      repository.fail = true;
      final bool saved = await container
          .read(notificationPreferencesProvider.notifier)
          .save(initial.copyWith(recordingReady: false));

      expect(saved, isFalse);
      expect(
        container.read(notificationPreferencesProvider).value!.recordingReady,
        isTrue,
      );
    },
  );
}

final class _FakeNotifications implements NotificationsRepository {
  bool failNext = false;

  AppNotification _item(String id, {bool read = false}) {
    return AppNotification(
      id: id,
      type: AppNotificationType.recordingReady,
      title: id,
      body: id,
      read: read,
      createdAt: DateTime.utc(2026, 10, 3),
    );
  }

  @override
  Future<NotificationPage> listNotifications({String? cursor}) async {
    if (failNext) {
      failNext = false;
      throw StateError('offline');
    }
    return cursor == null
        ? NotificationPage(
            items: <AppNotification>[_item('n1')],
            nextCursor: 'c2',
          )
        : NotificationPage(items: <AppNotification>[_item('n2')]);
  }

  @override
  Future<AppNotification> markRead(String notificationId) async {
    return _item(notificationId, read: true);
  }
}

final class _FakePreferences implements NotificationPreferencesRepository {
  bool fail = false;

  @override
  Future<NotificationPreferences> getPreferences() async {
    return const NotificationPreferences(
      recordingStarted: true,
      recordingReady: true,
      recordingFailed: true,
    );
  }

  @override
  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  ) async {
    if (fail) throw StateError('rejected');
    return preferences;
  }
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
