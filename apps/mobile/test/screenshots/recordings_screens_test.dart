// Recordings + Player v2 screens at 390×844 (ARecordings at 390×1180, the
// whole scrolled list), one test per artboard. See screenshot_harness.dart
// for writing the PNGs. Video playback is never started: the player shows
// its poster until Play is tapped.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/router/app_routes.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/api/api_exception.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/channels/domain/models/watch_summary.dart';
import 'package:savestream_mobile/features/channels/domain/repositories/watch_repository.dart';
import 'package:savestream_mobile/features/credits/domain/credit_balance.dart';
import 'package:savestream_mobile/features/credits/presentation/credits_providers.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/entitlement/domain/repositories/entitlement_repository.dart';
import 'package:savestream_mobile/features/entitlement/presentation/entitlement_providers.dart';
import 'package:savestream_mobile/features/home/presentation/controllers/home_dashboard_controller.dart';
import 'package:savestream_mobile/features/recordings/data/cloud_artifact_downloader.dart';
import 'package:savestream_mobile/features/recordings/data/cloud_recording_file_service.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/recordings/domain/repositories/recording_repository.dart';
import 'package:savestream_mobile/features/recordings/presentation/controllers/recording_file_providers.dart';
import 'package:savestream_mobile/features/settings/domain/models/app_notification.dart';
import 'package:savestream_mobile/features/settings/domain/models/user_profile.dart';
import 'package:savestream_mobile/features/settings/domain/repositories/notifications_repository.dart';
import 'package:savestream_mobile/features/settings/domain/repositories/profile_repository.dart';

import 'screenshot_harness.dart';

final DateTime _now = DateTime(2026, 10, 22, 20, 43, 18);
const int _gb = 1024 * 1024 * 1024;

AppConfig _config() => AppConfig(
  environment: AppEnvironment.local,
  apiBaseUrl: Uri.parse('http://localhost:8000'),
);

