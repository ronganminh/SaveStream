import 'dart:convert';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_stream_response.dart';
import '../../domain/models/recording_summary.dart';
import 'recording_api_models.dart';

abstract interface class RecordingEventSource {
  Stream<RecordingEvent> connect(
    String recordingId, {
    String? lastEventId,
  });
}

final class DioRecordingEventSource implements RecordingEventSource {
  const DioRecordingEventSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Stream<RecordingEvent> connect(
    String recordingId, {
    String? lastEventId,
  }) async* {
    final ApiStreamResponse response = await _apiClient.getStream(
      '/v1/recordings/$recordingId/events',
      headers: <String, dynamic>{
        'Accept': 'text/event-stream',
        if (lastEventId != null) 'Last-Event-ID': lastEventId,
      },
    );

    String? id;
    String? eventType;
    final List<String> dataLines = <String>[];

    await for (final String line
        in utf8.decoder
            .bind(response.stream)
            .transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          yield _decodeEvent(
            id: id,
            eventType: eventType,
            data: dataLines.join('\n'),
          );
        }
        id = null;
        eventType = null;
        dataLines.clear();
        continue;
      }
      if (line.startsWith(':')) {
        continue;
      }

      final int separator = line.indexOf(':');
      final String field = separator < 0 ? line : line.substring(0, separator);
      String value = separator < 0 ? '' : line.substring(separator + 1);
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }

      switch (field) {
        case 'id':
          id = value;
        case 'event':
          eventType = value;
        case 'data':
          dataLines.add(value);
      }
    }

    if (dataLines.isNotEmpty) {
      yield _decodeEvent(
        id: id,
        eventType: eventType,
        data: dataLines.join('\n'),
      );
    }
  }

  RecordingEvent _decodeEvent({
    required String? id,
    required String? eventType,
    required String data,
  }) {
    final Object? decoded = jsonDecode(data);
    if (decoded is! Map) {
      throw const FormatException('Expected recording event object.');
    }
    final Object? rawId = decoded['id'];
    final Object? rawSequence = decoded['sequence'];
    final Object? rawType = decoded['type'];
    final Object? rawRecordingId = decoded['recording_id'];
    final Object? rawCreatedAt = decoded['created_at'];
    final Object? rawData = decoded['data'];
    if (rawId is! String ||
        rawId.trim().isEmpty ||
        rawSequence is! int ||
        rawSequence < 0 ||
        rawType is! String ||
        rawType.trim().isEmpty ||
        rawRecordingId is! String ||
        rawRecordingId.trim().isEmpty ||
        rawCreatedAt is! String ||
        rawData is! Map) {
      throw const FormatException('Malformed recording event.');
    }
    if (id != null && id.isNotEmpty && id != rawId) {
      throw const FormatException('SSE event ID does not match payload ID.');
    }
    if (eventType != null && eventType.isNotEmpty && eventType != rawType) {
      throw const FormatException('SSE event type does not match payload.');
    }

    final DateTime? createdAt = DateTime.tryParse(rawCreatedAt)?.toUtc();
    final Object? rawStatus = rawData['status'];
    final Object? rawDuration = rawData['duration_seconds'];
    final Object? rawBytes = rawData['bytes_recorded'];
    if (createdAt == null ||
        rawStatus is! String ||
        rawDuration is! int ||
        rawDuration < 0 ||
        rawBytes is! int ||
        rawBytes < 0) {
      throw const FormatException('Malformed recording progress event.');
    }

    return RecordingEvent(
      id: rawId,
      sequence: rawSequence,
      type: rawType,
      recordingId: rawRecordingId,
      createdAt: createdAt,
      status: recordingStatusFromApi(rawStatus),
      durationSeconds: rawDuration,
      bytesRecorded: rawBytes,
    );
  }
}
