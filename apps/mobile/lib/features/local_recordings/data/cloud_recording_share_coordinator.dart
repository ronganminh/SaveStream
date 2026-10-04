import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../recordings/data/cloud_artifact_downloader.dart';
import '../../recordings/domain/repositories/recording_repository.dart';
import '../../../platform/contracts/share_service.dart';

final class CloudRecordingShareCoordinator {
  CloudRecordingShareCoordinator({
    required RecordingRepository recordingRepository,
    required CloudArtifactDownloader downloader,
    required ShareService shareService,
  }) : _recordingRepository = recordingRepository,
       _downloader = downloader,
       _shareService = shareService;

  final RecordingRepository _recordingRepository;
  final CloudArtifactDownloader _downloader;
  final ShareService _shareService;

  Future<void> share({
    required String artifactId,
    required String displayName,
    String fileExtension = 'mp4',
  }) async {
    final download = await _recordingRepository.createArtifactDownloadUrl(
      artifactId,
    );
    final Directory tempRoot = await getTemporaryDirectory();
    final Directory shareDirectory = Directory(
      '${tempRoot.path}/savestream-share',
    );
    await shareDirectory.create(recursive: true);

    final String safeArtifactId = _safeComponent(artifactId);
    final String safeExtension = _safeExtension(fileExtension);
    final File tempFile = File(
      '${shareDirectory.path}/$safeArtifactId.$safeExtension',
    );

    await _downloader.download(
      uri: download.uri,
      destination: tempFile,
    );

    try {
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
