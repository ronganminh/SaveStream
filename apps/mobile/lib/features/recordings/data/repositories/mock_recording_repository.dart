import '../../../../core/mock/mock_repository_base.dart';
import '../../domain/models/recording_summary.dart';
import '../../domain/repositories/recording_repository.dart';

final class MockRecordingRepository extends MockRepositoryBase
    implements RecordingRepository {
  const MockRecordingRepository(super.behavior);

  static const List<RecordingSummary> _seed = <RecordingSummary>[
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
    ),
  ];

  @override
  Future<List<RecordingSummary>> listRecordings() {
    return respond<List<RecordingSummary>>(
      success: () => List<RecordingSummary>.unmodifiable(_seed),
      empty: () => const <RecordingSummary>[],
    );
  }

  @override
  Future<RecordingSummary?> getRecording(String id) {
    return respond<RecordingSummary?>(
      success: () {
        for (final RecordingSummary recording in _seed) {
          if (recording.id == id) {
            return recording;
          }
        }
        return null;
      },
      empty: () => null,
    );
  }
}
