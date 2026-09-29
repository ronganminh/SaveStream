import '../../../../core/mock/mock_repository_base.dart';
import '../../domain/models/watch_summary.dart';
import '../../domain/repositories/watch_repository.dart';

final class MockWatchRepository extends MockRepositoryBase
    implements WatchRepository {
  const MockWatchRepository(super.behavior);

  static const List<WatchSummary> _seed = <WatchSummary>[
    WatchSummary(
      id: 'watch_001',
      creatorDisplayName: 'Ada Live',
      creatorUsername: '@ada_live',
      status: WatchStatus.active,
      isLive: true,
    ),
    WatchSummary(
      id: 'watch_002',
      creatorDisplayName: 'Minh Streams',
      creatorUsername: '@minh_streams',
      status: WatchStatus.pausedInsufficientCredit,
      isLive: false,
    ),
    WatchSummary(
      id: 'watch_003',
      creatorDisplayName: 'Studio North',
      creatorUsername: '@studio_north',
      status: WatchStatus.pausedError,
      isLive: false,
    ),
  ];

  @override
  Future<List<WatchSummary>> listWatches() {
    return respond<List<WatchSummary>>(
      success: () => List<WatchSummary>.unmodifiable(_seed),
      empty: () => const <WatchSummary>[],
    );
  }

  @override
  Future<WatchSummary?> getWatch(String id) {
    return respond<WatchSummary?>(
      success: () {
        for (final WatchSummary watch in _seed) {
          if (watch.id == id) {
            return watch;
          }
        }
        return null;
      },
      empty: () => null,
    );
  }
}