void main() {
  setUpAll(loadBundledFonts);

  Future<_FakeRecordings> pumpRecordings(
    WidgetTester tester, {
    required _FakeRecordings recordings,
    _FakeFileStore? files,
    String? location,
    Size size = artboardSize,
  }) async {
    usePhoneView(tester, size: size);
    final AppSessionController session = AppSessionController();
    final AppSettingsController settings = AppSettingsController();
    addTearDown(session.dispose);
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      screenshotFrame(
        SaveStreamApp(
          config: _config(),
          session: session,
          settings: settings,
          watchRepository: _FakeWatches(),
          recordingRepository: recordings,
          profileRepository: _FakeProfile(),
          notificationsRepository: _FakeNotifications(),
          extraOverrides: <Override>[
            entitlementRepositoryProvider.overrideWithValue(
              _FakeEntitlement(_entitlement()),
            ),
            creditsRepositoryProvider.overrideWithValue(const _FakeCredits()),
            homeClockProvider.overrideWithValue(() => _now),
            cloudRecordingFileServiceProvider.overrideWithValue(
              files ?? _FakeFileStore(),
            ),
          ],
        ),
      ),
    );
    await settle(tester);
    _router(tester).go(AppRoutes.recordings);
    await settle(tester);
    if (location != null) {
      _router(tester).push(location);
      await settle(tester);
    }
    return recordings;
  }

  Future<void> selectFilter(WidgetTester tester, String name) async {
    final Finder chip = find.byKey(ValueKey<String>('recordings-filter-$name'));
    // "Expiring soon" sits past the edge; the row scrolls to it.
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    await settle(tester);
  }

  testWidgets('ARecordings', (WidgetTester tester) async {
    await pumpRecordings(
      tester,
      recordings: _FakeRecordings(_library(full: false)),
      size: const Size(390, 1180),
    );
    expect(find.text('@my_shop_live · LIVE now'), findsOneWidget);
    expect(find.text('Recording · 0:42:18'), findsOneWidget);
    expect(find.text('Processing…'), findsOneWidget);
    expect(find.text('1:39:02'), findsOneWidget);
    expect(find.text('58:14'), findsOneWidget);
    expect(find.text('Couldn’t save'), findsOneWidget);
    expect(
      find.text('The source is currently offline · 0 min charged'),
      findsOneWidget,
    );
    expect(find.text('3 days left'), findsOneWidget);
    expect(find.text('1:12:40'), findsOneWidget);
    await captureScreen(tester, 'ARecordings');

    // Search narrows the grid by channel.
    await tester.tap(find.byKey(const ValueKey<String>('recordings-search')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey<String>('recordings-search-field')),
      'gaming',
    );
    await settle(tester);
    expect(find.text('@my_shop_live'), findsNothing);
    expect(find.text('@my_gaming_stream'), findsNWidgets(2));
  });

  testWidgets('ARecordingsEmpty', (WidgetTester tester) async {
    await pumpRecordings(
      tester,
      recordings: _FakeRecordings(<RecordingSummary>[]),
    );
    expect(find.text('No recordings yet'), findsOneWidget);
    expect(find.text('Go to Channels'), findsOneWidget);
    await captureScreen(tester, 'ARecordingsEmpty');
  });

  testWidgets('ARecordingsLoading', (WidgetTester tester) async {
    await pumpRecordings(
      tester,
      recordings: _FakeRecordings(<RecordingSummary>[], listHangs: true),
    );
    expect(find.text('All'), findsOneWidget);
    expect(find.text('No recordings yet'), findsNothing);
    await captureScreen(tester, 'ARecordingsLoading');
  });

  testWidgets('ARecordingsProcessing', (WidgetTester tester) async {
    await pumpRecordings(tester, recordings: _FakeRecordings(_library()));
    await selectFilter(tester, 'processing');
    expect(
      find.text('Usually ready within 10 minutes after the LIVE ends.'),
      findsOneWidget,
    );
    expect(find.text('Processing…'), findsNWidgets(2));
    expect(find.text('@my_shop_live · LIVE now'), findsNothing);
    await captureScreen(tester, 'ARecordingsProcessing');
  });

  testWidgets('ARecordingsFailed', (WidgetTester tester) async {
    await pumpRecordings(tester, recordings: _FakeRecordings(_library()));
    await selectFilter(tester, 'failed');
    expect(find.text('Failed recordings are never charged.'), findsOneWidget);
    expect(find.text('Oct 19, 21:02'), findsOneWidget);
    expect(find.text('Oct 14, 07:02'), findsOneWidget);
    expect(find.text('Retry processing'), findsNothing);
    await captureScreen(tester, 'ARecordingsFailed');
  });

  testWidgets('ARecordingsExpiring', (WidgetTester tester) async {
    await pumpRecordings(tester, recordings: _FakeRecordings(_library()));
    await selectFilter(tester, 'expiring');
    expect(
      find.textContaining('Recordings are deleted automatically'),
      findsOneWidget,
    );
    expect(find.text('3 days left'), findsOneWidget);
    expect(find.text('2 days left'), findsOneWidget);
    expect(find.text('47:05'), findsOneWidget);
    expect(find.text('1:39:02'), findsNothing);
    await captureScreen(tester, 'ARecordingsExpiring');
  });

  testWidgets('APlayer', (WidgetTester tester) async {
    await pumpRecordings(
      tester,
      recordings: _FakeRecordings(_library()),
      location: AppRoutes.recordingDetail('r-weekend'),
    );
    expect(find.text('@my_shop_live'), findsOneWidget);
    expect(find.text('Oct 21, 20:01 · 1:39:02'), findsOneWidget);
    expect(find.text('Save to device'), findsOneWidget);
    expect(find.text('Share link'), findsNothing);
    expect(
      find.text('Kept for 23 more days · then deleted automatically'),
      findsOneWidget,
    );
    expect(
      find.text('1080p · 2.4 GB · recorded on SaveStream servers'),
      findsOneWidget,
    );
    expect(find.text('0:00:00'), findsOneWidget);
    await captureScreen(tester, 'APlayer');
  });

  testWidgets('APlayerSaving', (WidgetTester tester) async {
    final _FakeFileStore files = _FakeFileStore(hang: true);
    await pumpRecordings(
      tester,
      recordings: _FakeRecordings(_library()),
      files: files,
      location: AppRoutes.recordingDetail('r-weekend'),
    );
    await tester.tap(find.byKey(const ValueKey<String>('player-save')));
    await settle(tester);
    expect(find.text('Saving to Downloads…'), findsOneWidget);
    expect(find.text('58%'), findsOneWidget);
    expect(
      find.text('1.4 GB of 2.4 GB · keep the app open until it finishes'),
      findsOneWidget,
    );
    await captureScreen(tester, 'APlayerSaving');

    // Cancel stops the download and closes the panel.
    await tester.tap(find.byKey(const ValueKey<String>('player-save-cancel')));
    files.release();
    await settle(tester);
    expect(files.cancelled, isTrue);
    expect(find.text('Saving to Downloads…'), findsNothing);
    expect(find.text('Save to device'), findsOneWidget);
  });

  testWidgets('APlayerSaved', (WidgetTester tester) async {
    final _FakeFileStore files = _FakeFileStore();
    await pumpRecordings(
      tester,
      recordings: _FakeRecordings(_library()),
      files: files,
      location: AppRoutes.recordingDetail('r-weekend'),
    );
    await tester.tap(find.byKey(const ValueKey<String>('player-save')));
    await settle(tester);
    expect(files.downloads, <String>['art-weekend']);
    expect(find.text('Saved to Downloads'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Play saved copy'), findsOneWidget);
    await captureScreen(tester, 'APlayerSaved');
  });

  testWidgets('APlayerDelete', (WidgetTester tester) async {
    final _FakeRecordings recordings = await pumpRecordings(
      tester,
      recordings: _FakeRecordings(_library()),
      location: AppRoutes.recordingDetail('r-weekend'),
    );
    await tester.tap(find.byKey(const ValueKey<String>('player-more')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey<String>('player-delete')));
    await settle(tester);
    expect(find.text('Delete this recording?'), findsOneWidget);
    expect(
      find.textContaining('Copies you saved to your device aren’t affected.'),
      findsOneWidget,
    );
    await captureScreen(tester, 'APlayerDelete');

    await tester.tap(
      find.byKey(const ValueKey<String>('recording-delete-confirm')),
    );
    await settle(tester);
    expect(recordings.deleted, <String>['r-weekend']);
    expect(find.text('@my_shop_live · LIVE now'), findsOneWidget);
    expect(find.text('1:39:02'), findsNothing);
  });

  testWidgets('APlayerProcessing', (WidgetTester tester) async {
    await pumpRecordings(
      tester,
      recordings: _FakeRecordings(_library()),
      location: AppRoutes.recordingDetail('r-evening'),
    );
    expect(find.text('Processing your recording…'), findsOneWidget);
    expect(find.text('usually under 10 minutes'), findsOneWidget);
    expect(
      find.text(
        'Save to device unlocks when processing finishes. We’ll notify you.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('player-save')), findsNothing);
    await captureScreen(tester, 'APlayerProcessing');
  });

  testWidgets('APlayerFailed', (WidgetTester tester) async {
    await pumpRecordings(
      tester,
      recordings: _FakeRecordings(_library()),
      location: AppRoutes.recordingDetail('r-quick'),
    );
    expect(find.text('This recording couldn’t be saved'), findsOneWidget);
    expect(find.text('@my_gaming_stream'), findsOneWidget);
    expect(find.text('Oct 19, 21:02'), findsOneWidget);
    expect(find.text('The source is currently offline'), findsOneWidget);
    expect(find.text('0 minutes were charged.'), findsOneWidget);
    expect(find.text('Report a problem'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await captureScreen(tester, 'APlayerFailed');
  });
}

Future<void> settle(WidgetTester tester) async {
  // Spinners and the recording timer never settle; pump a fixed time.
  await tester.pump();
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

GoRouter _router(WidgetTester tester) {
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

Entitlement _entitlement() {
  return Entitlement(
    plan: Plan.pro,
    hasPurchased: true,
    emailVerified: true,
    trialRecording: false,
    canAutoRecord: true,
    cloudMinutesAvailable: 760,
    limits: const EntitlementLimits(
      maxWatches: 5,
      maxConcurrentCloudRecordings: 1,
      cloudRetentionDays: 30,
    ),
    watchCount: 2,
    local: LocalEntitlement(
      enabled: false,
      unlimited: false,
      dailyMinutes: 0,
      minutesRemaining: 0,
      resetsAt: DateTime.utc(2026, 10, 23),
      rewardsUsedToday: 0,
      rewardsCapPerDay: 0,
      minutesPerReward: 0,
      extensionsCapPerRecording: 0,
    ),
    updatedAt: DateTime.utc(2026, 10, 22),
  );
}

RecordingSummary _rec(
  String id, {
  required String handle,
  required RecordingStatus status,
  required DateTime? started,
  int seconds = 0,
  String? watchId,
  DateTime? expiresAt,
  bool ready = false,
  String? errorCode,
  String? errorMessage,
}) {
  final bool failed = status == RecordingStatus.failed;
  return RecordingSummary(
    id: id,
    watchId: watchId,
    creatorDisplayName: handle,
    creatorUsername: handle,
    status: status,
    actions: RecordingActions(
      canStop: status == RecordingStatus.recording,
      canRetry: false,
      canDelete: status != RecordingStatus.recording,
    ),
    startedAt: started,
    durationSeconds: seconds,
    artifactReady: ready,
    expiresAt: expiresAt,
    errorCode: failed ? errorCode : null,
    errorMessage: failed ? errorMessage : null,
  );
}

/// The ARecordings artboard, plus (when [full]) the second processing,
/// failed and expiring recordings its filter artboards show.
List<RecordingSummary> _library({bool full = true}) {
  const Set<String> extra = <String>{'r-ranked2', 'r-qa', 'r-morning'};
  return <RecordingSummary>[
    _rec(
      'r-live',
      handle: 'my_shop_live',
      status: RecordingStatus.recording,
      started: DateTime(2026, 10, 22, 20, 1),
      seconds: 2400,
      watchId: 'w-shop',
    ),
    _rec(
      'r-evening',
      handle: 'my_shop_live',
      status: RecordingStatus.processing,
      started: DateTime(2026, 10, 22, 17),
      seconds: 5942,
    ),
    _rec(
      'r-ranked2',
      handle: 'my_gaming_stream',
      status: RecordingStatus.uploading,
      started: DateTime(2026, 10, 21, 18),
      seconds: 3100,
    ),
    _rec(
      'r-weekend',
      handle: 'my_shop_live',
      status: RecordingStatus.completed,
      started: DateTime(2026, 10, 21, 20, 1),
      seconds: 5942,
      ready: true,
      expiresAt: _now.add(const Duration(days: 23)),
    ),
    _rec(
      'r-ranked',
      handle: 'my_gaming_stream',
      status: RecordingStatus.completed,
      started: DateTime(2026, 10, 20, 21),
      seconds: 3494,
      ready: true,
      expiresAt: _now.add(const Duration(days: 22)),
    ),
    _rec(
      'r-quick',
      handle: 'my_gaming_stream',
      status: RecordingStatus.failed,
      started: DateTime(2026, 10, 19, 21, 2),
      errorCode: 'STREAM_OFFLINE',
      errorMessage: 'The source is currently offline',
    ),
    _rec(
      'r-spring',
      handle: 'my_shop_live',
      status: RecordingStatus.completed,
      started: DateTime(2026, 9, 25, 19),
      seconds: 4360,
      ready: true,
      expiresAt: _now.add(const Duration(hours: 60)),
    ),
    _rec(
      'r-qa',
      handle: 'my_shop_live',
      status: RecordingStatus.completed,
      started: DateTime(2026, 9, 24, 19),
      seconds: 2825,
      ready: true,
      expiresAt: _now.add(const Duration(hours: 36)),
    ),
    _rec(
      'r-morning',
      handle: 'my_shop_live',
      status: RecordingStatus.failed,
      started: DateTime(2026, 10, 14, 7, 2),
      errorCode: 'SERVICE_UNAVAILABLE',
      errorMessage: 'Artifact upload failed: storage timed out',
    ),
  ].where((RecordingSummary r) => full || !extra.contains(r.id)).toList();
}

class _FakeRecordings implements RecordingRepository {
  _FakeRecordings(List<RecordingSummary> items, {this.listHangs = false})
    : _items = List<RecordingSummary>.of(items);

  final List<RecordingSummary> _items;
  final bool listHangs;
  final List<String> deleted = <String>[];

  @override
  Future<List<RecordingSummary>> listRecordings() async {
    if (listHangs) return Completer<List<RecordingSummary>>().future;
    return List<RecordingSummary>.of(_items);
  }

  @override
  Future<RecordingPage> listRecordingPage({
    RecordingFilter filter = RecordingFilter.all,
    String? cursor,
    int limit = 4,
  }) async => RecordingPage(items: _items, nextCursor: null);

  @override
  Future<RecordingSummary?> getRecording(String id) async =>
      _items.where((RecordingSummary r) => r.id == id).firstOrNull;

  @override
  Stream<RecordingSummary?> watchRecording(String id) async* {
    yield await getRecording(id);
  }

  @override
  Future<List<RecordingArtifactSummary>> listArtifacts(
    String recordingId,
  ) async {
    final RecordingSummary? recording = await getRecording(recordingId);
    if (recording == null || !recording.artifactReady) {
      return const <RecordingArtifactSummary>[];
    }
    return <RecordingArtifactSummary>[
      RecordingArtifactSummary(
        id: 'art-${recordingId.substring(2)}',
        recordingId: recordingId,
        sizeBytes: (2.4 * _gb).round(),
        checksumSha256: 'sha',
        createdAt: DateTime.utc(2026, 10, 21, 22),
        width: 1080,
        height: 1920,
      ),
    ];
  }

  @override
  Future<void> deleteRecording(String id) async {
    deleted.add(id);
    _items.removeWhere((RecordingSummary r) => r.id == id);
  }

  @override
  Future<RecordingSummary?> stopRecording(String id) async => null;

  @override
  Future<ArtifactDownloadUrl> createArtifactDownloadUrl(String artifactId) =>
      throw const ApiException(kind: ApiExceptionKind.network, retryable: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Saves to Downloads without touching the disk. With [hang] the download stops
/// at 58% until [release].
class _FakeFileStore implements RecordingFileStore {
  _FakeFileStore({this.hang = false});

  final bool hang;
  final List<String> downloads = <String>[];
  final Completer<void> _gate = Completer<void>();
  bool cancelled = false;

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  bool get savesToDownloads => true;

  @override
  Future<SavedRecordingCopy?> existingCopy(
    String recordingId, {
    int? expectedSizeBytes,
  }) async => null;

  @override
  Future<int> existingBytes(String recordingId) async => 0;

  @override
  Future<SavedRecordingCopy> download({
    required String recordingId,
    required String artifactId,
    CloudDownloadProgress? onProgress,
    bool Function()? isCancelled,
  }) async {
    downloads.add(artifactId);
    final int total = (2.4 * _gb).round();
    onProgress?.call(receivedBytes: (1.4 * _gb).round(), totalBytes: total);
    if (hang) {
      await _gate.future;
      if (isCancelled?.call() ?? false) {
        cancelled = true;
        throw const CloudDownloadCancelledException();
      }
    }
    onProgress?.call(receivedBytes: total, totalBytes: total);
    return SavedRecordingCopy(
      location: 'content://media/external/downloads/$recordingId',
      sizeBytes: total,
    );
  }
}

class _FakeWatches implements WatchRepository {
  @override
  Future<List<WatchSummary>> listWatches() async => <WatchSummary>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeEntitlement implements EntitlementRepository {
  const _FakeEntitlement(this.value);

  final Entitlement value;

  @override
  Future<Entitlement> getEntitlement() async => value;
}

class _FakeCredits implements CreditsRepository {
  const _FakeCredits();

  @override
  Future<CreditBalance> getBalance() async =>
      const CreditBalance(posted: 760, reserved: 0, available: 760);
}

class _FakeProfile implements ProfileRepository {
  @override
  Future<UserProfile> getProfile() async => const UserProfile(
    email: 'alex.morgan@example.com',
    emailVerified: true,
    displayName: 'Alex Morgan',
  );
}

class _FakeNotifications implements NotificationsRepository {
  @override
  Future<NotificationPage> listNotifications({String? cursor}) async {
    return const NotificationPage(items: <AppNotification>[]);
  }

  @override
  Future<AppNotification> markRead(String notificationId) =>
      throw UnimplementedError();
}
