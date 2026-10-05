import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/local_recordings/data/local_file_index.dart';
import 'package:savestream_mobile/features/local_recordings/domain/models/local_recording_models.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/recordings/presentation/models/recording_library_item.dart';

void main() {
  test('L01 cross-device local recording is read-only', () {
    final RecordingLibraryItem item = libraryItemFromLocal(
      LocalRecordingSummary(
        id: 'local-remote',
        watchId: 'watch-1',
        creatorDisplayName: 'Ada Live',
        creatorHandle: '@ada_live',
        deviceId: 'other-device',
        deviceName: 'iPhone 17',
        startedAt: DateTime.utc(2026, 10, 4),
        recordedSeconds: 120,
        sizeBytes: 1024,
        status: RecordingStatus.completed,
        filePath: '/remote/recording.mp4',
      ),
      currentDeviceId: 'this-device',
    );

    expect(item.isCrossDevice, isTrue);
    expect(item.canPlay, isFalse);
    expect(item.canShare, isFalse);
    expect(item.canDelete, isFalse);
  });

  test('L09 missing local file disables playback and sharing', () {
    final RecordingLibraryItem item = libraryItemFromLocal(
      LocalRecordingSummary(
        id: 'local-missing',
        watchId: 'watch-1',
        creatorDisplayName: 'Ada Live',
        creatorHandle: '@ada_live',
        deviceId: 'this-device',
        deviceName: 'Pixel',
        startedAt: DateTime.utc(2026, 10, 4),
        recordedSeconds: 120,
        sizeBytes: 1024,
        status: RecordingStatus.completed,
        fileAvailable: false,
      ),
      currentDeviceId: 'this-device',
    );

    expect(item.issue, RecordingLibraryIssue.missingLocalFile);
    expect(item.canPlay, isFalse);
    expect(item.canShare, isFalse);
  });

  test('L07 expiry warning begins inside three days', () {
    final RecordingLibraryItem item = RecordingLibraryItem(
      id: 'cloud-1',
      creatorDisplayName: 'Ada Live',
      creatorHandle: '@ada_live',
      storage: RecordingLibraryStorage.cloud,
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
    expect(missed.issue, RecordingLibraryIssue.missedNoCloudSlot);
  });

  test('L13 resolves local cloud and both delete contexts', () {
    expect(
      deletionTargetFor(hasLocal: true, hasCloud: false),
      RecordingDeleteTarget.local,
    );
    expect(
      deletionTargetFor(hasLocal: false, hasCloud: true),
      RecordingDeleteTarget.cloud,
    );
    expect(
      deletionTargetFor(hasLocal: true, hasCloud: true),
      RecordingDeleteTarget.both,
    );
  });

  test(
    'A16 foreign local files stay isolated from the current account',
    () async {
      final Directory root = await Directory.systemTemp.createTemp(
        'savestream-a16-',
      );
      final Directory foreign = Directory('${root.path}/user-other/device-b');
      await foreign.create(recursive: true);
      await File(
        '${foreign.path}/foreign-recording.mp4',
      ).writeAsBytes(<int>[1]);

      final LocalFileIndex index = LocalFileIndex(root: root);
      expect(
        await index.hasRecordingsOwnedByOtherUsers(userId: 'user-current'),
        isTrue,
      );

      final LocalFileReconciliation result = await index.reconcile(
        userId: 'user-current',
        deviceId: 'device-a',
        backendRecordings: const <LocalRecordingSummary>[],
      );
      expect(result.entries, isEmpty);
      expect(result.orphanFiles, isEmpty);
    },
  );
}
