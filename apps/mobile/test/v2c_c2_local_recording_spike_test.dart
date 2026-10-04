import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/spike_local_recording/stream_probe.dart';

void main() {
  test('classifies FLV, HLS and RTMP transports', () {
    expect(
      classifyStreamTransport(uri: Uri.parse('https://cdn.example/live.flv')),
      StreamProbeTransport.flv,
    );
    expect(
      classifyStreamTransport(uri: Uri.parse('https://cdn.example/live.m3u8')),
      StreamProbeTransport.hls,
    );
    expect(
      classifyStreamTransport(uri: Uri.parse('rtmp://cdn.example/live')),
      StreamProbeTransport.rtmp,
    );
    expect(
      classifyStreamTransport(
        uri: Uri.parse('https://cdn.example/live'),
        contentType: 'video/x-flv',
      ),
      StreamProbeTransport.flv,
    );
  });

  test('records response bytes and forwards explicit headers', () async {
    final Completer<String?> receivedHeader = Completer<String?>();
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    server.listen((HttpRequest request) async {
      receivedHeader.complete(request.headers.value('x-spike-token'));
      request.response.headers.contentType = ContentType('video', 'x-flv');
      request.response.add(<int>[1, 2, 3]);
      request.response.add(<int>[4, 5]);
      await request.response.close();
    });

    final Directory directory = await Directory.systemTemp.createTemp(
      'savestream-c2-probe-',
    );
    final File output = File('${directory.path}/sample.flv');

    try {
      final StreamProbeResult result = await StreamProbe().run(
        StreamProbeRequest(
          uri: Uri.parse('http://127.0.0.1:${server.port}/sample.flv'),
          outputFile: output,
          maxDuration: const Duration(seconds: 5),
          headers: const <String, String>{'x-spike-token': 'expected'},
        ),
      );

      expect(await receivedHeader.future, 'expected');
      expect(result.statusCode, HttpStatus.ok);
      expect(result.transport, StreamProbeTransport.flv);
      expect(result.bytesWritten, 5);
      expect(await output.readAsBytes(), <int>[1, 2, 3, 4, 5]);
      expect(result.bytesPerSecond, greaterThanOrEqualTo(0));
      expect(result.mebibytesPerMinute, greaterThanOrEqualTo(0));
    } finally {
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });

  test('keeps non-success status as measurable zero-byte evidence', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    server.listen((HttpRequest request) async {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
    });

    final Directory directory = await Directory.systemTemp.createTemp(
      'savestream-c2-probe-',
    );

    try {
      final StreamProbeResult result = await StreamProbe().run(
        StreamProbeRequest(
          uri: Uri.parse('http://127.0.0.1:${server.port}/blocked.flv'),
          outputFile: File('${directory.path}/blocked.flv'),
          maxDuration: const Duration(seconds: 5),
        ),
      );

      expect(result.statusCode, HttpStatus.forbidden);
      expect(result.transport, StreamProbeTransport.flv);
      expect(result.bytesWritten, 0);
    } finally {
      await server.close(force: true);
      await directory.delete(recursive: true);
    }
  });
}
