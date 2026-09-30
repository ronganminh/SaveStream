import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_providers.dart';
import '../../../recordings/domain/models/recording_summary.dart';
import '../../../recordings/presentation/controllers/recording_providers.dart';
import '../../data/repositories/mock_watch_repository.dart';
import '../../domain/models/channel_detail_view_model.dart';
import '../../domain/models/watch_summary.dart';
import '../../domain/repositories/watch_repository.dart';

final Provider<WatchRepository> watchRepositoryProvider =
    Provider<WatchRepository>(
      (ref) => MockWatchRepository(ref.watch(mockBehaviorProvider)),
    );

final NotifierProvider<WatchRevisionNotifier, int> watchRevisionProvider =
    NotifierProvider<WatchRevisionNotifier, int>(WatchRevisionNotifier.new);

class WatchRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state += 1;
  }
}

final FutureProvider<List<WatchSummary>> watchListProvider =
    FutureProvider<List<WatchSummary>>(
      (ref) => ref.watch(watchRepositoryProvider).listWatches(),
    );

final watchDetailProvider = FutureProvider.family<WatchSummary?, String>(
  (ref, id) => ref.watch(watchRepositoryProvider).getWatch(id),
);

final channelDetailProvider =
    FutureProvider.family<ChannelDetailViewModel?, String>((ref, id) async {
      final List<Object?> values = await Future.wait<Object?>(<Future<Object?>>[
        ref.watch(watchRepositoryProvider).getWatch(id),
        ref.watch(recordingRepositoryProvider).listRecordings(),
      ], eagerError: false);

      final WatchSummary? watch = values[0] as WatchSummary?;
      if (watch == null) {
        return null;
      }

      final List<RecordingSummary> recordings =
          (values[1] as List<RecordingSummary>)
              .where((RecordingSummary item) => item.watchId == id)
              .toList(growable: false);

      return ChannelDetailViewModel(watch: watch, recordings: recordings);
    });

final Provider<WatchController> watchControllerProvider =
    Provider<WatchController>((ref) {
      return WatchController(
        repository: ref.watch(watchRepositoryProvider),
        invalidateList: () => ref.invalidate(watchListProvider),
        invalidateDetail: (String id) {
          ref.invalidate(watchDetailProvider(id));
          ref.invalidate(channelDetailProvider(id));
        },
        notifyChanged: () => ref.read(watchRevisionProvider.notifier).bump(),
      );
    });

class WatchController {
  WatchController({
    required WatchRepository repository,
    required void Function() invalidateList,
    required void Function(String id) invalidateDetail,
    required void Function() notifyChanged,
  }) : _repository = repository,
       _invalidateList = invalidateList,
       _invalidateDetail = invalidateDetail,
       _notifyChanged = notifyChanged;

  final WatchRepository _repository;
  final void Function() _invalidateList;
  final void Function(String id) _invalidateDetail;
  final void Function() _notifyChanged;

  Future<WatchSummary> createWatch(CreateWatchCommand command) async {
    final WatchSummary created = await _repository.createWatch(command);
    _invalidate(created.id);
    return created;
  }

  Future<void> setAutoRecord(String id, {required bool enabled}) async {
    await _repository.setAutoRecord(id, enabled: enabled);
    _invalidate(id);
  }

  Future<void> pause(String id) async {
    await _repository.pauseWatch(id);
    _invalidate(id);
  }

  Future<void> resume(String id) async {
    await _repository.resumeWatch(id);
    _invalidate(id);
  }

  Future<void> delete(String id) async {
    await _repository.deleteWatch(id);
    _invalidate(id);
  }

  void _invalidate(String id) {
    _invalidateList();
    _invalidateDetail(id);
    _notifyChanged();
  }
}
