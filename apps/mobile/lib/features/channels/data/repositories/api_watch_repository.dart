import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/models/watch_summary.dart';
import '../../domain/repositories/watch_repository.dart';
import '../remote/watch_api_models.dart';

final class ApiWatchRepository implements WatchRepository {
  const ApiWatchRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  static const int _pageSize = 100;

  final ApiClient _apiClient;

  @override
  Future<List<WatchSummary>> listWatches() async {
    final List<WatchSummary> watches = <WatchSummary>[];
    final Set<String> seenCursors = <String>{};
    String? cursor;

    while (true) {
      final response = await _apiClient.get<WatchApiPage>(
        '/v1/watches',
        queryParameters: <String, dynamic>{
          'limit': _pageSize,
          if (cursor != null) 'cursor': cursor,
        },
        decoder: WatchApiPage.fromJson,
      );
      final WatchApiPage page = response.data;
      watches.addAll(page.items.map((WatchApiModel item) => item.toDomain()));

      if (!page.hasMore) {
        return List<WatchSummary>.unmodifiable(watches);
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
  Future<WatchSummary?> getWatch(String id) async {
    try {
      final response = await _apiClient.get<WatchApiModel>(
        '/v1/watches/$id',
        decoder: WatchApiModel.fromJson,
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
  Future<WatchSummary> createWatch(CreateWatchCommand command) async {
    final response = await _apiClient.post<WatchApiModel>(
      '/v1/watches',
      data: <String, Object?>{
        'source': <String, Object?>{
          'type': command.sourceType.apiValue,
          'value': command.sourceValue,
        },
        'auto_record': command.autoRecord,
        'notify_on_live': command.notifyOnLive,
      },
      decoder: WatchApiModel.fromJson,
    );
    return response.data.toDomain();
  }

  @override
  Future<WatchSummary?> setAutoRecord(
    String id, {
    required bool enabled,
  }) async {
    return _patchWatch(id, <String, Object?>{'auto_record': enabled});
  }

  @override
  Future<WatchSummary?> setNotifyOnLive(
    String id, {
    required bool enabled,
  }) async {
    return _patchWatch(id, <String, Object?>{'notify_on_live': enabled});
  }

  @override
  Future<WatchSummary?> pauseWatch(String id) async {
    return _patchWatch(id, <String, Object?>{'status': 'paused'});
  }

  @override
  Future<WatchSummary?> resumeWatch(String id) async {
    try {
      final response = await _apiClient.post<WatchApiModel>(
        '/v1/watches/$id/resume',
        decoder: WatchApiModel.fromJson,
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
  Future<void> deleteWatch(String id) async {
    await _apiClient.delete<Object?>('/v1/watches/$id', decoder: (_) => null);
  }

  Future<WatchSummary?> _patchWatch(
    String id,
    Map<String, Object?> data,
  ) async {
    try {
      final response = await _apiClient.patch<WatchApiModel>(
        '/v1/watches/$id',
        data: data,
        decoder: WatchApiModel.fromJson,
      );
      return response.data.toDomain();
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}
