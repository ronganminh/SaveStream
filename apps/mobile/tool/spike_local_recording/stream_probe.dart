import 'dart:io';

enum StreamProbeTransport { flv, hls, rtmp, unknown }

StreamProbeTransport classifyStreamTransport({
  required Uri uri,
  String? contentType,
}) {
  final String scheme = uri.scheme.toLowerCase();
  if (scheme == 'rtmp' || scheme == 'rtmps') {
    return StreamProbeTransport.rtmp;
  }

  final String normalizedContentType = (contentType ?? '').toLowerCase();
  if (normalizedContentType.contains('x-flv') ||
      normalizedContentType.contains('video/flv')) {
    return StreamProbeTransport.flv;
  }
  if (normalizedContentType.contains('mpegurl')) {
    return StreamProbeTransport.hls;
  }

  final String lowerUrl = uri.toString().toLowerCase();
  if (lowerUrl.contains('.m3u8')) {
    return StreamProbeTransport.hls;
  }
  if (lowerUrl.contains('.flv')) {
    return StreamProbeTransport.flv;
  }

  return StreamProbeTransport.unknown;
}

final class StreamProbeRequest {
  const StreamProbeRequest({
    required this.uri,
    required this.outputFile,
    required this.maxDuration,
    this.headers = const <String, String>{},
    this.idleTimeout = const Duration(seconds: 15),
  });

  final Uri uri;
  final File outputFile;
  final Duration maxDuration;
  final Map<String, String> headers;
  final Duration idleTimeout;
}

final class StreamProbeResult {
  const StreamProbeResult({
    required this.uri,
    required this.transport,
    required this.statusCode,
    required this.bytesWritten,
    required this.elapsed,
    required this.contentType,
  });

  final Uri uri;
  final StreamProbeTransport transport;
  final int statusCode;
  final int bytesWritten;
  final Duration elapsed;
  final String? contentType;

  double get bytesPerSecond {
    if (elapsed.inMicroseconds <= 0) {
      return 0;
    }
    return bytesWritten * Duration.microsecondsPerSecond / elapsed.inMicroseconds;
  }

  double get mebibytesPerMinute {
    return bytesPerSecond * 60 / (1024 * 1024);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'url': uri.toString(),
      'transport': transport.name,
      'status_code': statusCode,
      'bytes_written': bytesWritten,
      'elapsed_ms': elapsed.inMilliseconds,
      'bytes_per_second': bytesPerSecond,
      'mib_per_minute': mebibytesPerMinute,
      'content_type': contentType,
    };
  }
}

typedef HttpClientFactory = HttpClient Function();

final class StreamProbe {
  StreamProbe({HttpClientFactory? httpClientFactory})
    : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final HttpClientFactory _httpClientFactory;

  Future<StreamProbeResult> run(StreamProbeRequest probe) async {
    if (probe.maxDuration <= Duration.zero) {
      throw ArgumentError.value(
        probe.maxDuration,
        'maxDuration',
        'must be greater than zero',
      );
    }

    await probe.outputFile.parent.create(recursive: true);

    final HttpClient client = _httpClientFactory();
    client.autoUncompress = false;
    client.connectionTimeout = probe.idleTimeout;

    final Stopwatch stopwatch = Stopwatch()..start();
    IOSink? sink;
    int bytesWritten = 0;

    try {
      final HttpClientRequest request = await client.getUrl(probe.uri);
      for (final MapEntry<String, String> header in probe.headers.entries) {
        request.headers.set(header.key, header.value);
      }

      final HttpClientResponse response = await request.close();
      final String? contentType = response.headers.value(
        HttpHeaders.contentTypeHeader,
      );
      final StreamProbeTransport transport = classifyStreamTransport(
        uri: probe.uri,
        contentType: contentType,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        stopwatch.stop();
        return StreamProbeResult(
          uri: probe.uri,
          transport: transport,
          statusCode: response.statusCode,
          bytesWritten: 0,
          elapsed: stopwatch.elapsed,
          contentType: contentType,
        );
      }

      sink = probe.outputFile.openWrite();
      await for (final List<int> chunk in response.timeout(probe.idleTimeout)) {
        if (chunk.isEmpty) {
          continue;
        }

        sink.add(chunk);
        bytesWritten += chunk.length;

        if (stopwatch.elapsed >= probe.maxDuration) {
          break;
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      stopwatch.stop();

      return StreamProbeResult(
        uri: probe.uri,
        transport: transport,
        statusCode: response.statusCode,
        bytesWritten: bytesWritten,
        elapsed: stopwatch.elapsed,
        contentType: contentType,
      );
    } finally {
      stopwatch.stop();
      await sink?.close();
      client.close(force: true);
    }
  }
}
