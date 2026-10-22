import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/recordings/presentation/models/recording_library_item.dart';

void main() {
  test('L07 expiry warning begins inside three days', () {
    final RecordingLibraryItem item = RecordingLibraryItem(
      id: 'cloud-1',
      creatorDisplayName: 'Ada Live',
      creatorHandle: '@ada_live',
      status: RecordingStatus.completed,
      startedAt: DateTime.utc(2026, 10, 1),
      durationSeconds: 60,
      sizeBytes: 2048,
      canPlay: true,
      canShare: false,
      canDelete: true,
      expiresAt: DateTime.utc(2026, 10, 7),
    );

    expect(item.isExpiringSoon(DateTime.utc(2026, 10, 4)), isTrue);
    expect(item.isExpiringSoon(DateTime.utc(2026, 10, 3)), isFalse);
  });

  test('L12 and L01-missed map explicit issue states', () {
    const RecordingActions actions = RecordingActions(
      canStop: false,
      canRetry: false,
      canDelete: true,
    );
    final RecordingLibraryItem partial = libraryItemFromCloud(
      RecordingSummary(
        id: 'partial',
        creatorDisplayName: 'Partial',
        creatorUsername: '@partial',
        status: RecordingStatus.partial,
        actions: actions,
        startedAt: DateTime.utc(2026, 10, 4),
        durationSeconds: 60,
        artifactReady: true,
      ),
    );
    final RecordingLibraryItem missed = libraryItemFromCloud(
      const RecordingSummary(
        id: 'missed',
        creatorDisplayName: 'Missed',
        creatorUsername: '@missed',
        status: RecordingStatus.missedNoCloudSlot,
        actions: actions,
        startedAt: null,
        durationSeconds: 0,
      ),
    );

    expect(partial.issue, RecordingLibraryIssue.partialTimeline);
    expect(partial.canShare, isTrue);
    expect(missed.issue, RecordingLibraryIssue.missedNoCloudSlot);
  });

  test('terminal cloud item without an artifact is not playable', () {
    const RecordingActions actions = RecordingActions(
      canStop: false,
      canRetry: true,
      canDelete: true,
    );
    final RecordingLibraryItem item = libraryItemFromCloud(
      RecordingSummary(
        id: 'missing-artifact',
        creatorDisplayName: 'Missing',
        creatorUsername: '@missing',
        status: RecordingStatus.stopped,
        actions: actions,
        startedAt: DateTime.utc(2026, 10, 4),
        durationSeconds: 60,
      ),
    );

    expect(item.issue, RecordingLibraryIssue.missingCloudArtifact);
    expect(item.canPlay, isFalse);
    expect(item.canShare, isFalse);
    expect(item.canDelete, isTrue);
  });
}
