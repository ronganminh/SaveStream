import 'dart:async';
import 'dart:io';

import '../../../platform/contracts/device_info_service.dart';

typedef CloudDownloadProgress = void Function({
  required int receivedBytes,
  required int? totalBytes,
});

final class CloudDownloadResult {
  const CloudDownloadResult({
    required this.file,
    required this.bytesWritten,
    required this.resumed,
  });

  final File file;
  final int bytesWritten;
  final bool resumed;
}

final class CloudDownloadStorageException implements IOException {
  const CloudDownloadStorageException({
    required this.freeBytes,
    required this.requiredBytes,
  });

  final int freeBytes;
  final int requiredBytes;

  @override
  String toString() {
    return 'Insufficient storage: $freeBytes available, '
        '$requiredBytes required.';
  }
}

final class CloudArtifactDownloader {
  CloudArtifactDownloader({
    required DeviceInfoService deviceInfo,
    HttpClient? httpClient,
    this.storageReserveBytes = 250 * 1024 * 1024,
  }) : _deviceInfo = deviceInfo,
       _httpClient = httpClient ?? HttpClient();

  final DeviceInfoService _deviceInfo;
  final HttpClient _httpClient;
  final int storageReserveBytes;

  Future<CloudDownloadResult> download({
    required Uri uri,
    required File destination,
    CloudDownloadProgress? onProgress,
  }) async {
    await destination.parent.create(recursive: true);

    int existingBytes = await destination.exists()
        ? await destination.length()
        : 0;
    final HttpClientRequest request = await _httpClient.getUrl(uri);
    if (existingBytes > 0) {
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
    }

    final HttpClientResponse response = await request.close();
    bool resumed =
        existingBytes > 0 && response.statusCode == HttpStatus.partialContent;

    if (existingBytes > 0 &&
        response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
      return CloudDownloadResult(
        file: destination,
        bytesWritten: existingBytes,
        resumed: true,
      );
    }

    if (existingBytes > 0 && response.statusCode == HttpStatus.ok) {
      existingBytes = 0;
      resumed = false;
    } else if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      await response.drain<void>();
      throw HttpException(
        'Cloud download failed with HTTP ${response.statusCode}.',
        uri: uri,
      );
    }

    final int? remainingBytes = response.contentLength >= 0
        ? response.contentLength
        : null;
    final int freeBytes = await _deviceInfo.freeStorageBytes;
    if (remainingBytes != null &&
        freeBytes < remainingBytes + storageReserveBytes) {
      await response.drain<void>();
      throw CloudDownloadStorageException(
        freeBytes: freeBytes,
        requiredBytes: remainingBytes + storageReserveBytes,
      );
    }

    final RandomAccessFile output = await destination.open(
      mode: resumed ? FileMode.append : FileMode.write,
    );
    int receivedBytes = existingBytes;
    final int? totalBytes = remainingBytes == null
        ? null
        : existingBytes + remainingBytes;
    try {
      await for (final List<int> chunk in response) {
        await output.writeFrom(chunk);
        receivedBytes += chunk.length;
        onProgress?.call(
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
        );
      }
      await output.flush();
    } finally {
      await output.close();
    }

    return CloudDownloadResult(
      file: destination,
      bytesWritten: receivedBytes,
      resumed: resumed,
    );
  }

  void close({bool force = false}) {
    _httpClient.close(force: force);
  }
}
