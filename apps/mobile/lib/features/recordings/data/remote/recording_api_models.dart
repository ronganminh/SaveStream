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
    required this.createdAt,
    required this.updatedAt,
    this.startedAt,
    this.endedAt,
    this.actualCost,
    this.creditReservationId,
    this.errorCode,
    this.errorMessage,
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
  final int? actualCost;
  final String? creditReservationId;
  final String? errorCode;
  final String? errorMessage;
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
      actualCost: _optionalInt(map['actual_cost'], 'actual_cost'),
      creditReservationId: _optionalString(
        map['credit_reservation_id'],
        'credit_reservation_id',
      ),
      errorCode: errorCode,
      errorMessage: errorMessage,
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
      costCredits: actualCost?.toDouble(),
      errorCode: errorCode,
      errorMessage: errorMessage,
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
  });

  final String id;
  final String recordingId;
  final int sizeBytes;
  final String checksumSha256;
  final DateTime createdAt;

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
    );
  }

  RecordingArtifactSummary toDomain() {
    return RecordingArtifactSummary(
      id: id,
      recordingId: recordingId,
      sizeBytes: sizeBytes,
      checksumSha256: checksumSha256,
      createdAt: createdAt,
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
    'recording' => RecordingStatus.recording,
    'processing' => RecordingStatus.processing,
    'uploading' => RecordingStatus.uploading,
    'completed' => RecordingStatus.completed,
    'failed' => RecordingStatus.failed,
    'stop_requested' => RecordingStatus.stopRequested,
    'stopped' => RecordingStatus.stopped,
    _ => throw FormatException('Unsupported Recording status: $value'),
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

String? _optionalString(Object? value, String name) {
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Expected nullable $name string.');
  }
  return value.trim();
}

bool _requiredBool(Object? value, String name) {
  if (value is! bool) {
    throw FormatException('Expected $name boolean.');
  }
  return value;
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
