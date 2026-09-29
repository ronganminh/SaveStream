import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_providers.dart';
import '../../data/repositories/mock_watch_repository.dart';
import '../../domain/models/watch_summary.dart';
import '../../domain/repositories/watch_repository.dart';

final Provider<WatchRepository> watchRepositoryProvider =
    Provider<WatchRepository>(
      (ref) => MockWatchRepository(ref.watch(mockBehaviorProvider)),
    );

final FutureProvider<List<WatchSummary>> watchListProvider =
    FutureProvider<List<WatchSummary>>(
      (ref) => ref.watch(watchRepositoryProvider).listWatches(),
    );

final watchDetailProvider = FutureProvider.family<WatchSummary?, String>(
      (ref, id) => ref.watch(watchRepositoryProvider).getWatch(id),
    );
