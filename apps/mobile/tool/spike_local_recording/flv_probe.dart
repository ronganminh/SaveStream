final class FlvInspection {
  const FlvInspection({
    required this.validHeader,
    required this.completeTags,
    required this.safeLength,
    required this.truncated,
    required this.malformed,
  });

  final bool validHeader;
  final int completeTags;
  final int safeLength;
  final bool truncated;
  final bool malformed;

  bool get hasRecoverablePrefix =>
      validHeader && completeTags > 0 && !malformed;
}

FlvInspection inspectFlvBytes(List<int> bytes) {
  if (bytes.length < 13 || !_hasFlvSignature(bytes)) {
    return const FlvInspection(
      validHeader: false,
      completeTags: 0,
      safeLength: 0,
      truncated: true,
      malformed: false,
    );
  }

  final int dataOffset = _readUint32(bytes, 5);
  if (dataOffset < 9 || dataOffset + 4 > bytes.length) {
    return const FlvInspection(
      validHeader: false,
      completeTags: 0,
      safeLength: 0,
      truncated: true,
      malformed: false,
    );
  }

  int cursor = dataOffset + 4;
  int safeLength = cursor;
  int completeTags = 0;
  bool truncated = false;
  bool malformed = false;

  while (cursor < bytes.length) {
    if (bytes.length - cursor < 11) {
      truncated = true;
      break;
    }

    final int dataSize = _readUint24(bytes, cursor + 1);
    final int tagPayloadEnd = cursor + 11 + dataSize;
    final int tagEnd = tagPayloadEnd + 4;
    if (tagEnd > bytes.length) {
      truncated = true;
      break;
    }

    final int previousTagSize = _readUint32(bytes, tagPayloadEnd);
    if (previousTagSize != 11 + dataSize) {
      malformed = true;
      break;
    }

    completeTags += 1;
    safeLength = tagEnd;
    cursor = tagEnd;
  }

  return FlvInspection(
    validHeader: true,
    completeTags: completeTags,
    safeLength: safeLength,
    truncated: truncated,
    malformed: malformed,
  );
}

bool _hasFlvSignature(List<int> bytes) {
  return bytes[0] == 0x46 && bytes[1] == 0x4c && bytes[2] == 0x56;
}

int _readUint24(List<int> bytes, int offset) {
  return (bytes[offset] << 16) |
      (bytes[offset + 1] << 8) |
      bytes[offset + 2];
}

int _readUint32(List<int> bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}
