import '../../domain/models/recording_summary.dart';

final class RecordingApiModel {
  const RecordingApiModel({
    required this.id,
    required this.sourceType,
    required this.sourceValue,
    required this.creatorDisplayName,
    required this.creatorUsername,
    required this.status,
    required this.actions,
    required this.durationSeconds,
    required this.bytesRecorded,
    required this.estimatedMaxCost,
    required this.artifactReady,
    required this.createdAt,
    required this.updatedAt,
    this.startedAt,
    this.endedAt,
    this.actualCost,
    this.creditReservationId,
    this.errorCode,
    this.errorMessage,
    this.failureReason,
    this.failureGuidance,
    this.expiresAt,
    this.minutesCharged = 0,
    this.queuePosition,
    this.thumbnailUrl,
  });

  final String id;
  final RecordingSourceType sourceType;
  final String sourceValue;
  final String creatorDisplayName;
  final String creatorUsername;
  final RecordingStatus status;
  final RecordingActions actions;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final int bytesRecorded;
  final int estimatedMaxCost;
  final bool artifactReady;
  final int? actualCost;
  final String? creditReservationId;
  final String? errorCode;
  final String? errorMessage;

  /// Plain-English `failure_reason` / `failure_guidance` the server adds to a
  /// failed or missed recording; null on older servers.
  final String? failureReason;
  final String? failureGuidance;
  final DateTime? expiresAt;
  final int minutesCharged;
  final int? queuePosition;
  final String? thumbnailUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RecordingApiModel.fromJson(Object? json) {
    final Map<Object?, Object?> map = _requiredMap(json, 'recording');
    final Map<Object?, Object?> source = _requiredMap(map['source'], 'source');
    final RecordingSourceType sourceType = _sourceType(
      _requiredString(source['type'], 'source.type'),
    );
    final String sourceValue = _requiredString(source['value'], 'source.value');

    String? creatorUsername;
    String? creatorDisplayName;
    final Object? rawCreator = map['creator'];
    if (rawCreator != null) {
      final Map<Object?, Object?> creator = _requiredMap(rawCreator, 'creator');
      final Object? platform = creator['platform'];
      if (platform != null && platform != 'tiktok') {
        throw const FormatException('Unsupported creator platform.');
      }
      creatorUsername = _requiredString(
        creator['username'],
        'creator.username',
      );
      creatorDisplayName = _requiredString(
        creator['display_name'],
        'creator.display_name',
      );
    }

    final String fallback = _fallbackUsername(sourceType, sourceValue);
    final String normalizedUsername = _displayUsername(
      creatorUsername ?? fallback,
    );
    final String normalizedDisplayName =
        (creatorDisplayName?.trim().isNotEmpty ?? false)
        ? creatorDisplayName!.trim()
        : _fallbackDisplayName(normalizedUsername);

    final Map<Object?, Object?> actions = _requiredMap(
      map['actions'],
      'actions',
    );
    final Object? rawError = map['error'];
    String? errorCode;
    String? errorMessage;
    if (rawError != null) {
      final Map<Object?, Object?> error = _requiredMap(rawError, 'error');
      errorCode = _requiredString(error['code'], 'error.code');
      errorMessage = _requiredString(error['message'], 'error.message');
      _requiredBool(error['retryable'], 'error.retryable');
    }

    return RecordingApiModel(
      id: _requiredString(map['id'], 'id'),
      sourceType: sourceType,
      sourceValue: sourceValue,
      creatorDisplayName: normalizedDisplayName,
      creatorUsername: normalizedUsername,
      status: recordingStatusFromApi(_requiredString(map['status'], 'status')),
      actions: RecordingActions(
        canStop: _requiredBool(actions['can_stop'], 'actions.can_stop'),
        canRetry: _requiredBool(actions['can_retry'], 'actions.can_retry'),
        canDelete: _requiredBool(actions['can_delete'], 'actions.can_delete'),
      ),
      startedAt: _optionalDateTime(map['started_at'], 'started_at'),
      endedAt: _optionalDateTime(map['ended_at'], 'ended_at'),
      durationSeconds: _requiredInt(
        map['duration_seconds'],
        'duration_seconds',
      ),
      bytesRecorded: _requiredInt(map['bytes_recorded'], 'bytes_recorded'),
      estimatedMaxCost: _requiredInt(
        map['estimated_max_cost'],
        'estimated_max_cost',
      ),
      artifactReady:
          _optionalBool(map['playback_ready'], 'playback_ready') ?? false,
      actualCost: _optionalInt(map['actual_cost'], 'actual_cost'),
      creditReservationId: _optionalString(
        map['credit_reservation_id'],
        'credit_reservation_id',
      ),
      errorCode: errorCode,
      errorMessage: errorMessage,
      failureReason: _optionalText(map['failure_reason']),
      failureGuidance: _optionalText(map['failure_guidance']),
      expiresAt: _optionalDateTime(map['expires_at'], 'expires_at'),
      minutesCharged:
          _optionalInt(map['minutes_charged'], 'minutes_charged') ?? 0,
      queuePosition: _optionalPositiveInt(
        map['queue_position'],
        'queue_position',
      ),
      thumbnailUrl: _optionalHttpUrl(map['thumbnail_url'], 'thumbnail_url'),
      createdAt: _requiredDateTime(map['created_at'], 'created_at'),
      updatedAt: _requiredDateTime(map['updated_at'], 'updated_at'),
    );
  }

