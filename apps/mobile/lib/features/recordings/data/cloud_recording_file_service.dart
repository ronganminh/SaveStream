import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/recording_summary.dart';
import 'cloud_artifact_downloader.dart';

final class CloudRecordingFileService {
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

  Future<File?> existingFile(String recordingId) async {
    final File file = await _destination(recordingId);
    return await file.exists() ? file : null;
  }

  Future<File> download({
    required String recordingId,
    required String artifactId,
    CloudDownloadProgress? onProgress,
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
    );
    return destination;
  }

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
