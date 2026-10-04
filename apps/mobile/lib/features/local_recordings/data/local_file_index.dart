import 'dart:io';

import '../domain/models/local_recording_models.dart';

enum LocalFilePresence { present, missing, moved }

final class LocalFileIndexEntry {
  const LocalFileIndexEntry({
    required this.recording,
    required this.presence,
    this.file,
  });

  final LocalRecordingSummary recording;
  final LocalFilePresence presence;
  final File? file;
}

final class LocalFileReconciliation {
  const LocalFileReconciliation({
    required this.entries,
    required this.orphanFiles,
  });

  final List<LocalFileIndexEntry> entries;
  final List<File> orphanFiles;
}

final class LocalFileIndex {
  const LocalFileIndex({required Directory root}) : _root = root;

  final Directory _root;

  Future<LocalFileReconciliation> reconcile({
    required String userId,
    required String deviceId,
    required List<LocalRecordingSummary> backendRecordings,
  }) async {
    final Directory userRoot = Directory('${_root.path}/$userId');
    final Directory expectedRoot = Directory('${userRoot.path}/$deviceId');
    final Map<String, File> expectedFiles = await _recordingFiles(expectedRoot);
    final Map<String, File> userFiles = await _recordingFiles(
      userRoot,
      recursive: true,
    );

    final Set<String> backendIds = backendRecordings
        .map((LocalRecordingSummary item) => item.id)
        .toSet();
    final List<LocalFileIndexEntry> entries = backendRecordings
        .map((LocalRecordingSummary recording) {
          final File? expected = expectedFiles[recording.id];
          if (expected != null) {
            return LocalFileIndexEntry(
              recording: recording,
              presence: LocalFilePresence.present,
              file: expected,
            );
          }
          final File? elsewhere = userFiles[recording.id];
          return LocalFileIndexEntry(
            recording: recording,
            presence: elsewhere == null
                ? LocalFilePresence.missing
                : LocalFilePresence.moved,
            file: elsewhere,
          );
        })
        .toList(growable: false);

    final List<File> orphanFiles = userFiles.entries
        .where(
          (MapEntry<String, File> entry) => !backendIds.contains(entry.key),
        )
        .map((MapEntry<String, File> entry) => entry.value)
        .toList(growable: false);

    return LocalFileReconciliation(
      entries: List<LocalFileIndexEntry>.unmodifiable(entries),
      orphanFiles: List<File>.unmodifiable(orphanFiles),
    );
  }

  Future<void> deleteRecordingFiles({
    required String userId,
    required String recordingId,
  }) async {
    final Directory userRoot = Directory('${_root.path}/$userId');
    if (!await userRoot.exists()) {
      return;
    }

    await for (final FileSystemEntity entity in userRoot.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final String basename = entity.uri.pathSegments.isEmpty
          ? ''
          : entity.uri.pathSegments.last;
      if (_recordingIdFromBasename(basename) == recordingId ||
          basename == '$recordingId.json') {
        await entity.delete();
      }
    }
  }

  Future<Map<String, File>> _recordingFiles(
    Directory directory, {
    bool recursive = false,
  }) async {
    if (!await directory.exists()) {
      return <String, File>{};
    }

    final Map<String, File> files = <String, File>{};
    await for (final FileSystemEntity entity in directory.list(
      recursive: recursive,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final String basename = entity.uri.pathSegments.isEmpty
          ? ''
          : entity.uri.pathSegments.last;
      final String? id = _recordingIdFromBasename(basename);
      if (id != null) {
        files.putIfAbsent(id, () => entity);
      }
    }
    return files;
  }

  String? _recordingIdFromBasename(String basename) {
    for (final String suffix in const <String>[
      '.mp4',
      '.flv',
      '.ts',
      '.part',
    ]) {
      if (basename.endsWith(suffix) && basename.length > suffix.length) {
        return basename.substring(0, basename.length - suffix.length);
      }
    }
    return null;
  }
}
