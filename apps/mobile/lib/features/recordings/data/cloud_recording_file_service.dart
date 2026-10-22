import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/models/recording_summary.dart';
import 'cloud_artifact_downloader.dart';
import 'device_downloads.dart';

export 'device_downloads.dart' show SavedRecordingCopy;

/// Copies of cloud recordings saved on this device.
///
/// Saved copies belong to the user: deleting the cloud recording never
/// removes them, so there is no delete here.
abstract interface class RecordingFileStore {
  /// True when copies go to the public Downloads/SaveStream folder (Android);
  /// false when they stay in the app's own storage (iOS).
  bool get savesToDownloads;

  /// The saved copy of [recordingId], when it is complete.
  Future<SavedRecordingCopy?> existingCopy(
    String recordingId, {
    int? expectedSizeBytes,
  });

  /// Bytes already downloaded for [recordingId] (a partial download).
  Future<int> existingBytes(String recordingId);

  /// Downloads (or resumes) the artifact and saves it on the device.
  Future<SavedRecordingCopy> download({
    required String recordingId,
    required String artifactId,
    CloudDownloadProgress? onProgress,
    bool Function()? isCancelled,
  });
}

/// With [downloads] (Android) the artifact downloads into a resumable cache
/// file and, once complete, is copied into Downloads/SaveStream; the cache
/// file is then removed. Without it (iOS) the download itself is the saved
/// copy, in the app's support directory.
final class CloudRecordingFileService implements RecordingFileStore {
  CloudRecordingFileService({
    required Future<ArtifactDownloadUrl> Function(String artifactId)
    createDownloadUrl,
    required CloudArtifactDownloader downloader,
    Future<Directory> Function()? rootDirectory,
    Future<Directory> Function()? tempDirectory,
    DeviceDownloads? downloads,
  }) : _createDownloadUrl = createDownloadUrl,
       _downloader = downloader,
       _rootDirectory = rootDirectory ?? _defaultRootDirectory,
       _tempDirectory = tempDirectory ?? _defaultTempDirectory,
       _downloads = downloads;

  final Future<ArtifactDownloadUrl> Function(String artifactId)
  _createDownloadUrl;
  final CloudArtifactDownloader _downloader;
  final Future<Directory> Function() _rootDirectory;
  final Future<Directory> Function() _tempDirectory;
  final DeviceDownloads? _downloads;

  static Future<Directory> _defaultRootDirectory() async {
    final Directory support = await getApplicationSupportDirectory();
    return Directory('${support.path}/cloud_recordings');
  }

  static Future<Directory> _defaultTempDirectory() async {
    final Directory temp = await getTemporaryDirectory();
    return Directory('${temp.path}/cloud_recordings');
  }

  @override
  bool get savesToDownloads => _downloads != null;

  /// The file name in Downloads/SaveStream.
  static String displayName(String recordingId) =>
      'SaveStream_${_safeComponent(recordingId)}.mp4';

  @override
  Future<SavedRecordingCopy?> existingCopy(
    String recordingId, {
    int? expectedSizeBytes,
  }) async {
    final DeviceDownloads? downloads = _downloads;
    if (downloads != null) {
      final SavedRecordingCopy? copy = await downloads.find(
        displayName(recordingId),
      );
      if (copy == null) return null;
      if (expectedSizeBytes != null &&
          copy.sizeBytes != null &&
          copy.sizeBytes != expectedSizeBytes) {
        return null;
      }
      return copy;
    }

    final File file = await _destination(recordingId);
    if (!await file.exists()) {
      return null;
    }
    final int size = await file.length();
    if (expectedSizeBytes != null && size != expectedSizeBytes) {
      return null;
    }
    return SavedRecordingCopy(location: file.path, sizeBytes: size);
  }

  @override
  Future<int> existingBytes(String recordingId) async {
    final File file = await _destination(recordingId);
    return await file.exists() ? file.length() : 0;
  }

  @override
  Future<SavedRecordingCopy> download({
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
    final CloudDownloadResult result = await _downloader.download(
      uri: download.uri,
      destination: destination,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );

    final DeviceDownloads? downloads = _downloads;
    if (downloads == null) {
      return SavedRecordingCopy(
        location: destination.path,
        sizeBytes: result.bytesWritten,
      );
    }
    final SavedRecordingCopy copy = await downloads.save(
      source: destination,
      displayName: displayName(recordingId),
    );
    try {
      await destination.delete();
    } on FileSystemException {
      // A leftover cache file only takes space; the OS may clear it.
    }
    return copy;
  }

  Future<File> _destination(String recordingId) async {
    final Directory root = _downloads == null
        ? await _rootDirectory()
        : await _tempDirectory();
    await root.create(recursive: true);
    final String name = '${_safeComponent(recordingId)}.mp4';
    return File('${root.path}/${_downloads == null ? name : '$name.part'}');
  }

  static String _safeComponent(String value) {
    final String normalized = value.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]+'),
      '_',
    );
    return normalized.isEmpty ? 'recording' : normalized;
  }
}
