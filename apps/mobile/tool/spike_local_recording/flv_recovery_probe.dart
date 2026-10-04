import 'dart:io';
import 'dart:typed_data';

final class FlvRecoveryReport {
  const FlvRecoveryReport({
    required this.headerValid,
    required this.fileLength,
    required this.dataOffset,
    required this.completeTagCount,
    required this.safeLength,
    required this.lastTimestampMs,
    required this.truncatedTailBytes,
    required this.previousTagSizeValid,
  });

  final bool headerValid;
  final int fileLength;
  final int? dataOffset;
  final int completeTagCount;
  final int safeLength;
  final int? lastTimestampMs;
  final int truncatedTailBytes;
  final bool previousTagSizeValid;

  bool get hasRecoverablePrefix =>
      headerValid && previousTagSizeValid && completeTagCount > 0;
}

Future<FlvRecoveryReport> inspectFlvFile(File file) async {
  final RandomAccessFile input = await file.open();
  try {
    final int fileLength = await input.length();
    if (fileLength < 9) {
      return FlvRecoveryReport(
        headerValid: false,
        fileLength: fileLength,
        dataOffset: null,
        completeTagCount: 0,
        safeLength: 0,
        lastTimestampMs: null,
        truncatedTailBytes: fileLength,
        previousTagSizeValid: false,
      );
    }

    await input.setPosition(0);
    final Uint8List header = await input.read(9);
    final bool headerValid =
        header.length == 9 &&
        header[0] == 0x46 &&
        header[1] == 0x4c &&
        header[2] == 0x56;
    final int dataOffset = _uint32(header, 5);

    if (!headerValid ||
        dataOffset < 9 ||
        dataOffset > fileLength ||
        fileLength < dataOffset + 4) {
      return FlvRecoveryReport(
        headerValid: headerValid,
        fileLength: fileLength,
        dataOffset: dataOffset,
        completeTagCount: 0,
        safeLength: 0,
        lastTimestampMs: null,
        truncatedTailBytes: fileLength,
        previousTagSizeValid: false,
      );
    }

    int position = dataOffset + 4;
    int safeLength = position;
    int completeTagCount = 0;
    int? lastTimestampMs;
    bool previousTagSizeValid = true;

    while (position < fileLength) {
      if (fileLength - position < 11) {
        break;
      }

      await input.setPosition(position);
      final Uint8List tagHeader = await input.read(11);
      if (tagHeader.length < 11) {
        break;
      }

      final int dataSize = _uint24(tagHeader, 1);
      final int timestampMs =
          _uint24(tagHeader, 4) | (tagHeader[7] << 24);
      final int previousTagSizePosition = position + 11 + dataSize;
      final int tagEnd = previousTagSizePosition + 4;
      if (tagEnd > fileLength) {
        break;
      }

      await input.setPosition(previousTagSizePosition);
      final Uint8List previousTagSizeBytes = await input.read(4);
      if (previousTagSizeBytes.length < 4) {
        break;
      }

      final int previousTagSize = _uint32(previousTagSizeBytes, 0);
      if (previousTagSize != 11 + dataSize) {
        previousTagSizeValid = false;
        break;
      }

      completeTagCount += 1;
      lastTimestampMs = timestampMs;
      safeLength = tagEnd;
      position = tagEnd;
    }

    return FlvRecoveryReport(
      headerValid: true,
      fileLength: fileLength,
      dataOffset: dataOffset,
      completeTagCount: completeTagCount,
      safeLength: safeLength,
      lastTimestampMs: lastTimestampMs,
      truncatedTailBytes: fileLength - safeLength,
      previousTagSizeValid: previousTagSizeValid,
    );
  } finally {
    await input.close();
  }
}

int _uint24(Uint8List bytes, int offset) {
  return (bytes[offset] << 16) |
      (bytes[offset + 1] << 8) |
      bytes[offset + 2];
}

int _uint32(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}
