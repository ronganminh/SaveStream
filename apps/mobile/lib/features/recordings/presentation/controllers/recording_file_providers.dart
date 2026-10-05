import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../platform/platform_providers.dart';
import '../../../local_recordings/data/cloud_recording_share_coordinator.dart';
import '../../data/cloud_artifact_downloader.dart';
import '../../data/cloud_recording_file_service.dart';
import 'recording_providers.dart';

final Provider<CloudArtifactDownloader> cloudArtifactDownloaderProvider =
    Provider<CloudArtifactDownloader>((Ref ref) {
      final CloudArtifactDownloader downloader = CloudArtifactDownloader(
        deviceInfo: ref.watch(deviceInfoServiceProvider),
      );
      ref.onDispose(downloader.close);
      return downloader;
    });

final Provider<CloudRecordingFileService> cloudRecordingFileServiceProvider =
    Provider<CloudRecordingFileService>((Ref ref) {
      return CloudRecordingFileService(
        createDownloadUrl: ref
            .watch(recordingRepositoryProvider)
            .createArtifactDownloadUrl,
        downloader: ref.watch(cloudArtifactDownloaderProvider),
      );
    });

final Provider<CloudRecordingShareCoordinator>
cloudRecordingShareCoordinatorProvider =
    Provider<CloudRecordingShareCoordinator>((Ref ref) {
      return CloudRecordingShareCoordinator(
        createDownloadUrl: ref
            .watch(recordingRepositoryProvider)
            .createArtifactDownloadUrl,
        downloader: ref.watch(cloudArtifactDownloaderProvider),
        shareService: ref.watch(shareServiceProvider),
      );
    });
