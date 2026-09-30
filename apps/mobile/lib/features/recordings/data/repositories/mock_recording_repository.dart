import '../../../../core/mock/mock_repository_base.dart';
import '../../domain/models/recording_summary.dart';
import '../../domain/repositories/recording_repository.dart';

final class MockRecordingRepository extends MockRepositoryBase
    implements RecordingRepository {
  MockRecordingRepository(super.behavior)
    : _items = List<RecordingSummary>.of(_seed);

  static final List<RecordingSummary> _seed = <RecordingSummary>[
    RecordingSummary(
      id: 'rec_001',
      watchId: 'watch_001',
      creatorDisplayName: 'Ada Live',
      creatorUsername: '@ada_live',
      status: RecordingStatus.recording,
      actions: RecordingActions(
        canStop: true,
        canRetry: false,
        canDelete: false,
      ),
      startedAt: DateTime.utc(2026, 9, 30, 13, 42),
      durationSeconds: 2940,
      bytesRecorded: 734003200,
      progress: 0.58,
      thumbnailReady: true,
    ),
    RecordingSummary(
      id: 'rec_004',
      watchId: 'watch_004',
      creatorDisplayName: 'Nora Shop',
      creatorUsername: '@nora_shop',
      status: RecordingStatus.processing,
      actions: RecordingActions(
        canStop: false,
        canRetry: false,
        canDelete: false,
      ),
      startedAt: DateTime.utc(2026, 9, 30, 12, 5),
      durationSeconds: 4210,
      sizeBytes: 1181116006,
      progress: 0.72,
      thumbnailReady: true,
    ),
    RecordingSummary(
      id: 'rec_005',
      watchId: 'watch_006',
      creatorDisplayName: 'Mika Studio',
      creatorUsername: '@mika_studio',
      status: RecordingStatus.uploading,
      actions: RecordingActions(
        canStop: false,
        canRetry: false,
        canDelete: false,
      ),
      startedAt: DateTime.utc(2026, 9, 30, 10, 22),
      durationSeconds: 3625,
      sizeBytes: 943718400,
      progress: 0.41,
      thumbnailReady: true,
    ),
    RecordingSummary(
      id: 'rec_002',
      watchId: 'watch_002',
      creatorDisplayName: 'Minh Streams',
      creatorUsername: '@minh_streams',
      status: RecordingStatus.completed,
      actions: RecordingActions(
        canStop: false,
        canRetry: false,
        canDelete: true,
      ),
      startedAt: DateTime.utc(2026, 9, 29, 11, 5),
      durationSeconds: 5400,
      sizeBytes: 1503238553,
      costCredits: 1.8,
      progress: 1,
      artifactReady: true,
      thumbnailReady: true,
    ),
    RecordingSummary(
      id: 'rec_003',
      watchId: 'watch_003',
      creatorDisplayName: 'Studio North',
      creatorUsername: '@studio_north',
      status: RecordingStatus.failed,
      actions: RecordingActions(
        canStop: false,
        canRetry: true,
        canDelete: true,
      ),
      startedAt: DateTime.utc(2026, 9, 29, 8, 12),
      durationSeconds: 388,
      bytesRecorded: 136314880,
      costCredits: 0.2,
      thumbnailReady: true,
      errorCode: 'SOURCE_CONNECTION_LOST',
      errorMessage: 'The source connection ended before recording completed.',
    ),
    RecordingSummary(
      id: 'rec_006',
      watchId: 'watch_005',
      creatorDisplayName: 'Leo Daily',
      creatorUsername: '@leo_daily',
      status: RecordingStatus.waitingLive,
      actions: RecordingActions(
        canStop: false,
        canRetry: false,
        canDelete: true,
      ),
      startedAt: null,
      durationSeconds: 0,
    ),
    RecordingSummary(
      id: 'rec_007',
      watchId: 'watch_004',
      creatorDisplayName: 'Nora Shop',
      creatorUsername: '@nora_shop',
      status: RecordingStatus.resolving,
      actions: RecordingActions(
        canStop: false,
        canRetry: false,
        canDelete: false,
      ),
      startedAt: null,
      durationSeconds: 0,
      progress: 0.2,
    ),
    RecordingSummary(
      id: 'rec_008',
      watchId: 'watch_001',
      creatorDisplayName: 'Ada Live',
      creatorUsername: '@ada_live',
      status: RecordingStatus.queued,
      actions: RecordingActions(
        canStop: false,
        canRetry: false,
        canDelete: true,
      ),
      startedAt: null,
      durationSeconds: 0,
    ),
    RecordingSummary(
      id: 'rec_009',
      watchId: 'watch_006',
      creatorDisplayName: 'Mika Studio',
      creatorUsername: '@mika_studio',
      status: RecordingStatus.stopRequested,
      actions: RecordingActions(
        canStop: false,
        canRetry: false,
        canDelete: false,
      ),
      startedAt: DateTime.utc(2026, 9, 28, 19, 10),
      durationSeconds: 1775,
      bytesRecorded: 482344960,
      progress: 0.86,
      thumbnailReady: true,
    ),
    RecordingSummary(
      id: 'rec_010',
      watchId: 'watch_005',
      creatorDisplayName: 'Leo Daily',
      creatorUsername: '@leo_daily',
      status: RecordingStatus.stopped,
      actions: RecordingActions(
        canStop: false,
        canRetry: false,
        canDelete: true,
      ),
      startedAt: DateTime.utc(2026, 9, 27, 16, 40),
      durationSeconds: 1302,
      sizeBytes: 398458880,
      costCredits: 0.5,
      artifactReady: true,
      thumbnailReady: true,
    ),
  ];

  final List<RecordingSummary> _items;

  @override
  Future<List<RecordingSummary>> listRecordings() {
    return respond<List<RecordingSummary>>(
      success: () => List<RecordingSummary>.unmodifiable(_items),
      empty: () => const <RecordingSummary>[],
    );
  }

  @override
  Future<RecordingPage> listRecordingPage({
    RecordingFilter filter = RecordingFilter.all,
    String? cursor,
    int limit = 4,
  }) {
    return respond<RecordingPage>(
      success: () {
        final List<RecordingSummary> filtered = _items
            .where((RecordingSummary item) => _matchesFilter(item, filter))
            .toList(growable: false);
        final int offset = int.tryParse(cursor ?? '0') ?? 0;
        final int end = (offset + limit).clamp(0, filtered.length);
        final List<RecordingSummary> page = filtered.sublist(offset, end);
        return RecordingPage(
          items: List<RecordingSummary>.unmodifiable(page),
          nextCursor: end < filtered.length ? end.toString() : null,
        );
      },
      empty: () => const RecordingPage(
        items: <RecordingSummary>[],
        nextCursor: null,
      ),
    );
  }

  @override
  Future<RecordingSummary?> getRecording(String id) {
    return respond<RecordingSummary?>(
      success: () => _find(id),
      empty: () => null,
    );
  }

  @override
  Future<RecordingSummary?> stopRecording(String id) {
    return respond<RecordingSummary?>(
      success: () => _update(
        id,
        (RecordingSummary current) => current.copyWith(
          status: RecordingStatus.stopRequested,
          actions: const RecordingActions(
            canStop: false,
            canRetry: false,
            canDelete: false,
          ),
        ),
      ),
      empty: () => null,
    );
  }

  @override
  Future<RecordingSummary?> retryRecording(String id) {
    return respond<RecordingSummary?>(
      success: () => _update(
        id,
        (RecordingSummary current) => current.copyWith(
          status: RecordingStatus.queued,
          actions: const RecordingActions(
            canStop: false,
            canRetry: false,
            canDelete: true,
          ),
          progress: 0,
        ),
      ),
      empty: () => null,
    );
  }

  @override
  Future<void> deleteRecording(String id) {
    return respond<void>(
      success: () {
        _items.removeWhere((RecordingSummary item) => item.id == id);
      },
      empty: () {},
    );
  }

  bool _matchesFilter(RecordingSummary item, RecordingFilter filter) {
    return switch (filter) {
      RecordingFilter.all => true,
      RecordingFilter.active => item.isActiveLifecycle,
      RecordingFilter.completed => item.status == RecordingStatus.completed,
      RecordingFilter.failed => item.status == RecordingStatus.failed,
    };
  }

  RecordingSummary? _find(String id) {
    for (final RecordingSummary item in _items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  RecordingSummary? _update(
    String id,
    RecordingSummary Function(RecordingSummary current) update,
  ) {
    final int index = _items.indexWhere((RecordingSummary item) => item.id == id);
    if (index < 0) {
      return null;
    }
    final RecordingSummary updated = update(_items[index]);
    _items[index] = updated;
    return updated;
  }
}
