import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/platform/flv_timestamp_normalizer.dart';

void main() {
  test('rebases FLV timestamps and adds a seek index', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'savestream-flv-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/recording.flv');
    await file.writeAsBytes(_flvWithTimestamps(<int>[1429180, 1431180]));

    final FlvTimestampNormalizationResult result = await normalizeFlvTimestamps(
      file.path,
    );

    expect(result.changed, isTrue);
    expect(result.mediaStartMilliseconds, 1429180);
    expect(result.tagCount, 3);
    final int normalizedLength = await file.length();
    expect(normalizedLength, greaterThan(0));
    expect(await _timestamps(file), <int>[0, 0, 0, 2000]);

    final FlvTimestampNormalizationResult second = await normalizeFlvTimestamps(
      file.path,
    );
    expect(second.changed, isFalse);
    expect(await file.length(), normalizedLength);
    expect(await _timestamps(file), <int>[0, 0, 0, 2000]);
  });

  test('ignores non-FLV files', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'savestream-flv-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/recording.mp4');
    await file.writeAsBytes(<int>[1, 2, 3]);

    final FlvTimestampNormalizationResult result = await normalizeFlvTimestamps(
      file.path,
    );

    expect(result.changed, isFalse);
  });
}

Uint8List _flvWithTimestamps(List<int> timestamps) {
  final BytesBuilder output = BytesBuilder()
    ..add(<int>[0x46, 0x4c, 0x56, 1, 5, 0, 0, 0, 9])
    ..add(<int>[0, 0, 0, 0]);
  final List<(int, List<int>)> tags = <(int, List<int>)>[
    (0, <int>[0x17, 0]),
    for (final int timestamp in timestamps) (timestamp, <int>[0x17, 1]),
  ];
  for (final (int timestamp, List<int> payload) in tags) {
    output
      ..add(<int>[
        9,
        0,
        0,
        payload.length,
        (timestamp >> 16) & 0xff,
        (timestamp >> 8) & 0xff,
        timestamp & 0xff,
        (timestamp >> 24) & 0xff,
        0,
        0,
        0,
      ])
      ..add(payload)
      ..add(<int>[0, 0, 0, 11 + payload.length]);
  }
  return output.takeBytes();
}

Future<List<int>> _timestamps(File file) async {
  final Uint8List bytes = await file.readAsBytes();
  final List<int> values = <int>[];
  int cursor = 13;
  while (cursor + 11 <= bytes.length) {
    final int size =
        (bytes[cursor + 1] << 16) |
        (bytes[cursor + 2] << 8) |
        bytes[cursor + 3];
    values.add(
      (bytes[cursor + 7] << 24) |
          (bytes[cursor + 4] << 16) |
          (bytes[cursor + 5] << 8) |
          bytes[cursor + 6],
    );
    cursor += 11 + size + 4;
  }
  return values;
}
