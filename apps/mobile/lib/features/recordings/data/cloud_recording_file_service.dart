import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/models/recording_summary.dart';
import 'cloud_artifact_downloader.dart';

/// Copies of cloud recordings saved on this device.
abstract interface class RecordingFileStore {
  /// The saved copy of [recordingId], when it is complete.
  Future<File?> existingFile(String recordingId, {int? expectedSizeBytes});

  /// Bytes already saved for [recordingId] (a partial download included).
  Future<int> existingBytes(String recordingId);

  /// Downloads (or resumes) the artifact into the device copy.
  Future<File> download({
    required String recordingId,
    required String artifactId,
    CloudDownloadProgress? onProgress,
    bool Function()? isCancelled,
  });

  Future<void> delete(String recordingId);
}

final class CloudRecordingFileService implements RecordingFileStore {
  CloudRecordingFileService({
    required Future<ArtifactDownloadUrl> Function(String artifactId)
    createDownloadUrl,
    required CloudArtifactDownloader downloader,
    Future<Directory> Function()? rootDirectory,
  }) : _createDownloadUrl = createDownloadUrl,
       _downloader = downloader,
       _rootDirectory = rootDirectory ?? _defaultRootDirectory;

  final Future<ArtifactDownloadUrl> Function(String artifactId)
  _createDownloadUrl;
  final CloudArtifactDownloader _downloader;
  final Future<Directory> Function() _rootDirectory;

  static Future<Directory> _defaultRootDirectory() async {
    final Directory support = await getApplicationSupportDirectory();
    return Directory('${support.path}/cloud_recordings');
  }

  @override
  Future<File?> existingFile(
    String recordingId, {
    int? expectedSizeBytes,
  }) async {
    final File file = await _destination(recordingId);
    if (!await file.exists()) {
      return null;
    }
    if (expectedSizeBytes != null && await file.length() != expectedSizeBytes) {
      return null;
    }
    return file;
  }

  @override
  Future<int> existingBytes(String recordingId) async {
    final File file = await _destination(recordingId);
    return await file.exists() ? file.length() : 0;
  }

  @override
  Future<File> download({
    required String recordingId,
    required String artifactId,
    CloudDownloadProgress? onProgress,
    bool Function()? isCancelled,
  }) async {
    final ArtifactDownloadUrl download = await _createDownloadUrl(artifactId);
    if (download.isExpired) {
      throw StateError('Cloud recording URL expired before download.');
    }
    final File destination = await _destination(recordingId);
    await _downloader.download(
      uri: download.uri,
      destination: destination,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    return destination;
  }

  @override
  Future<void> delete(String recordingId) async {
    final File file = await _destination(recordingId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _destination(String recordingId) async {
    final Directory root = await _rootDirectory();
    await root.create(recursive: true);
    return File('${root.path}/${_safeComponent(recordingId)}.mp4');
  }

  String _safeComponent(String value) {
    final String normalized = value.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]+'),
      '_',
    );
    return normalized.isEmpty ? 'recording' : normalized;
  }
}
