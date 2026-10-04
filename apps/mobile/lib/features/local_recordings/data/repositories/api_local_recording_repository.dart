import '../../../../core/api/api_client.dart';
import '../../../../core/api/idempotency.dart';
import '../../../recordings/domain/models/recording_summary.dart';
import '../../domain/models/local_recording_models.dart';
import '../../domain/repositories/local_recording_repository.dart';

final class ApiLocalRecordingRepository implements LocalRecordingRepository {
  ApiLocalRecordingRepository({
    required ApiClient apiClient,
    IdempotencyKeyGenerator? idempotencyKeyGenerator,
  }) : _apiClient = apiClient,
       _idempotencyKeyGenerator =
           idempotencyKeyGenerator ?? SecureIdempotencyKeyGenerator();

  static const int _pageSize = 100;
  static const int _rewardExtensionSeconds = 10 * 60;

  final ApiClient _apiClient;
  final IdempotencyKeyGenerator _idempotencyKeyGenerator;
  final Map<String, LocalRecordingSession> _sessions =
      <String, LocalRecordingSession>{};

  @override
  Future<LocalRecordingSession> start({
    required String watchId,
    required String deviceId,
    String? rewardId,
  }) async {
    final response = await _apiClient.post<LocalRecordingSession>(
      '/v1/local-recordings/sessions',
      data: <String, Object?>{
        'watch_id': watchId,
        'device_id': deviceId,
        if (rewardId != null) 'reward_id': rewardId,
      },
      idempotency: IdempotencyContext.create(_idempotencyKeyGenerator),
      decoder: (Object? json) =>
          _decodeSession(json, watchId: watchId, deviceId: deviceId),
    );
    _sessions[response.data.sessionId] = response.data;
    return response.data;
  }

  @override
  Future<LocalRecordingSession> extend(
    String sessionId, {
    String? rewardId,
  }) async {
    final LocalRecordingSession current =
        _sessions[sessionId] ??
        (throw StateError('Unknown local recording session: $sessionId'));

    await _apiClient.post<Object?>(
      '/v1/local-recordings/sessions/${Uri.encodeComponent(sessionId)}/extend',
      data: <String, Object?>{if (rewardId != null) 'reward_id': rewardId},
      decoder: (_) => null,
    );

    // B4 intentionally returns 204. A3's repository contract needs the updated
    // lease, so mirror the locked rewarded-ad decision (+10 minutes) locally.
    // The Android recorder still treats the server-issued lease as authoritative
    // and never deletes already captured bytes when auth/session state changes.
    final DateTime now = DateTime.now().toUtc();
    final DateTime base = current.leaseExpiresAt.isAfter(now)
        ? current.leaseExpiresAt
        : now;
    final LocalRecordingSession extended = current.copyWith(
      grantedSeconds: current.grantedSeconds + _rewardExtensionSeconds,
      leaseExpiresAt: base.add(
        const Duration(seconds: _rewardExtensionSeconds),
      ),
    );
    _sessions[sessionId] = extended;
    return extended;
  }

  @override
  Future<LocalRecordingSummary> finish(
    String sessionId, {
    required int recordedSeconds,
    required int sizeBytes,
    required RecordingEndReason endReason,
    required RecordingStatus status,
  }) async {
    await _apiClient.post<Object?>(
      '/v1/local-recordings/sessions/${Uri.encodeComponent(sessionId)}/finish',
      data: <String, Object?>{
        'recorded_seconds': recordedSeconds,
        'size_bytes': sizeBytes,
        'end_reason': _endReasonValue(endReason),
        'status': _localStatusValue(status),
      },
      decoder: (_) => null,
    );

    final List<LocalRecordingSummary> items = await list();
    for (final LocalRecordingSummary item in items) {
      if (item.id == sessionId) {
        _sessions.remove(sessionId);
        return item;
      }
    }
    throw StateError(
      'Finished local recording $sessionId was not returned by the backend.',
    );
  }