  RecordingSummary toDomain() {
    return RecordingSummary(
      id: id,
      sourceType: sourceType,
      sourceValue: sourceValue,
      creatorDisplayName: creatorDisplayName,
      creatorUsername: creatorUsername,
      status: status,
      actions: actions,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: durationSeconds,
      bytesRecorded: bytesRecorded,
      artifactReady: artifactReady,
      costCredits: actualCost?.toDouble(),
      errorCode: errorCode,
      errorMessage: errorMessage,
      failureReason: failureReason,
      failureGuidance: failureGuidance,
      expiresAt: expiresAt,
      minutesCharged: minutesCharged,
      queuePosition: queuePosition,
      thumbnailUrl: thumbnailUrl,
    );
  }
}

final class RecordingApiPage {
  const RecordingApiPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<RecordingApiModel> items;
  final String? nextCursor;
  final bool hasMore;

  factory RecordingApiPage.fromJson(Object? json) {
    final Map<Object?, Object?> map = _requiredMap(json, 'recording list');
    final Object? rawItems = map['items'];
    if (rawItems is! List) {
      throw const FormatException('Recording list items must be an array.');
    }
    final Map<Object?, Object?> pagination = _requiredMap(
      map['pagination'],
      'pagination',
    );
    final bool hasMore = _requiredBool(
      pagination['has_more'],
      'pagination.has_more',
    );
    final String? nextCursor = _optionalString(
      pagination['next_cursor'],
      'pagination.next_cursor',
    );
    if (hasMore && (nextCursor == null || nextCursor.isEmpty)) {
      throw const FormatException(
        'A paginated Recording response must include next_cursor.',
      );
    }
    return RecordingApiPage(
      items: rawItems
          .map<RecordingApiModel>(RecordingApiModel.fromJson)
          .toList(growable: false),
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }
}

final class RecordingArtifactApiModel {
  const RecordingArtifactApiModel({
    required this.id,
    required this.recordingId,
    required this.sizeBytes,
    required this.checksumSha256,
    required this.createdAt,
    this.width,
    this.height,
  });

  final String id;
  final String recordingId;
  final int sizeBytes;
  final String checksumSha256;
  final DateTime createdAt;
  final int? width;
  final int? height;

  factory RecordingArtifactApiModel.fromJson(Object? json) {
    final Map<Object?, Object?> map = _requiredMap(json, 'artifact');
    if (map['kind'] != 'video' || map['container'] != 'mp4') {
      throw const FormatException('Unsupported recording artifact type.');
    }
    return RecordingArtifactApiModel(
      id: _requiredString(map['id'], 'id'),
      recordingId: _requiredString(map['recording_id'], 'recording_id'),
      sizeBytes: _requiredInt(map['size_bytes'], 'size_bytes'),
      checksumSha256: _requiredString(
        map['checksum_sha256'],
        'checksum_sha256',
      ),
      createdAt: _requiredDateTime(map['created_at'], 'created_at'),
      width: _optionalPositiveInt(map['width'], 'width'),
      height: _optionalPositiveInt(map['height'], 'height'),
    );
  }

  RecordingArtifactSummary toDomain() {
    return RecordingArtifactSummary(
      id: id,
      recordingId: recordingId,
      sizeBytes: sizeBytes,
      checksumSha256: checksumSha256,
      createdAt: createdAt,
      width: width,
      height: height,
    );
  }
}

List<RecordingArtifactApiModel> recordingArtifactsFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'artifacts');
  final Object? rawItems = map['items'];
  if (rawItems is! List) {
    throw const FormatException('Artifact items must be an array.');
  }
  return rawItems
      .map<RecordingArtifactApiModel>(RecordingArtifactApiModel.fromJson)
      .toList(growable: false);
}

