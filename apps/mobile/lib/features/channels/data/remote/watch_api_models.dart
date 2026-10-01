import '../../domain/models/watch_summary.dart';

enum WatchLiveStatus {
  unknown('unknown'),
  offline('offline'),
  live('live');

  const WatchLiveStatus(this.apiValue);

  final String apiValue;
}

final class WatchApiModel {
  const WatchApiModel({
    required this.id,
    required this.sourceType,
    required this.sourceValue,
    required this.creatorDisplayName,
    required this.creatorUsername,
    required this.status,
    required this.liveStatus,
    required this.autoRecord,
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
  final WatchStatus status;
  final WatchLiveStatus liveStatus;
  final bool autoRecord;
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
    final String sourceValue = _requiredString(
      source['value'],
      'source.value',
    );

    final Object? rawCreator = map['creator'];
    String? creatorUsername;
    String? creatorDisplayName;
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

    final String fallbackUsername = _fallbackUsername(
      sourceType,
      sourceValue,
    );
    final String normalizedUsername = _displayUsername(
      creatorUsername ?? fallbackUsername,
    );
    final String normalizedDisplayName =
        (creatorDisplayName?.trim().isNotEmpty ?? false)
        ? creatorDisplayName!.trim()
        : _fallbackDisplayName(normalizedUsername);

    return WatchApiModel(
      id: _requiredString(map['id'], 'id'),
      sourceType: sourceType,
      sourceValue: sourceValue,
      creatorDisplayName: normalizedDisplayName,
      creatorUsername: normalizedUsername,
      status: _watchStatus(_requiredString(map['status'], 'status')),
      liveStatus: _liveStatus(
        _requiredString(map['live_status'], 'live_status'),
      ),
      autoRecord: _requiredBool(map['auto_record'], 'auto_record'),
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
      status: status,
      isLive: liveStatus == WatchLiveStatus.live,
      autoRecord: autoRecord,
      lastCheckedAt: lastCheckedAt,
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
