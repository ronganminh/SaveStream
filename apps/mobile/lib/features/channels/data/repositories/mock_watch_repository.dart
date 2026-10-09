import '../../../../core/api/api_exception.dart';
import '../../../../core/mock/mock_repository_base.dart';
import '../../../../core/mock/mock_scenario.dart';
import '../../domain/models/watch_summary.dart';
import '../../domain/repositories/watch_repository.dart';

final class MockWatchRepository extends MockRepositoryBase
    implements WatchRepository, CreatorLookupRepository {
  MockWatchRepository(super.behavior) : _items = List<WatchSummary>.of(_seed);

  static final List<WatchSummary> _seed = <WatchSummary>[
    WatchSummary(
      id: 'watch_001',
      creatorDisplayName: 'Ada Live',
      creatorUsername: '@ada_live',
      status: WatchStatus.active,
      isLive: true,
      autoRecord: true,
      lastCheckedAt: DateTime.utc(2026, 9, 30, 14, 20),
      lastLiveAt: DateTime.utc(2026, 9, 30, 14, 18),
    ),
    WatchSummary(
      id: 'watch_004',
      creatorDisplayName: 'Nora Shop',
      creatorUsername: '@nora_shop',
      status: WatchStatus.active,
      isLive: false,
      autoRecord: true,
      lastCheckedAt: DateTime.utc(2026, 9, 30, 14, 15),
      nextCheckAt: DateTime.utc(2026, 9, 30, 14, 45),
      lastLiveAt: DateTime.utc(2026, 9, 28, 10, 30),
    ),
    WatchSummary(
      id: 'watch_002',
      creatorDisplayName: 'Minh Streams',
      creatorUsername: '@minh_streams',
      status: WatchStatus.pausedInsufficientCredit,
      isLive: false,
      autoRecord: true,
      lastCheckedAt: DateTime.utc(2026, 9, 30, 14, 10),
      lastLiveAt: DateTime.utc(2026, 9, 29, 11, 5),
    ),
    WatchSummary(
      id: 'watch_003',
      creatorDisplayName: 'Studio North',
      creatorUsername: '@studio_north',
      status: WatchStatus.pausedError,
      isLive: false,
      autoRecord: true,
      lastCheckedAt: DateTime.utc(2026, 9, 30, 13, 58),
      lastLiveAt: DateTime.utc(2026, 9, 27, 8, 15),
    ),
    WatchSummary(
      id: 'watch_005',
      creatorDisplayName: 'Leo Daily',
      creatorUsername: '@leo_daily',
      status: WatchStatus.paused,
      isLive: false,
      autoRecord: false,
      lastCheckedAt: DateTime.utc(2026, 9, 30, 12, 45),
      lastLiveAt: DateTime.utc(2026, 9, 26, 16, 40),
    ),
    WatchSummary(
      id: 'watch_006',
      creatorDisplayName: 'Mika Studio',
      creatorUsername: '@mika_studio',
      status: WatchStatus.disabled,
      isLive: false,
      autoRecord: false,
      lastCheckedAt: DateTime.utc(2026, 9, 25, 9),
      lastLiveAt: DateTime.utc(2026, 9, 24, 19, 20),
    ),
    WatchSummary(
      id: 'watch_007',
      creatorDisplayName: 'Queue Creator',
      creatorUsername: '@queue_creator',
      status: WatchStatus.active,
      isLive: true,
      autoRecord: true,
      notifyOnLive: true,
      autoRecordState: AutoRecordState.waitingForCloudSlot,
      lastCheckedAt: DateTime.utc(2026, 9, 30, 14, 29),
      lastLiveAt: DateTime.utc(2026, 9, 30, 14, 29),
    ),
    WatchSummary(
      id: 'watch_008',
      creatorDisplayName: 'Missed Creator',
      creatorUsername: '@missed_creator',
      status: WatchStatus.active,
      isLive: false,
      autoRecord: true,
      notifyOnLive: true,
      lastCheckedAt: DateTime.utc(2026, 9, 30, 14, 28),
      lastLiveAt: DateTime.utc(2026, 9, 30, 14, 20),
    ),
  ];

  final List<WatchSummary> _items;

  @override
  Future<CreatorLookupResult> lookupCreator(CreateWatchCommand command) {
    // Keep the zero-latency mock synchronous enough for the existing widget
    // flows, which pump only one frame after tapping Find creator.
    if (behavior.scenario == MockScenario.success) {
      final String username = _usernameFromSource(command.sourceValue);
      if (username.toLowerCase().contains('notfound') ||
          username.toLowerCase().contains('missing')) {
        return Future<CreatorLookupResult>.error(
          const ApiException(
            kind: ApiExceptionKind.api,
            statusCode: 404,
            retryable: false,
          ),
        );
      }
      return Future<CreatorLookupResult>.value(_lookupResult(username));
    }
    return respond<CreatorLookupResult>(
      success: () {
        final String username = _usernameFromSource(command.sourceValue);
        if (username.toLowerCase().contains('notfound') ||
            username.toLowerCase().contains('missing')) {
          throw const ApiException(
            kind: ApiExceptionKind.api,
            statusCode: 404,
            retryable: false,
          );
        }
        return _lookupResult(username);
      },
      empty: () => CreatorLookupResult(
        username: _usernameFromSource(command.sourceValue),
        displayName: _displayNameFromUsername(
          _usernameFromSource(command.sourceValue),
        ),
        liveStatus: CreatorLiveStatus.unknown,
      ),
    );
  }

  CreatorLookupResult _lookupResult(String username) {
    return CreatorLookupResult(
      username: username,
      displayName: _displayNameFromUsername(username),
      liveStatus: username == 'ada_live'
          ? CreatorLiveStatus.live
          : CreatorLiveStatus.offline,
      avatarUrl: null,
      checkedAt: DateTime.utc(2026, 9, 30, 14, 30),
    );
  }

  @override
  Future<List<WatchSummary>> listWatches() {
    return respond<List<WatchSummary>>(
      success: () => List<WatchSummary>.unmodifiable(_items),
      empty: () => const <WatchSummary>[],
    );
  }

  @override
  Future<WatchSummary?> getWatch(String id) {
    return respond<WatchSummary?>(success: () => _find(id), empty: () => null);
  }

  @override
  Future<WatchSummary> createWatch(CreateWatchCommand command) {
    return respond<WatchSummary>(
      success: () => _create(command),
      empty: () => _create(command),
    );
  }

  @override
  Future<WatchSummary?> setAutoRecord(String id, {required bool enabled}) {
    return respond<WatchSummary?>(
      success: () => _update(
        id,
        (WatchSummary current) => current.copyWith(autoRecord: enabled),
      ),
      empty: () => null,
    );
  }

  @override
  Future<WatchSummary?> setNotifyOnLive(String id, {required bool enabled}) {
    return respond<WatchSummary?>(
      success: () => _update(
        id,
        (WatchSummary current) => current.copyWith(notifyOnLive: enabled),
      ),
      empty: () => null,
    );
  }

  @override
  Future<WatchSummary?> pauseWatch(String id) {
    return respond<WatchSummary?>(
      success: () => _update(
        id,
        (WatchSummary current) => current.copyWith(status: WatchStatus.paused),
      ),
      empty: () => null,
    );
  }

  @override
  Future<WatchSummary?> resumeWatch(String id) {
    return respond<WatchSummary?>(
      success: () => _update(
        id,
        (WatchSummary current) => current.copyWith(status: WatchStatus.active),
      ),
      empty: () => null,
    );
  }

  @override
  Future<void> deleteWatch(String id) {
    return respond<void>(
      success: () {
        _items.removeWhere((WatchSummary item) => item.id == id);
      },
      empty: () {},
    );
  }

  WatchSummary? _find(String id) {
    for (final WatchSummary watch in _items) {
      if (watch.id == id) {
        return watch;
      }
    }
    return null;
  }

  WatchSummary? _update(
    String id,
    WatchSummary Function(WatchSummary current) update,
  ) {
    final int index = _items.indexWhere((WatchSummary item) => item.id == id);
    if (index < 0) {
      return null;
    }
    final WatchSummary updated = update(_items[index]);
    _items[index] = updated;
    return updated;
  }

  WatchSummary _create(CreateWatchCommand command) {
    final String username = _usernameFromSource(command.sourceValue);
    final String displayName = _displayNameFromUsername(username);
    final WatchSummary created = WatchSummary(
      id: 'watch_' + (_items.length + 1).toString().padLeft(3, '0'),
      creatorDisplayName: displayName,
      creatorUsername: '@' + username,
      status: WatchStatus.active,
      isLive: false,
      autoRecord: command.autoRecord,
      notifyOnLive: command.notifyOnLive,
      lastCheckedAt: DateTime.utc(2026, 9, 30, 14, 30),
    );
    _items.insert(0, created);
    return created;
  }

  String _usernameFromSource(String source) {
    final String trimmed = source.trim();
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last.replaceFirst('@', '');
    }
    return trimmed.replaceFirst('@', '');
  }

  String _displayNameFromUsername(String username) {
    if (username.isEmpty) {
      return 'TikTok creator';
    }
    return username
        .split(RegExp(r'[_\-.]+'))
        .where((String part) => part.isNotEmpty)
        .map(
          (String part) =>
              part.substring(0, 1).toUpperCase() + part.substring(1),
        )
        .join(' ');
  }
}