ArtifactDownloadUrl recordingDownloadUrlFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'download URL');
  final Uri? uri = Uri.tryParse(_requiredString(map['url'], 'url'));
  if (uri == null || !uri.hasScheme) {
    throw const FormatException('Invalid artifact download URL.');
  }
  return ArtifactDownloadUrl(
    uri: uri,
    expiresAt: _requiredDateTime(map['expires_at'], 'expires_at'),
  );
}

RecordingStatus recordingStatusFromApi(String value) {
  return switch (value) {
    'queued' => RecordingStatus.queued,
    'resolving' => RecordingStatus.resolving,
    'waiting_live' => RecordingStatus.waitingLive,
    'waiting_for_cloud_slot' => RecordingStatus.waitingForCloudSlot,
    'recording' => RecordingStatus.recording,
    'processing' => RecordingStatus.processing,
    'uploading' => RecordingStatus.uploading,
    'completed' => RecordingStatus.completed,
    'failed' => RecordingStatus.failed,
    'stop_requested' => RecordingStatus.stopRequested,
    'stopped' => RecordingStatus.stopped,
    'missed_no_cloud_slot' => RecordingStatus.missedNoCloudSlot,
    // Forward-compatible fallback: an unknown backend lifecycle must not make
    // the whole recording list undecodable. Treat it as terminal until the
    // app learns the new state instead of spinning indefinitely.
    _ => RecordingStatus.failed,
  };
}

RecordingSourceType _sourceType(String value) {
  return switch (value) {
    'username' => RecordingSourceType.username,
    'room_id' => RecordingSourceType.roomId,
    'url' => RecordingSourceType.url,
    _ => throw FormatException('Unsupported Recording source type: $value'),
  };
}

Map<Object?, Object?> _requiredMap(Object? value, String name) {
  if (value is! Map) {
    throw FormatException('Expected $name object.');
  }
  return value;
}

String _requiredString(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Expected non-empty $name.');
  }
  return value.trim();
}

/// Display text that only adds to the UI: anything but a non-blank string
/// reads as absent instead of failing the whole recording.
String? _optionalText(Object? value) {
  if (value is! String) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _optionalString(Object? value, String name) {
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Expected nullable $name string.');
  }
  return value.trim();
}

/// An http(s) URL, or null when absent or unusable (a bad thumbnail URL
/// only drops the image).
String? _optionalHttpUrl(Object? value, String name) {
  final String? raw = _optionalString(value, name);
  if (raw == null || raw.isEmpty) return null;
  final Uri? uri = Uri.tryParse(raw);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  return raw;
}

bool _requiredBool(Object? value, String name) {
  if (value is! bool) {
    throw FormatException('Expected $name boolean.');
  }
  return value;
}

bool? _optionalBool(Object? value, String name) {
  if (value == null) return null;
  return _requiredBool(value, name);
}

int _requiredInt(Object? value, String name) {
  if (value is! int || value < 0) {
    throw FormatException('Expected non-negative $name integer.');
  }
  return value;
}

int? _optionalInt(Object? value, String name) {
  if (value == null) return null;
  return _requiredInt(value, name);
}

int? _optionalPositiveInt(Object? value, String name) {
  final int? parsed = _optionalInt(value, name);
  if (parsed != null && parsed < 1) {
    throw FormatException('Expected positive $name integer.');
  }
  return parsed;
}

DateTime _requiredDateTime(Object? value, String name) {
  final DateTime? parsed = _parseDateTime(value);
  if (parsed == null) {
    throw FormatException('Expected valid $name timestamp.');
  }
  return parsed;
}

DateTime? _optionalDateTime(Object? value, String name) {
  if (value == null) return null;
  final DateTime? parsed = _parseDateTime(value);
  if (parsed == null) {
    throw FormatException('Expected nullable $name timestamp.');
  }
  return parsed;
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toUtc();
}

String _fallbackUsername(RecordingSourceType type, String value) {
  if (type == RecordingSourceType.url) {
    final Uri? uri = Uri.tryParse(value);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last.replaceFirst('@', '');
    }
  }
  return value.replaceFirst('@', '');
}

String _displayUsername(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) return '@unknown';
  return normalized.startsWith('@') ? normalized : '@$normalized';
}

String _fallbackDisplayName(String username) {
  final String normalized = username.replaceFirst('@', '').trim();
  return normalized.isEmpty ? 'TikTok creator' : normalized;
}
