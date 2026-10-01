import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/api/idempotency.dart';
import '../../domain/models/recording_summary.dart';
import '../../domain/repositories/recording_repository.dart';
import '../remote/recording_api_models.dart';
import '../remote/recording_event_source.dart';

final class ApiRecordingRepository implements RecordingRepository {
  ApiRecordingRepository({
    required ApiClient apiClient,
    RecordingEventSource? eventSource,
    IdempotencyKeyGenerator? idempotencyKeyGenerator,
    Duration realtimeBaseDelay = const Duration(milliseconds: 400),
    Duration realtimeMaxDelay = const Duration(seconds: 8),
  }) : _apiClient = apiClient,
       _eventSource = eventSource ?? DioRecordingEventSource(apiClient),
       _idempotencyKeyGenerator =
           idempotencyKeyGenerator ?? SecureIdempotencyKeyGenerator(),
       _realtimeBaseDelay = realtimeBaseDelay,
       _realtimeMaxDelay = realtimeMaxDelay;

  final ApiClient _apiClient;
  final RecordingEventSource _eventSource;
  final IdempotencyKeyGenerator _idempotencyKeyGenerator;
  final Duration _realtimeBaseDelay;
  final Duration _realtimeMaxDelay;

  @override
  Future<List<RecordingSummary>> listRecordings() async {
    final List<RecordingSummary> items = <RecordingSummary>[];
    final Set<String> seenCursors = <String>{};
    String? cursor;

    while (true) {
      final RecordingApiPage page = await _listApiPage(
        limit: 100,
        cursor: cursor,
      );
      items.addAll(page.items.map((RecordingApiModel item) => item.toDomain()));
      if (!page.hasMore) {
        return List<RecordingSummary>.unmodifiable(items);
      }
      final String nextCursor = page.nextCursor!;
      if (!seenCursors.add(nextCursor)) {
        throw const ApiException(
          kind: ApiExceptionKind.malformedResponse,
          retryable: false,
        );
      }
      cursor = nextCursor;
    }
  }

  @override
  Future<RecordingPage> listRecordingPage({
    RecordingFilter filter = RecordingFilter.all,
    String? cursor,
    int limit = 4,
  }) async {
    String? currentCursor = cursor;
    final Set<String> seenCursors = <String>{};

    while (true) {
      final RecordingApiPage page = await _listApiPage(
        limit: limit,
        cursor: currentCursor,
        status: switch (filter) {
          RecordingFilter.completed => RecordingStatus.completed.apiValue,
          RecordingFilter.failed => RecordingStatus.failed.apiValue,
          RecordingFilter.all || RecordingFilter.active => null,
        },
      );
      final List<RecordingSummary> mapped = page.items
          .map((RecordingApiModel item) => item.toDomain())
          .where((RecordingSummary item) {
            return filter != RecordingFilter.active || item.isActiveLifecycle;
          })
          .toList(growable: false);

      if (mapped.isNotEmpty ||
          !page.hasMore ||
          filter != RecordingFilter.active) {
        return RecordingPage(
          items: List<RecordingSummary>.unmodifiable(mapped),
          nextCursor: page.hasMore ? page.nextCursor : null,
        );
      }

      final String nextCursor = page.nextCursor!;
      if (!seenCursors.add(nextCursor)) {
        throw const ApiException(
          kind: ApiExceptionKind.malformedResponse,
          retryable: false,
        );
      }
      currentCursor = nextCursor;
    }
  }

