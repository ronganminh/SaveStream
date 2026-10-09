import 'dart:io';
import 'dart:typed_data';

class FlvTimestampNormalizationResult {
  const FlvTimestampNormalizationResult({
    required this.changed,
    required this.mediaStartMilliseconds,
    required this.tagCount,
  });

  final bool changed;
  final int? mediaStartMilliseconds;
  final int tagCount;
}

/// Rebases FLV tag timestamps to zero without decoding or re-encoding media.
///
/// TikTok's live FLV stream keeps the timestamp of the already-running live.
/// A recording that starts 20 minutes into a live can therefore look like a
/// 22-minute file even when only two minutes were downloaded. Android's media
/// player then cannot seek using the recording-relative time shown in the UI.
Future<FlvTimestampNormalizationResult> normalizeFlvTimestamps(
  String path,
) async {
  if (!path.toLowerCase().endsWith('.flv')) {
    return const FlvTimestampNormalizationResult(
      changed: false,
      mediaStartMilliseconds: null,
      tagCount: 0,
    );
  }

  final File file = File(path);
  if (!await file.exists() || await file.length() < 13) {
    return const FlvTimestampNormalizationResult(
      changed: false,
      mediaStartMilliseconds: null,
      tagCount: 0,
    );
  }

  final RandomAccessFile reader = await file.open(mode: FileMode.read);
  int? mediaStart;
  int? mediaEnd;
  int tagCount = 0;
  int dataOffset = 0;
  bool hasSeekMetadata = false;
  final List<({int position, int timestamp})> keyframes =
      <({int position, int timestamp})>[];

  try {
    final Uint8List header = await reader.read(9);
    if (header.length != 9 ||
        header[0] != 0x46 ||
        header[1] != 0x4c ||
        header[2] != 0x56) {
      return const FlvTimestampNormalizationResult(
        changed: false,
        mediaStartMilliseconds: null,
        tagCount: 0,
      );
    }

    dataOffset = _uint32(header, 5);
    final int length = await reader.length();
    int cursor = dataOffset + 4;

    while (cursor + 11 <= length) {
      await reader.setPosition(cursor);
      final Uint8List tagHeader = await reader.read(11);
      if (tagHeader.length != 11) break;

      final int dataSize =
          (tagHeader[1] << 16) | (tagHeader[2] << 8) | tagHeader[3];
      final int tagEnd = cursor + 11 + dataSize + 4;
      if (tagEnd > length) break;

      final int timestamp =
          (tagHeader[7] << 24) |
          (tagHeader[4] << 16) |
          (tagHeader[5] << 8) |
          tagHeader[6];
      final int tagType = tagHeader[0] & 0x1f;
      final int inspectedBytes = tagType == 18
          ? dataSize
          : dataSize < 2
          ? dataSize
          : 2;
      final Uint8List payloadPrefix = inspectedBytes == 0
          ? Uint8List(0)
          : await reader.read(inspectedBytes);
      if (tagType == 18 && _containsAscii(payloadPrefix, _seekMetadataMarker)) {
        hasSeekMetadata = true;
      }
      if (_isPlayableMediaTag(tagType, payloadPrefix)) {
        mediaStart ??= timestamp;
        mediaEnd = mediaEnd == null || timestamp > mediaEnd
            ? timestamp
            : mediaEnd;
        if (_isVideoKeyframe(tagType, payloadPrefix)) {
          keyframes.add((position: cursor, timestamp: timestamp));
        }
      }
      tagCount += 1;
      cursor = tagEnd;
    }
  } finally {
    await reader.close();
  }

  final int? base = mediaStart;
  if (base == null) {
    return FlvTimestampNormalizationResult(
      changed: false,
      mediaStartMilliseconds: null,
      tagCount: tagCount,
    );
  }

  final int durationMilliseconds = ((mediaEnd ?? base) - base).clamp(
    0,
    0xffffffff,
  );
  final bool shouldAddSeekMetadata =
      !hasSeekMetadata && durationMilliseconds > 0 && keyframes.isNotEmpty;
  if (base == 0 && !shouldAddSeekMetadata) {
    return FlvTimestampNormalizationResult(
      changed: false,
      mediaStartMilliseconds: base,
      tagCount: tagCount,
    );
  }

  Uint8List? seekMetadataTag;
  if (shouldAddSeekMetadata) {
    final List<int> keyframeTimes = <int>[
      for (final keyframe in keyframes)
        (keyframe.timestamp - base).clamp(0, 0xffffffff),
    ];
    final Uint8List placeholder = _buildSeekMetadataTag(
      durationMilliseconds: durationMilliseconds,
      keyframeTimesMilliseconds: keyframeTimes,
      keyframePositions: <int>[for (final _ in keyframes) 0],
    );
    seekMetadataTag = _buildSeekMetadataTag(
      durationMilliseconds: durationMilliseconds,
      keyframeTimesMilliseconds: keyframeTimes,
      keyframePositions: <int>[
        for (final keyframe in keyframes)
          keyframe.position + placeholder.length,
      ],
    );
  }

  final File temporary = File('$path.timestamp-normalized');
  final File backup = File('$path.timestamp-original');
  if (await temporary.exists()) await temporary.delete();
  if (await backup.exists()) await backup.delete();

  final RandomAccessFile source = await file.open(mode: FileMode.read);
  final RandomAccessFile writer = await temporary.open(mode: FileMode.write);
  try {
    await _copyBytes(source, writer, dataOffset + 4);
    if (seekMetadataTag != null) {
      await writer.writeFrom(seekMetadataTag);
    }
    final int length = await source.length();
    int cursor = dataOffset + 4;
    while (cursor + 11 <= length) {
      final Uint8List tagHeader = await source.read(11);
      if (tagHeader.length != 11) break;
      final int dataSize =
          (tagHeader[1] << 16) | (tagHeader[2] << 8) | tagHeader[3];
      final int timestamp =
          (tagHeader[7] << 24) |
          (tagHeader[4] << 16) |
          (tagHeader[5] << 8) |
          tagHeader[6];
      final int normalized = timestamp <= base ? 0 : timestamp - base;
      tagHeader[4] = (normalized >> 16) & 0xff;
      tagHeader[5] = (normalized >> 8) & 0xff;
      tagHeader[6] = normalized & 0xff;
      tagHeader[7] = (normalized >> 24) & 0xff;
      await writer.writeFrom(tagHeader);
      await _copyBytes(source, writer, dataSize + 4);
      cursor += 11 + dataSize + 4;
    }
    await writer.flush();
  } finally {
    await source.close();
    await writer.close();
  }

  await file.rename(backup.path);
  try {
    await temporary.rename(path);
  } on Object {
    await backup.rename(path);
    rethrow;
  }
  await backup.delete();

  return FlvTimestampNormalizationResult(
    changed: true,
    mediaStartMilliseconds: base,
    tagCount: tagCount,
  );
}

