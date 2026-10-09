import '../../domain/models/watch_summary.dart';

enum WatchLiveStatus {
  unknown('unknown'),
  offline('offline'),
  live('live');

  const WatchLiveStatus(this.apiValue);

  final String apiValue;
}

final class CreatorLookupApiModel {
  const CreatorLookupApiModel({
    required this.username,
    required this.displayName,
    required this.liveStatus,
    this.avatarUrl,
    this.roomId,
    this.checkedAt,
  });

  final String username;
  final String displayName;
  final String? avatarUrl;
  final WatchLiveStatus liveStatus;
  final String? roomId;
  final DateTime? checkedAt;

  factory CreatorLookupApiModel.fromJson(Object? json) {
    final Map<Object?, Object?> map = _requiredMap(json, 'live status');
    final Map<Object?, Object?> creator = _requiredMap(
      map['creator'],
      'creator',
    );
    final Object? platform = creator['platform'];
    if (platform != null && platform != 'tiktok') {
      throw const FormatException('Unsupported creator platform.');
    }
    return CreatorLookupApiModel(
      username: _requiredString(creator['username'], 'creator.username'),
      displayName: _requiredString(
        creator['display_name'],
        'creator.display_name',
      ),
      avatarUrl: _optionalString(creator['avatar_url'], 'creator.avatar_url'),
      liveStatus: _liveStatus(
        _requiredString(map['live_status'], 'live_status'),
      ),
      roomId: _optionalString(map['room_id'], 'room_id'),
      checkedAt: _optionalDateTime(map['checked_at'], 'checked_at'),
    );
  }

  CreatorLookupResult toDomain() {
    return CreatorLookupResult(
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl?.isEmpty ?? true ? null : avatarUrl,
      liveStatus: switch (liveStatus) {
        WatchLiveStatus.unknown => CreatorLiveStatus.unknown,
        WatchLiveStatus.offline => CreatorLiveStatus.offline,
        WatchLiveStatus.live => CreatorLiveStatus.live,
      },
      roomId: roomId,
      checkedAt: checkedAt,
    );
  }
}

final class WatchApiModel {
  const WatchApiModel({
    required this.id,
    required this.sourceType,
    required this.sourceValue,
    required this.creatorDisplayName,
    required this.creatorUsername,
    this.creatorAvatarUrl,
    required this.status,
    required this.liveStatus,
    required this.autoRecord,
    required this.notifyOnLive,
    required this.autoRecordState,
    required this.createdAt,
    required this.updatedAt,
    this.lastCheckedAt,
    this.nextCheckAt,
    this.lastLiveAt,
  });

  final String id;
  final WatchSourceType sourceType;
  final String sourceValue;
  final String creatorDisplayName;
  final String creatorUsername;
  final String? creatorAvatarUrl;
  final WatchStatus status;
  final WatchLiveStatus liveStatus;
  final bool autoRecord;
  final bool notifyOnLive;
  final AutoRecordState autoRecordState;
  final DateTime? lastCheckedAt;
  final DateTime? nextCheckAt;
  final DateTime? lastLiveAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WatchApiModel.fromJson(Object? json) {
    final Map<Object?, Object?> map = _requiredMap(json, 'watch');
    final Map<Object?, Object?> source = _requiredMap(map['source'], 'source');
    final WatchSourceType sourceType = _sourceType(
      _requiredString(source['type'], 'source.type'),
    );
    final String sourceValue = _requiredString(source['value'], 'source.value');

    final Object? rawCreator = map['creator'];
    String? creatorUsername;
    String? creatorDisplayName;
    String? creatorAvatarUrl;
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
      creatorAvatarUrl = _optionalString(
        creator['avatar_url'],
        'creator.avatar_url',
      );
    }

    final String fallbackUsername = _fallbackUsername(sourceType, sourceValue);
    final String normalizedUsername = _displayUsername(
      creatorUsername ?? fallbackUsername,
    );
    final String normalizedDisplayName =
        (creatorDisplayName?.trim().isNotEmpty ?? false)
        ? creatorDisplayName!.trim()
        : _fallbackDisplayName(normalizedUsername);

    final bool autoRecord = _requiredBool(map['auto_record'], 'auto_record');

