import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/local_recordings/data/cloud_recording_share_coordinator.dart';
import 'package:savestream_mobile/features/local_recordings/data/repositories/indexed_local_recording_repository.dart';
import 'package:savestream_mobile/features/local_recordings/domain/models/local_recording_models.dart';
import 'package:savestream_mobile/features/local_recordings/domain/repositories/local_recording_repository.dart';
import 'package:savestream_mobile/features/recordings/data/cloud_artifact_downloader.dart';
import 'package:savestream_mobile/features/recordings/data/cloud_recording_file_service.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/platform/contracts/share_service.dart';
import 'package:savestream_mobile/platform/fakes/fake_device_info_service.dart';

void main() {
  test('indexed repository exposes local file and deletes metadata plus file', () async {
    final Directory root = await Directory.systemTemp.createTemp('c5-indexed-');
    addTearDown(() => root.delete(recursive: true));

    final Directory deviceDirectory = Directory(
      '${root.path}/user-1/device-1',
    );
    await deviceDirectory.create(recursive: true);
    final File media = await File(
      '${deviceDirectory.path}/local-1.flv',
    ).writeAsBytes(<int>[1, 2, 3]);
    final File sidecar = await File(
      '${deviceDirectory.path}/local-1.json',
    ).writeAsString('{}');

    final _FakeLocalRecordingRepository delegate =
        _FakeLocalRecordingRepository(<LocalRecordingSummary>[
          _localSummary('local-1'),
        ]);
    final IndexedLocalRecordingRepository repository =
        IndexedLocalRecordingRepository(
          delegate: delegate,
          currentUserId: () async => 'user-1',
          currentDeviceId: () async => 'device-1',
          rootDirectory: () async => root,
        );

    final List<LocalRecordingSummary> listed = await repository.list();
    expect(listed.single.fileAvailable, isTrue);
    expect(listed.single.filePath, media.path);

    await repository.delete('local-1', deviceId: 'device-1');

    expect(delegate.deleted, <String>['local-1@device-1']);
    expect(await media.exists(), isFalse);
    expect(await sidecar.exists(), isFalse);
  });

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

    final File downloaded = await service.download(
      recordingId: 'rec-1',
      artifactId: 'artifact-1',
    );
    await serving;

    expect(urlCalls, 1);
    expect(await downloaded.readAsString(), 'abcdefg');
    expect((await service.existingFile('rec-1'))?.path, downloaded.path);
  });

  test('cloud share uses fresh URL and removes temporary file after share', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));

    final Future<void> serving = server.first.then((HttpRequest request) async {
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
  });
}

LocalRecordingSummary _localSummary(String id) {
  return LocalRecordingSummary(
    id: id,
    watchId: 'watch-1',
    creatorDisplayName: 'Creator',
    creatorHandle: '@creator',
    deviceId: 'device-1',
    deviceName: 'Pixel',
    startedAt: DateTime.utc(2026, 10, 4),
    recordedSeconds: 60,
    sizeBytes: 1024,
    status: RecordingStatus.completed,
  );
}

final class _FakeLocalRecordingRepository implements LocalRecordingRepository {
  _FakeLocalRecordingRepository(this.items);

  final List<LocalRecordingSummary> items;
  final List<String> deleted = <String>[];

  @override
  Future<List<LocalRecordingSummary>> list() async => items;

  @override
  Future<void> delete(String id, {required String deviceId}) async {
    deleted.add('$id@$deviceId');
  }

  @override
  Future<LocalRecordingSession> start({
    required String watchId,
    required String deviceId,
    String? rewardId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<LocalRecordingSession> extend(
    String sessionId, {
    String? rewardId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<LocalRecordingSummary> finish(
    String sessionId, {
    required int recordedSeconds,
    required int sizeBytes,
    required RecordingEndReason endReason,
    required RecordingStatus status,
  }) {
    throw UnimplementedError();
  }
}
