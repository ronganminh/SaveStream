import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../platform/contracts/share_service.dart';
import '../../recordings/data/cloud_artifact_downloader.dart';
import '../../recordings/domain/models/recording_summary.dart';

final class CloudRecordingShareCoordinator {
  CloudRecordingShareCoordinator({
    required Future<ArtifactDownloadUrl> Function(String artifactId)
    createDownloadUrl,
    required CloudArtifactDownloader downloader,
    required ShareService shareService,
    Future<Directory> Function()? tempDirectory,
  }) : _createDownloadUrl = createDownloadUrl,
       _downloader = downloader,
       _shareService = shareService,
       _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  final Future<ArtifactDownloadUrl> Function(String artifactId)
  _createDownloadUrl;
  final CloudArtifactDownloader _downloader;
  final ShareService _shareService;
  final Future<Directory> Function() _tempDirectory;

  Future<void> share({
    required String artifactId,
    required String displayName,
    String fileExtension = 'mp4',
  }) async {
    final ArtifactDownloadUrl download = await _createDownloadUrl(artifactId);
    if (download.isExpired) {
      throw StateError('Cloud recording URL expired before sharing.');
    }
    final Directory tempRoot = await _tempDirectory();
    final Directory shareDirectory = Directory(
      '${tempRoot.path}/savestream-share',
    );
    await shareDirectory.create(recursive: true);

    final String safeArtifactId = _safeComponent(artifactId);
    final String safeExtension = _safeExtension(fileExtension);
    final File tempFile = File(
      '${shareDirectory.path}/$safeArtifactId.$safeExtension',
    );

    try {
      await _downloader.download(uri: download.uri, destination: tempFile);
      await _shareService.shareFile(
        filePath: tempFile.path,
        displayName: displayName,
      );
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  String _safeComponent(String value) {
    final String normalized = value.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]+'),
      '_',
    );
    return normalized.isEmpty ? 'recording' : normalized;
  }

  String _safeExtension(String value) {
    final String normalized = value
        .replaceAll('.', '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '')
        .toLowerCase();
    return normalized.isEmpty ? 'mp4' : normalized;
  }
}