const String _seekMetadataMarker = 'savestream_seekable';

bool _containsAscii(Uint8List bytes, String value) {
  final List<int> needle = value.codeUnits;
  if (needle.isEmpty || bytes.length < needle.length) return false;
  for (int start = 0; start <= bytes.length - needle.length; start += 1) {
    var matches = true;
    for (int index = 0; index < needle.length; index += 1) {
      if (bytes[start + index] != needle[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

bool _isPlayableMediaTag(int tagType, Uint8List payloadPrefix) {
  if (tagType != 8 && tagType != 9) return false;
  if (payloadPrefix.length < 2) return true;

  if (tagType == 8) {
    final int soundFormat = payloadPrefix[0] >> 4;
    final bool isAacSequenceHeader = soundFormat == 10 && payloadPrefix[1] == 0;
    return !isAacSequenceHeader;
  }

  final int codecId = payloadPrefix[0] & 0x0f;
  final bool isVideoSequenceHeader =
      (codecId == 7 || codecId == 12) && payloadPrefix[1] == 0;
  return !isVideoSequenceHeader;
}

bool _isVideoKeyframe(int tagType, Uint8List payloadPrefix) {
  return tagType == 9 &&
      payloadPrefix.length >= 2 &&
      (payloadPrefix[0] >> 4) == 1 &&
      payloadPrefix[1] != 0;
}

Uint8List _buildSeekMetadataTag({
  required int durationMilliseconds,
  required List<int> keyframeTimesMilliseconds,
  required List<int> keyframePositions,
}) {
  final BytesBuilder payload = BytesBuilder();
  _writeAmfTypedString(payload, 'onMetaData');
  payload
    ..addByte(8)
    ..add(_uint32Bytes(3));
  _writeAmfNumberProperty(payload, 'duration', durationMilliseconds / 1000);
  _writeAmfStringProperty(payload, _seekMetadataMarker, 'true');
  _writeAmfPropertyName(payload, 'keyframes');
  payload.addByte(3);
  _writeAmfNumberArrayProperty(payload, 'filepositions', <double>[
    for (final int value in keyframePositions) value.toDouble(),
  ]);
  _writeAmfNumberArrayProperty(payload, 'times', <double>[
    for (final int value in keyframeTimesMilliseconds) value / 1000,
  ]);
  payload.add(<int>[0, 0, 9]);
  payload.add(<int>[0, 0, 9]);

  final Uint8List data = payload.takeBytes();
  final BytesBuilder tag = BytesBuilder()
    ..addByte(18)
    ..add(<int>[
      (data.length >> 16) & 0xff,
      (data.length >> 8) & 0xff,
      data.length & 0xff,
    ])
    ..add(<int>[0, 0, 0, 0, 0, 0, 0])
    ..add(data)
    ..add(_uint32Bytes(11 + data.length));
  return tag.takeBytes();
}

void _writeAmfTypedString(BytesBuilder output, String value) {
  output.addByte(2);
  _writeAmfStringBytes(output, value);
}

void _writeAmfStringProperty(BytesBuilder output, String name, String value) {
  _writeAmfPropertyName(output, name);
  _writeAmfTypedString(output, value);
}

void _writeAmfNumberProperty(BytesBuilder output, String name, double value) {
  _writeAmfPropertyName(output, name);
  output
    ..addByte(0)
    ..add(_doubleBytes(value));
}

void _writeAmfNumberArrayProperty(
  BytesBuilder output,
  String name,
  List<double> values,
) {
  _writeAmfPropertyName(output, name);
  output
    ..addByte(10)
    ..add(_uint32Bytes(values.length));
  for (final double value in values) {
    output
      ..addByte(0)
      ..add(_doubleBytes(value));
  }
}

void _writeAmfPropertyName(BytesBuilder output, String value) {
  _writeAmfStringBytes(output, value);
}

void _writeAmfStringBytes(BytesBuilder output, String value) {
  final List<int> bytes = value.codeUnits;
  output.add(<int>[(bytes.length >> 8) & 0xff, bytes.length & 0xff]);
  output.add(bytes);
}

Uint8List _doubleBytes(double value) {
  final ByteData data = ByteData(8)..setFloat64(0, value, Endian.big);
  return data.buffer.asUint8List();
}

Uint8List _uint32Bytes(int value) {
  return Uint8List.fromList(<int>[
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ]);
}

Future<void> _copyBytes(
  RandomAccessFile source,
  RandomAccessFile destination,
  int count,
) async {
  var remaining = count;
  while (remaining > 0) {
    final Uint8List chunk = await source.read(
      remaining > 1024 * 1024 ? 1024 * 1024 : remaining,
    );
    if (chunk.isEmpty) {
      throw const FileSystemException('Unexpected end of FLV file.');
    }
    await destination.writeFrom(chunk);
    remaining -= chunk.length;
  }
}

int _uint32(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}