  @override
  Future<RecordingSummary?> getRecording(String id) async {
    try {
      final response = await _apiClient.get<RecordingApiModel>(
        '/v1/recordings/$id',
        decoder: RecordingApiModel.fromJson,
      );
      return response.data.toDomain();
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<RecordingSummary> createRecording(
    CreateRecordingCommand command,
  ) async {
    final response = await _apiClient.post<RecordingApiModel>(
      '/v1/recordings',
      data: <String, Object?>{
        'source': <String, Object?>{
          'type': command.sourceType.apiValue,
          'value': command.sourceValue,
        },
        'max_duration_seconds': command.maxDurationSeconds,
        'quality': 'best',
        'container': 'mp4',
      },
      idempotency: IdempotencyContext.create(_idempotencyKeyGenerator),
      decoder: RecordingApiModel.fromJson,
    );
    return response.data.toDomain();
  }

  @override
  Future<RecordingSummary?> stopRecording(String id) async {
    try {
      final response = await _apiClient.post<RecordingApiModel>(
        '/v1/recordings/$id/stop',
        decoder: RecordingApiModel.fromJson,
      );
      return response.data.toDomain();
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<RecordingSummary?> retryRecording(String id) async {
    final RecordingSummary? previous = await getRecording(id);
    if (previous == null) return null;
    if (!previous.actions.canRetry) {
      throw const ApiException(
        kind: ApiExceptionKind.conflict,
        retryable: false,
      );
    }
    return createRecording(
      CreateRecordingCommand(
        sourceType: previous.sourceType,
        sourceValue: previous.sourceValue,
      ),
    );
  }

  @override
  Future<void> deleteRecording(String id) async {
    await _apiClient.delete<Object?>(
      '/v1/recordings/$id',
      decoder: (_) => null,
    );
  }

  @override
  Future<List<RecordingArtifactSummary>> listArtifacts(
    String recordingId,
  ) async {
    final response = await _apiClient.get<List<RecordingArtifactApiModel>>(
      '/v1/recordings/$recordingId/artifacts',
      decoder: recordingArtifactsFromJson,
    );
    return List<RecordingArtifactSummary>.unmodifiable(
      response.data.map((RecordingArtifactApiModel item) => item.toDomain()),
    );
  }

  @override
  Future<ArtifactDownloadUrl> createArtifactDownloadUrl(
    String artifactId,
  ) async {
    final response = await _apiClient.post<ArtifactDownloadUrl>(
      '/v1/artifacts/$artifactId/download-url',
      decoder: recordingDownloadUrlFromJson,
    );
    return response.data;
  }

  @override
  Stream<RecordingSummary?> watchRecording(String id) async* {
    RecordingSummary? current = await getRecording(id);
    yield current;
    if (current == null || !current.isActiveLifecycle) {
      return;
    }

    String? lastEventId;
    int lastSequence = -1;
    int reconnectAttempt = 0;

    while (current != null && current.isActiveLifecycle) {
      bool receivedEvent = false;
      try {
        await for (final RecordingEvent event in _eventSource.connect(
          id,
          lastEventId: lastEventId,
        )) {
          if (event.recordingId != id || event.sequence <= lastSequence) {
            continue;
          }
          receivedEvent = true;
          lastSequence = event.sequence;
          lastEventId = event.id;
          reconnectAttempt = 0;

          if (current == null) {
            return;
          }
          final RecordingSummary beforeEvent = current;
          if (beforeEvent.status == event.status) {
            current = beforeEvent.copyWith(
              status: event.status,
              durationSeconds: event.durationSeconds,
              bytesRecorded: event.bytesRecorded,
            );
          } else {
            current = await getRecording(id);
          }
          yield current;
          if (current == null || !current.isActiveLifecycle) {
            return;
          }
        }
      } on Object {
        // SSE failures fall through to the canonical REST snapshot below.
      }

      current = await _pollFallback(id, reconnectAttempt: reconnectAttempt);
      yield current;
      if (current == null || !current.isActiveLifecycle) {
        return;
      }

      if (!receivedEvent) {
        reconnectAttempt += 1;
      }
      await Future<void>.delayed(_reconnectDelay(reconnectAttempt));
    }
  }

  Future<RecordingSummary?> _pollFallback(
    String id, {
    required int reconnectAttempt,
  }) async {
    int pollAttempt = 0;
    while (true) {
      try {
        return await getRecording(id);
      } on ApiException catch (error) {
        if (!error.retryable && error.kind != ApiExceptionKind.network) {
          rethrow;
        }
        if (pollAttempt >= 3) rethrow;
      }
      await Future<void>.delayed(
        _reconnectDelay(reconnectAttempt + pollAttempt),
      );
      pollAttempt += 1;
    }
  }

  Duration _reconnectDelay(int attempt) {
    final int multiplier = 1 << attempt.clamp(0, 8);
    final int milliseconds = _realtimeBaseDelay.inMilliseconds * multiplier;
    return Duration(
      milliseconds: milliseconds.clamp(
        _realtimeBaseDelay.inMilliseconds,
        _realtimeMaxDelay.inMilliseconds,
      ),
    );
  }

  Future<RecordingApiPage> _listApiPage({
    required int limit,
    String? cursor,
    String? status,
  }) async {
    final response = await _apiClient.get<RecordingApiPage>(
      '/v1/recordings',
      queryParameters: <String, dynamic>{
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (status != null) 'status': status,
      },
      decoder: RecordingApiPage.fromJson,
    );
    return response.data;
  }
}