  @override
  Future<List<LocalRecordingSummary>> list() async {
    final List<LocalRecordingSummary> items = <LocalRecordingSummary>[];
    final Set<String> seenCursors = <String>{};
    String? cursor;

    while (true) {
      final response = await _apiClient.get<_LocalRecordingPage>(
        '/v1/local-recordings',
        queryParameters: <String, dynamic>{
          'limit': _pageSize,
          if (cursor != null) 'cursor': cursor,
        },
        decoder: _LocalRecordingPage.fromJson,
      );
      items.addAll(response.data.items);
      if (!response.data.hasMore) {
        return List<LocalRecordingSummary>.unmodifiable(items);
      }

      final String? nextCursor = response.data.nextCursor;
      if (nextCursor == null || !seenCursors.add(nextCursor)) {
        throw const FormatException(
          'Local recording pagination cursor is missing or repeated.',
        );
      }
      cursor = nextCursor;
    }
  }

  @override
  Future<void> delete(String id, {required String deviceId}) async {
    await _apiClient.delete<Object?>(
      '/v1/local-recordings/${Uri.encodeComponent(id)}',
      queryParameters: <String, dynamic>{'device_id': deviceId},
      decoder: (_) => null,
    );
  }
}

LocalRecordingSession _decodeSession(
  Object? json, {
  required String watchId,
  required String deviceId,
}) {
  final Map<String, dynamic> root = _map(json);
  final Map<String, dynamic> stream = _map(root['stream']);
  final String format = stream['format'] as String;
  final Map<String, dynamic> rawHeaders = _map(stream['headers']);

  return LocalRecordingSession(
    sessionId: root['session_id'] as String,
    watchId: watchId,
    deviceId: deviceId,
    grantedSeconds: root['granted_seconds'] as int,
    leaseExpiresAt: DateTime.parse(root['lease_expires_at'] as String).toUtc(),
    streamUrl: Uri.parse(stream['url'] as String),
    streamFormat: switch (format) {
      'flv' => LocalStreamFormat.flv,
      'hls' => LocalStreamFormat.hls,
      _ => throw FormatException('Unsupported local stream format: $format'),
    },
    streamHeaders: rawHeaders.map(
      (String key, dynamic value) =>
          MapEntry<String, String>(key, value as String),
    ),
  );
}

final class _LocalRecordingPage {
  const _LocalRecordingPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory _LocalRecordingPage.fromJson(Object? json) {
    final Map<String, dynamic> root = _map(json);
    final Map<String, dynamic> pagination = _map(root['pagination']);
    return _LocalRecordingPage(
      items: (root['items'] as List<dynamic>)
          .map<LocalRecordingSummary>(_decodeSummary)
          .toList(growable: false),
      nextCursor: pagination['next_cursor'] as String?,
      hasMore: pagination['has_more'] as bool,
    );
  }

  final List<LocalRecordingSummary> items;
  final String? nextCursor;
  final bool hasMore;
}

LocalRecordingSummary _decodeSummary(dynamic json) {
  final Map<String, dynamic> root = _map(json);
  final Map<String, dynamic> creator = _map(root['creator']);
  return LocalRecordingSummary(
    id: root['id'] as String,
    watchId: root['watch_id'] as String,
    creatorDisplayName: creator['display_name'] as String,
    creatorHandle: '@${creator['username'] as String}',
    deviceId: root['device_id'] as String,
    deviceName: root['device_name'] as String,
    startedAt: DateTime.parse(root['started_at'] as String).toUtc(),
    recordedSeconds: root['recorded_seconds'] as int,
    sizeBytes: root['size_bytes'] as int,
    status: switch (root['status'] as String) {
      'completed' => RecordingStatus.completed,
      'partial' => RecordingStatus.partial,
      'recovered' => RecordingStatus.recovered,
      'failed' => RecordingStatus.failed,
      final String value => throw FormatException(
        'Unsupported local recording status: $value',
      ),
    },
  );
}

String _endReasonValue(RecordingEndReason reason) {
  return switch (reason) {
    RecordingEndReason.userStopped => 'user_stopped',
    RecordingEndReason.liveEnded => 'live_ended',
    RecordingEndReason.freeMinutesExhausted => 'free_minutes_exhausted',
    RecordingEndReason.storageLow => 'storage_low',
    RecordingEndReason.interrupted => 'interrupted',
    RecordingEndReason.error => 'error',
  };
}

String _localStatusValue(RecordingStatus status) {
  return switch (status) {
    RecordingStatus.completed || RecordingStatus.stopped => 'completed',
    RecordingStatus.partial => 'partial',
    RecordingStatus.recovered => 'recovered',
    RecordingStatus.failed => 'failed',
    _ => 'failed',
  };
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object.');
  }
  return value;
}
