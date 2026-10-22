import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_providers.dart';
import '../../../recordings/domain/models/recording_summary.dart';
import '../../../recordings/presentation/controllers/recording_providers.dart';
import '../../data/repositories/mock_watch_repository.dart';
import '../../domain/models/channel_detail_view_model.dart';
import '../../domain/models/channel_verification.dart';
import '../../domain/models/watch_summary.dart';
import '../../domain/repositories/watch_repository.dart';

final Provider<WatchRepository> watchRepositoryProvider =
    Provider<WatchRepository>(
      (ref) => MockWatchRepository(ref.watch(mockBehaviorProvider)),
    );

/// The watch repository's creator lookup (`POST /v1/live-status`).
final Provider<CreatorLookupRepository> creatorLookupRepositoryProvider =
    Provider<CreatorLookupRepository>((ref) {
      final WatchRepository repository = ref.watch(watchRepositoryProvider);
      if (repository is CreatorLookupRepository) {
        return repository as CreatorLookupRepository;
      }
      throw UnsupportedError('This watch repository cannot look up creators.');
    });

/// The watch repository's bio-code verification endpoints.
final Provider<ChannelVerificationRepository>
channelVerificationRepositoryProvider = Provider<ChannelVerificationRepository>(
  (ref) {
    final WatchRepository repository = ref.watch(watchRepositoryProvider);
    if (repository is ChannelVerificationRepository) {
      return repository as ChannelVerificationRepository;
    }
    throw UnsupportedError('This watch repository cannot verify channels.');
  },
);

/// Pending verification (code and expiry) of an unverified channel, read
/// without creating a code. Null when it cannot be loaded; screens then fall
/// back to copy without the code.
final channelVerificationProvider =
    FutureProvider.family<ChannelVerification?, String>((ref, id) async {
      ref.watch(watchRevisionProvider);
      try {
        return await ref
            .watch(channelVerificationRepositoryProvider)
            .getVerification(id);
      } on Object {
        return null;
      }
    });

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

final FutureProvider<List<RecordingSummary>> watchRecordingsProvider =
    FutureProvider<List<RecordingSummary>>((ref) {
      ref.watch(recordingRevisionProvider);
      return ref.watch(recordingRepositoryProvider).listRecordings();
    });

final channelDetailProvider =
    FutureProvider.family<ChannelDetailViewModel?, String>((ref, id) async {
      ref.watch(recordingRevisionProvider);
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
              .where(
                (RecordingSummary item) =>
                    _recordingBelongsToWatch(item, watch, id),
              )
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

  Future<void> setAutoRecord(String id, {required bool enabled}) {
    return _runMutation(
      id,
      () => _repository.setAutoRecord(id, enabled: enabled),
    );
  }

  Future<void> setNotifyOnLive(String id, {required bool enabled}) {
    return _runMutation(
      id,
      () => _repository.setNotifyOnLive(id, enabled: enabled),
    );
  }

  Future<void> pause(String id) {
    return _runMutation(id, () => _repository.pauseWatch(id));
  }

  Future<void> resume(String id) {
    return _runMutation(id, () => _repository.resumeWatch(id));
  }

  Future<void> delete(String id) {
    return _runMutation(id, () => _repository.deleteWatch(id));
  }

  /// Reloads a channel after something changed on the server (for example
  /// its ownership was verified).
  void refresh(String id) => _invalidate(id);

  Future<void> _runMutation<T>(String id, Future<T> Function() action) async {
    try {
      await action();
    } finally {
      // Always reconcile with the backend after a mutation attempt. This is
      // especially important for resume: the backend can persist
      // paused_insufficient_credit and then return 402.
      _invalidate(id);
    }
  }

  void _invalidate(String id) {
    _invalidateList();
    _invalidateDetail(id);
    _notifyChanged();
  }
}

bool _recordingBelongsToWatch(
  RecordingSummary recording,
  WatchSummary watch,
  String watchId,
) {
  if (recording.watchId == watchId) {
    return true;
  }

  final WatchSourceType? watchSourceType = watch.sourceType;
  final String? watchSourceValue = watch.sourceValue;
  if (watchSourceType != null && watchSourceValue != null) {
    if (recording.sourceType.apiValue == watchSourceType.apiValue &&
        _normalizeSource(recording.sourceValue) ==
            _normalizeSource(watchSourceValue)) {
      return true;
    }
  }

  return _normalizeUsername(recording.creatorUsername) ==
      _normalizeUsername(watch.creatorUsername);
}

String _normalizeSource(String value) {
  return value.trim().replaceFirst(RegExp(r'/+$'), '').toLowerCase();
}

String _normalizeUsername(String value) {
  return value.trim().replaceFirst('@', '').toLowerCase();
}
