import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../recordings/domain/models/recording_summary.dart';
import '../../domain/models/local_recording_models.dart';
import '../../domain/repositories/local_recording_repository.dart';
import '../local_file_index.dart';

final class IndexedLocalRecordingRepository
    implements LocalRecordingRepository {
  IndexedLocalRecordingRepository({
    required LocalRecordingRepository delegate,
    required Future<String> Function() currentUserId,
    required Future<String> Function() currentDeviceId,
    Future<Directory> Function()? rootDirectory,
  }) : _delegate = delegate,
       _currentUserId = currentUserId,
       _currentDeviceId = currentDeviceId,
       _rootDirectory = rootDirectory ?? _defaultRootDirectory;

  final LocalRecordingRepository _delegate;
  final Future<String> Function() _currentUserId;
  final Future<String> Function() _currentDeviceId;
  final Future<Directory> Function() _rootDirectory;

  static Future<Directory> _defaultRootDirectory() async {
    final Directory support = await getApplicationSupportDirectory();
    return Directory('${support.path}/local_recordings');
  }

  @override
  Future<LocalRecordingSession> start({
    required String watchId,
    required String deviceId,
    String? rewardId,
  }) {
    return _delegate.start(
      watchId: watchId,
      deviceId: deviceId,
      rewardId: rewardId,
    );
  }

  @override
  Future<LocalRecordingSession> extend(String sessionId, {String? rewardId}) {
    return _delegate.extend(sessionId, rewardId: rewardId);
  }

  @override
  Future<LocalRecordingSummary> finish(
    String sessionId, {
    required int recordedSeconds,
    required int sizeBytes,
    required RecordingEndReason endReason,
    required RecordingStatus status,
  }) {
    return _delegate.finish(
      sessionId,
      recordedSeconds: recordedSeconds,
      sizeBytes: sizeBytes,
      endReason: endReason,
      status: status,
    );
  }

  @override
  Future<List<LocalRecordingSummary>> list() async {
    final List<LocalRecordingSummary> backend = await _delegate.list();
    final String userId = await _currentUserId();
    final String deviceId = await _currentDeviceId();
    final Directory root = await _rootDirectory();
    final LocalFileReconciliation reconciliation = await LocalFileIndex(
      root: root,
    ).reconcile(userId: userId, deviceId: deviceId, backendRecordings: backend);

    return List<LocalRecordingSummary>.unmodifiable(
      reconciliation.entries.map((LocalFileIndexEntry entry) {
        final LocalRecordingSummary item = entry.recording;
        return LocalRecordingSummary(
          id: item.id,
          watchId: item.watchId,
          creatorDisplayName: item.creatorDisplayName,
          creatorHandle: item.creatorHandle,
          deviceId: item.deviceId,
          deviceName: item.deviceName,
          startedAt: item.startedAt,
          recordedSeconds: item.recordedSeconds,
          sizeBytes: item.sizeBytes,
          status: item.status,
          filePath: entry.file?.path,
          fileAvailable: entry.presence == LocalFilePresence.present,
        );
      }),
    );
  }

  @override
  Future<void> delete(String id, {required String deviceId}) async {
    await _delegate.delete(id, deviceId: deviceId);

    final String userId = await _currentUserId();
    final Directory root = await _rootDirectory();
    await LocalFileIndex(
      root: root,
    ).deleteRecordingFiles(userId: userId, recordingId: id);
  }
}
