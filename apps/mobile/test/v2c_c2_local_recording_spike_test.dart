import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/spike_local_recording/flv_probe.dart';
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

  test('FLV probe finds the last complete tag boundary', () {
    final List<int> firstOnly = _flv(<List<int>>[
      <int>[1, 2, 3],
    ]);
    final List<int> complete = _flv(<List<int>>[
      <int>[1, 2, 3],
      <int>[4, 5, 6, 7],
    ]);
    final List<int> truncated = complete.sublist(0, complete.length - 3);

    final FlvInspection completeInspection = inspectFlvBytes(complete);
    final FlvInspection truncatedInspection = inspectFlvBytes(truncated);

    expect(completeInspection.validHeader, isTrue);
    expect(completeInspection.completeTags, 2);
    expect(completeInspection.safeLength, complete.length);
    expect(completeInspection.truncated, isFalse);
    expect(completeInspection.malformed, isFalse);

    expect(truncatedInspection.validHeader, isTrue);
    expect(truncatedInspection.completeTags, 1);
    expect(truncatedInspection.safeLength, firstOnly.length);
    expect(truncatedInspection.truncated, isTrue);
    expect(truncatedInspection.hasRecoverablePrefix, isTrue);
  });

  test('FLV probe rejects malformed previous-tag-size metadata', () {
    final List<int> bytes = _flv(<List<int>>[
      <int>[1, 2, 3],
    ]);
    bytes[bytes.length - 1] = 0;

    final FlvInspection inspection = inspectFlvBytes(bytes);

    expect(inspection.validHeader, isTrue);
    expect(inspection.completeTags, 0);
    expect(inspection.malformed, isTrue);
    expect(inspection.hasRecoverablePrefix, isFalse);
  });
}

List<int> _flv(List<List<int>> payloads) {
  final List<int> bytes = <int>[
    0x46,
    0x4c,
    0x56,
    0x01,
    0x05,
    0x00,
    0x00,
    0x00,
    0x09,
    0x00,
    0x00,
    0x00,
    0x00,
  ];

  for (final List<int> payload in payloads) {
    final int dataSize = payload.length;
    bytes.addAll(<int>[
      0x09,
      (dataSize >> 16) & 0xff,
      (dataSize >> 8) & 0xff,
      dataSize & 0xff,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      ...payload,
    ]);
    final int previousTagSize = 11 + dataSize;
    bytes.addAll(<int>[
      (previousTagSize >> 24) & 0xff,
      (previousTagSize >> 16) & 0xff,
      (previousTagSize >> 8) & 0xff,
      previousTagSize & 0xff,
    ]);
  }

  return bytes;
}
