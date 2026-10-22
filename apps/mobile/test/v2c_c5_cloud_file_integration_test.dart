import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/recordings/data/cloud_artifact_downloader.dart';
import 'package:savestream_mobile/features/recordings/data/cloud_recording_file_service.dart';
import 'package:savestream_mobile/features/recordings/data/cloud_recording_share_coordinator.dart';
import 'package:savestream_mobile/features/recordings/data/device_downloads.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/platform/contracts/share_service.dart';
import 'package:savestream_mobile/platform/fakes/fake_device_info_service.dart';

void main() {
  test('cloud file service resumes into app-private persistent file', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));

    final Directory root = await Directory.systemTemp.createTemp('c5-cloud-');
    addTearDown(() => root.delete(recursive: true));
    await root.create(recursive: true);
    await File('${root.path}/rec-1.mp4').writeAsString('abcd');

    final Future<void> serving = server.first.then((HttpRequest request) async {
      expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=4-');
      request.response.statusCode = HttpStatus.partialContent;
      request.response.contentLength = 3;
      request.response.add(utf8.encode('efg'));
      await request.response.close();
    });

    int urlCalls = 0;
    final CloudArtifactDownloader downloader = CloudArtifactDownloader(
      deviceInfo: const FakeDeviceInfoService(storageBytes: 1024 * 1024),
      storageReserveBytes: 0,
    );
    addTearDown(downloader.close);
    final CloudRecordingFileService service = CloudRecordingFileService(
      createDownloadUrl: (String artifactId) async {
        urlCalls += 1;
        expect(artifactId, 'artifact-1');
        return ArtifactDownloadUrl(
          uri: Uri.parse(
            'http://${server.address.address}:${server.port}/artifact',
          ),
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        );
      },
      downloader: downloader,
      rootDirectory: () async => root,
    );

    final SavedRecordingCopy downloaded = await service.download(
      recordingId: 'rec-1',
      artifactId: 'artifact-1',
    );
    await serving;

    expect(urlCalls, 1);
    expect(service.savesToDownloads, isFalse);
    expect(await File(downloaded.location).readAsString(), 'abcdefg');
    expect(
      (await service.existingCopy('rec-1'))?.location,
      downloaded.location,
    );
  });

  test(
    'android save resumes in cache, publishes to Downloads, removes temp',
    () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));

      final Directory temp = await Directory.systemTemp.createTemp('c5-dl-');
      addTearDown(() => temp.delete(recursive: true));
      final File partial = File('${temp.path}/rec-2.mp4.part');
      await partial.writeAsString('abcd');

      final Future<void> serving = server.first.then((
        HttpRequest request,
      ) async {
        expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=4-');
        request.response.statusCode = HttpStatus.partialContent;
        request.response.contentLength = 3;
        request.response.add(utf8.encode('efg'));
        await request.response.close();
      });

      final CloudArtifactDownloader downloader = CloudArtifactDownloader(
        deviceInfo: const FakeDeviceInfoService(storageBytes: 1024 * 1024),
        storageReserveBytes: 0,
      );
      addTearDown(downloader.close);
      final _FakeDownloads downloads = _FakeDownloads();
      final CloudRecordingFileService service = CloudRecordingFileService(
        createDownloadUrl: (String artifactId) async => ArtifactDownloadUrl(
          uri: Uri.parse(
            'http://${server.address.address}:${server.port}/artifact',
          ),
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        ),
        downloader: downloader,
        tempDirectory: () async => temp,
        rootDirectory: () async => throw StateError('not used on Android'),
        downloads: downloads,
      );

      expect(service.savesToDownloads, isTrue);
      expect(await service.existingBytes('rec-2'), 4);
      expect(await service.existingCopy('rec-2'), isNull);

      final SavedRecordingCopy copy = await service.download(
        recordingId: 'rec-2',
        artifactId: 'artifact-2',
      );
      await serving;

      expect(copy.isContentUri, isTrue);
      expect(downloads.saved.keys, <String>['SaveStream_rec-2.mp4']);
      expect(downloads.saved.values.single, 'abcdefg');
      expect(await partial.exists(), isFalse);
      expect(
        (await service.existingCopy('rec-2', expectedSizeBytes: 7))?.location,
        copy.location,
      );
      expect(await service.existingCopy('rec-2', expectedSizeBytes: 8), isNull);
    },
  );

  test(
    'cloud share uses fresh URL and removes temporary file after share',
    () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));

      final Future<void> serving = server.first.then((
        HttpRequest request,
      ) async {
        request.response.statusCode = HttpStatus.ok;
        request.response.contentLength = 4;
        request.response.add(utf8.encode('data'));
        await request.response.close();
      });

      final Directory temp = await Directory.systemTemp.createTemp('c5-share-');
      addTearDown(() => temp.delete(recursive: true));

      final FakeShareService shareService = FakeShareService();
      final CloudArtifactDownloader downloader = CloudArtifactDownloader(
        deviceInfo: const FakeDeviceInfoService(storageBytes: 1024 * 1024),
        storageReserveBytes: 0,
      );
      addTearDown(downloader.close);

      int urlCalls = 0;
      final CloudRecordingShareCoordinator coordinator =
          CloudRecordingShareCoordinator(
            createDownloadUrl: (String artifactId) async {
              urlCalls += 1;
              return ArtifactDownloadUrl(
                uri: Uri.parse(
                  'http://${server.address.address}:${server.port}/artifact',
                ),
                expiresAt: DateTime.now().toUtc().add(
                  const Duration(minutes: 5),
                ),
              );
            },
            downloader: downloader,
            shareService: shareService,
            tempDirectory: () async => temp,
          );

      await coordinator.share(
        artifactId: 'artifact-1',
        displayName: 'Creator recording',
      );
      await serving;

      expect(urlCalls, 1);
      expect(shareService.sharedFiles, hasLength(1));
      final String sharedPath = shareService.sharedFiles.single.filePath;
      expect(sharedPath, contains('savestream-share'));
      expect(await File(sharedPath).exists(), isFalse);
    },
  );
}

/// Downloads/SaveStream in memory: name -> contents.
class _FakeDownloads implements DeviceDownloads {
  final Map<String, String> saved = <String, String>{};

  @override
  Future<SavedRecordingCopy> save({
    required File source,
    required String displayName,
    String mimeType = 'video/mp4',
  }) async {
    saved[displayName] = await source.readAsString();
    return SavedRecordingCopy(
      location: 'content://media/external/downloads/1',
      sizeBytes: await source.length(),
    );
  }

  @override
  Future<SavedRecordingCopy?> find(String displayName) async {
    final String? contents = saved[displayName];
    if (contents == null) return null;
    return SavedRecordingCopy(
      location: 'content://media/external/downloads/1',
      sizeBytes: contents.length,
    );
  }
}
