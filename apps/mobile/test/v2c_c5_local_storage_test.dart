import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/api/api_client.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/local_recordings/data/api_local_recording_delete_service.dart';
import 'package:savestream_mobile/features/local_recordings/data/local_file_index.dart';
import 'package:savestream_mobile/features/local_recordings/domain/models/local_recording_models.dart';
import 'package:savestream_mobile/features/recordings/data/cloud_artifact_downloader.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/platform/fakes/fake_device_info_service.dart';

void main() {
  test('local file index detects present moved missing and orphan files', () async {
    final Directory root = await Directory.systemTemp.createTemp('c5-index-');
    addTearDown(() => root.delete(recursive: true));

    final Directory expected = Directory('${root.path}/user-1/device-1');
    final Directory moved = Directory('${root.path}/user-1/device-2');
    await expected.create(recursive: true);
    await moved.create(recursive: true);
    await File('${expected.path}/local-1.flv').writeAsBytes(<int>[1]);
    await File('${moved.path}/local-2.mp4').writeAsBytes(<int>[2]);
    await File('${expected.path}/orphan.ts').writeAsBytes(<int>[3]);

    final LocalFileReconciliation result = await LocalFileIndex(root: root)
        .reconcile(
          userId: 'user-1',
          deviceId: 'device-1',
          backendRecordings: <LocalRecordingSummary>[
            _localSummary('local-1'),
            _localSummary('local-2'),
            _localSummary('local-3'),
          ],
        );

    expect(
      result.entries.map((LocalFileIndexEntry item) => item.presence),
      <LocalFilePresence>[
        LocalFilePresence.present,
        LocalFilePresence.moved,
        LocalFilePresence.missing,
      ],
    );
    expect(result.orphanFiles.single.path, endsWith('orphan.ts'));
  });

  test('local file deletion removes media and sidecar only for target user', () async {
    final Directory root = await Directory.systemTemp.createTemp('c5-delete-');
    addTearDown(() => root.delete(recursive: true));

    final Directory userOne = Directory('${root.path}/user-1/device-1');
    final Directory userTwo = Directory('${root.path}/user-2/device-1');
    await userOne.create(recursive: true);
    await userTwo.create(recursive: true);
    final File media = await File('${userOne.path}/local-1.flv')
        .writeAsBytes(<int>[1]);
    final File sidecar = await File('${userOne.path}/local-1.json')
        .writeAsString('{}');
    final File otherUser = await File('${userTwo.path}/local-1.flv')
        .writeAsBytes(<int>[2]);

    await LocalFileIndex(root: root).deleteRecordingFiles(
      userId: 'user-1',
      recordingId: 'local-1',
    );

    expect(await media.exists(), isFalse);
    expect(await sidecar.exists(), isFalse);
    expect(await otherUser.exists(), isTrue);
  });

  test('cloud downloader resumes with Range and reports actual bytes', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));

    final Future<void> serving = server.first.then((HttpRequest request) async {
      expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=4-');
      request.response.statusCode = HttpStatus.partialContent;
      request.response.contentLength = 3;
      request.response.add(utf8.encode('efg'));
      await request.response.close();
    });

    final Directory root = await Directory.systemTemp.createTemp('c5-dl-');
    addTearDown(() => root.delete(recursive: true));
    final File destination = await File('${root.path}/artifact.mp4')
        .writeAsString('abcd');

    int lastReceived = 0;
    int? lastTotal;
    final CloudArtifactDownloader downloader = CloudArtifactDownloader(
      deviceInfo: const FakeDeviceInfoService(storageBytes: 1024 * 1024),
      storageReserveBytes: 0,
    );
    addTearDown(downloader.close);

    final CloudDownloadResult result = await downloader.download(
      uri: Uri.parse(
        'http://${server.address.address}:${server.port}/artifact',
      ),
      destination: destination,
      onProgress: ({required int receivedBytes, required int? totalBytes}) {
        lastReceived = receivedBytes;
        lastTotal = totalBytes;
      },
    );
    await serving;

    expect(result.resumed, isTrue);
    expect(result.bytesWritten, 7);
    expect(await destination.readAsString(), 'abcdefg');
    expect(lastReceived, 7);
    expect(lastTotal, 7);
  });

  test('cloud downloader checks free storage before writing response', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));

    final Future<void> serving = server.first.then((HttpRequest request) async {
      request.response.statusCode = HttpStatus.ok;
      request.response.contentLength = 4;
      request.response.add(<int>[1, 2, 3, 4]);
      await request.response.close();
    });

    final Directory root = await Directory.systemTemp.createTemp('c5-low-');
    addTearDown(() => root.delete(recursive: true));
    final File destination = File('${root.path}/artifact.mp4');

    final CloudArtifactDownloader downloader = CloudArtifactDownloader(
      deviceInfo: const FakeDeviceInfoService(storageBytes: 12),
      storageReserveBytes: 10,
    );
    addTearDown(downloader.close);

    await expectLater(
      downloader.download(
        uri: Uri.parse(
          'http://${server.address.address}:${server.port}/artifact',
        ),
        destination: destination,
      ),
      throwsA(isA<CloudDownloadStorageException>()),
    );
    await serving;
    expect(await destination.exists(), isFalse);
  });

  test('local recording delete calls backend with device identity', () async {
    final _FakeAdapter adapter = _FakeAdapter((RequestOptions options) {
      expect(options.method, 'DELETE');
      expect(options.path, '/v1/local-recordings/local-1');
      expect(options.queryParameters, <String, dynamic>{
        'device_id': 'device-1',
      });
      return ResponseBody.fromString('', HttpStatus.noContent);
    });
    final Dio dio = Dio();
    dio.httpClientAdapter = adapter;
    final ApiLocalRecordingDeleteService service =
        ApiLocalRecordingDeleteService(
          apiClient: ApiClient(
            config: AppConfig(
              environment: AppEnvironment.local,
              apiBaseUrl: Uri.parse('http://localhost:8000'),
            ),
            dio: dio,
          ),
        );

    await service.delete(recordingId: 'local-1', deviceId: 'device-1');

    expect(adapter.calls, 1);
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

typedef _Handler = FutureOr<ResponseBody> Function(RequestOptions options);

final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final _Handler _handler;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