    return WatchApiModel(
      id: _requiredString(map['id'], 'id'),
      sourceType: sourceType,
      sourceValue: sourceValue,
      creatorDisplayName: normalizedDisplayName,
      creatorUsername: normalizedUsername,
      creatorAvatarUrl: creatorAvatarUrl?.isEmpty ?? true
          ? null
          : creatorAvatarUrl,
      status: _watchStatus(_requiredString(map['status'], 'status')),
      liveStatus: _liveStatus(
        _requiredString(map['live_status'], 'live_status'),
      ),
      autoRecord: autoRecord,
      notifyOnLive:
          _optionalBool(map['notify_on_live'], 'notify_on_live') ?? true,
      autoRecordState: _autoRecordState(
        _optionalString(map['auto_record_state'], 'auto_record_state'),
        autoRecord: autoRecord,
      ),
      lastCheckedAt: _optionalDateTime(
        map['last_checked_at'],
        'last_checked_at',
      ),
      nextCheckAt: _optionalDateTime(map['next_check_at'], 'next_check_at'),
      lastLiveAt: _optionalDateTime(map['last_live_at'], 'last_live_at'),
      createdAt: _requiredDateTime(map['created_at'], 'created_at'),
      updatedAt: _requiredDateTime(map['updated_at'], 'updated_at'),
    );
  }

  WatchSummary toDomain() {
    return WatchSummary(
      id: id,
      creatorDisplayName: creatorDisplayName,
      creatorUsername: creatorUsername,
      creatorAvatarUrl: creatorAvatarUrl,
      status: status,
      isLive: liveStatus == WatchLiveStatus.live,
      sourceType: sourceType,
      sourceValue: sourceValue,
      autoRecord: autoRecord,
      notifyOnLive: notifyOnLive,
      autoRecordState: autoRecordState,
      lastCheckedAt: lastCheckedAt,
      nextCheckAt: nextCheckAt,
      lastLiveAt: lastLiveAt,
    );
  }
}

final class WatchApiPage {
  const WatchApiPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<WatchApiModel> items;
  final String? nextCursor;
  final bool hasMore;

  factory WatchApiPage.fromJson(Object? json) {
    final Map<Object?, Object?> map = _requiredMap(json, 'watch list');
    final Object? rawItems = map['items'];
    if (rawItems is! List) {
      throw const FormatException('Watch list items must be an array.');
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
        'A paginated Watch response must include next_cursor.',
      );
    }

    return WatchApiPage(
      items: rawItems
          .map<WatchApiModel>(WatchApiModel.fromJson)
          .toList(growable: false),
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }
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
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Expected nullable $name string.');
  }
  return value.trim();
}

bool? _optionalBool(Object? value, String name) {
  if (value == null) return null;
  if (value is! bool) {
    throw FormatException('Expected nullable $name boolean.');
  }
  return value;
}

bool _requiredBool(Object? value, String name) {
  if (value is! bool) {
    throw FormatException('Expected $name boolean.');
  }
  return value;
}

DateTime _requiredDateTime(Object? value, String name) {
  final DateTime? parsed = _parseDateTime(value);
  if (parsed == null) {
    throw FormatException('Expected valid $name timestamp.');
  }
  return parsed;
}

DateTime? _optionalDateTime(Object? value, String name) {
  if (value == null) {
    return null;
  }
  final DateTime? parsed = _parseDateTime(value);
  if (parsed == null) {
    throw FormatException('Expected nullable $name timestamp.');
  }
  return parsed;
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

WatchStatus _watchStatus(String value) {
  return switch (value) {
    'active' => WatchStatus.active,
    'paused' => WatchStatus.paused,
    'paused_insufficient_credit' => WatchStatus.pausedInsufficientCredit,
    'paused_error' => WatchStatus.pausedError,
    'disabled' => WatchStatus.disabled,
    _ => throw FormatException('Unsupported Watch status: $value'),
  };
}

AutoRecordState _autoRecordState(String? value, {required bool autoRecord}) {
  if (value == null) {
    return autoRecord ? AutoRecordState.active : AutoRecordState.off;
  }
  return switch (value) {
    'off' => AutoRecordState.off,
    'active' => AutoRecordState.active,
    'paused_no_cloud_minutes' => AutoRecordState.pausedNoCloudMinutes,
    'waiting_for_cloud_slot' => AutoRecordState.waitingForCloudSlot,
    _ => throw FormatException('Unsupported auto_record_state: $value'),
  };
}

WatchLiveStatus _liveStatus(String value) {
  return switch (value) {
    'unknown' => WatchLiveStatus.unknown,
    'offline' => WatchLiveStatus.offline,
    'live' => WatchLiveStatus.live,
    _ => throw FormatException('Unsupported Watch live_status: $value'),
  };
}

WatchSourceType _sourceType(String value) {
  return switch (value) {
    'username' => WatchSourceType.username,
    'room_id' => WatchSourceType.roomId,
    'url' => WatchSourceType.url,
    _ => throw FormatException('Unsupported Watch source type: $value'),
  };
}

String _fallbackUsername(WatchSourceType type, String value) {
  if (type == WatchSourceType.url) {
    final Uri? uri = Uri.tryParse(value);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last.replaceFirst('@', '');
    }
  }
  return value.replaceFirst('@', '');
}

String _displayUsername(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return '@unknown';
  }
  return normalized.startsWith('@') ? normalized : '@$normalized';
}

String _fallbackDisplayName(String username) {
  final String normalized = username.replaceFirst('@', '').trim();
  return normalized.isEmpty ? 'TikTok creator' : normalized;
}
