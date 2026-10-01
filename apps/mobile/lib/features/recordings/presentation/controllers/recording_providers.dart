import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_providers.dart';
import '../../data/repositories/mock_recording_repository.dart';
import '../../domain/models/recording_summary.dart';
import '../../domain/repositories/recording_repository.dart';

final Provider<RecordingRepository> recordingRepositoryProvider =
    Provider<RecordingRepository>(
      (ref) => MockRecordingRepository(ref.watch(mockBehaviorProvider)),
    );

final NotifierProvider<RecordingRevisionNotifier, int>
recordingRevisionProvider = NotifierProvider<RecordingRevisionNotifier, int>(
  RecordingRevisionNotifier.new,
);

class RecordingRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state += 1;
  }
}

class RecordingListState {
  const RecordingListState({
    required this.filter,
    required this.items,
    required this.nextCursor,
    this.isRefreshing = false,
    this.refreshError,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final RecordingFilter filter;
  final List<RecordingSummary> items;
  final String? nextCursor;
  final bool isRefreshing;
  final Object? refreshError;
  final bool isLoadingMore;
  final Object? loadMoreError;

  RecordingListState copyWith({
    RecordingFilter? filter,
    List<RecordingSummary>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isRefreshing,
    Object? refreshError,
    bool clearRefreshError = false,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return RecordingListState(
      filter: filter ?? this.filter,
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshError: clearRefreshError
          ? null
          : refreshError ?? this.refreshError,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: clearLoadMoreError
          ? null
          : loadMoreError ?? this.loadMoreError,
    );
  }
}

final AsyncNotifierProvider<RecordingListController, RecordingListState>
recordingListControllerProvider =
    AsyncNotifierProvider<RecordingListController, RecordingListState>(
      RecordingListController.new,
    );

class RecordingListController extends AsyncNotifier<RecordingListState> {
  @override
  Future<RecordingListState> build() {
    return _loadFirstPage(RecordingFilter.all);
  }

  Future<void> setFilter(RecordingFilter filter) async {
    final RecordingListState? current = state.value;
    if (current?.filter == filter) {
      return;
    }
    state = const AsyncLoading<RecordingListState>();
    state = await AsyncValue.guard<RecordingListState>(
      () => _loadFirstPage(filter),
    );
  }

  Future<void> refresh() async {
    final RecordingListState? current = state.value;
    final RecordingFilter filter = current?.filter ?? RecordingFilter.all;

    if (current == null) {
      state = const AsyncLoading<RecordingListState>();
      state = await AsyncValue.guard<RecordingListState>(
        () => _loadFirstPage(filter),
      );
      return;
    }

    state = AsyncData<RecordingListState>(
      current.copyWith(
        isRefreshing: true,
        clearRefreshError: true,
        clearLoadMoreError: true,
      ),
    );

    try {
      state = AsyncData<RecordingListState>(await _loadFirstPage(filter));
    } on Object catch (error) {
      state = AsyncData<RecordingListState>(
        current.copyWith(
          isRefreshing: false,
          refreshError: error,
          clearLoadMoreError: true,
        ),
      );
    }
  }

  Future<void> loadMore() async {
    final RecordingListState? current = state.value;
    if (current == null ||
        current.nextCursor == null ||
        current.isLoadingMore) {
      return;
    }

    state = AsyncData<RecordingListState>(
      current.copyWith(
        isLoadingMore: true,
        clearLoadMoreError: true,
        clearRefreshError: true,
      ),
    );

    try {
      final RecordingPage page = await ref
          .read(recordingRepositoryProvider)
          .listRecordingPage(
            filter: current.filter,
            cursor: current.nextCursor,
          );
      state = AsyncData<RecordingListState>(
        RecordingListState(
          filter: current.filter,
          items: <RecordingSummary>[...current.items, ...page.items],
          nextCursor: page.nextCursor,
        ),
      );
    } on Object catch (error) {
      state = AsyncData<RecordingListState>(
        current.copyWith(
          isLoadingMore: false,
          loadMoreError: error,
          clearRefreshError: true,
        ),
      );
    }
  }

  Future<RecordingListState> _loadFirstPage(RecordingFilter filter) async {
    final RecordingPage page = await ref
        .read(recordingRepositoryProvider)
        .listRecordingPage(filter: filter);
    return RecordingListState(
      filter: filter,
      items: page.items,
      nextCursor: page.nextCursor,
    );
  }
}

final recordingDetailProvider =
    FutureProvider.family<RecordingSummary?, String>((ref, id) {
      ref.watch(recordingRevisionProvider);
      return ref.watch(recordingRepositoryProvider).getRecording(id);
    });

final recordingRealtimeProvider = StreamProvider.autoDispose
    .family<RecordingSummary?, String>((ref, id) async* {
      await for (final RecordingSummary? recording
          in ref.watch(recordingRepositoryProvider).watchRecording(id)) {
        if (recording != null && !recording.isActiveLifecycle) {
          ref.invalidate(recordingArtifactsProvider(id));
        }
        yield recording;
      }
    });

final recordingArtifactsProvider =
    FutureProvider.family<List<RecordingArtifactSummary>, String>((ref, id) {
      ref.watch(recordingRevisionProvider);
      return ref.watch(recordingRepositoryProvider).listArtifacts(id);
    });

final Provider<RecordingController> recordingControllerProvider =
    Provider<RecordingController>((ref) {
      return RecordingController(
        repository: ref.watch(recordingRepositoryProvider),
        refreshList: () => ref.invalidate(recordingListControllerProvider),
        refreshDetail: (String id) {
          ref.invalidate(recordingDetailProvider(id));
          ref.invalidate(recordingRealtimeProvider(id));
          ref.invalidate(recordingArtifactsProvider(id));
        },
        notifyChanged: () =>
            ref.read(recordingRevisionProvider.notifier).bump(),
      );
    });

class RecordingController {
  RecordingController({
    required RecordingRepository repository,
    required void Function() refreshList,
    required void Function(String id) refreshDetail,
    required void Function() notifyChanged,
  }) : _repository = repository,
       _refreshList = refreshList,
       _refreshDetail = refreshDetail,
       _notifyChanged = notifyChanged;

  final RecordingRepository _repository;
  final void Function() _refreshList;
  final void Function(String id) _refreshDetail;
  final void Function() _notifyChanged;

  Future<RecordingSummary> create(CreateRecordingCommand command) async {
    final RecordingSummary created = await _repository.createRecording(command);
    _invalidate(created.id);
    return created;
  }

  Future<void> stop(String id) {
    return _mutate(id, () => _repository.stopRecording(id));
  }

  Future<RecordingSummary?> retry(String id) async {
    RecordingSummary? retried;
    try {
      retried = await _repository.retryRecording(id);
      return retried;
    } finally {
      _invalidate(id);
      if (retried != null && retried.id != id) {
        _invalidate(retried.id);
      }
    }
  }

  Future<void> delete(String id) {
    return _mutate(id, () => _repository.deleteRecording(id));
  }

  Future<ArtifactDownloadUrl> createArtifactDownloadUrl(String artifactId) {
    return _repository.createArtifactDownloadUrl(artifactId);
  }

  Future<void> _mutate<T>(String id, Future<T> Function() action) async {
    try {
      await action();
    } finally {
      _invalidate(id);
    }
  }

  void _invalidate(String id) {
    _refreshList();
    _refreshDetail(id);
    _notifyChanged();
  }
}
