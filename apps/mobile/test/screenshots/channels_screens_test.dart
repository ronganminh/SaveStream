// Channels v2 screens at 390×844, one test per artboard. See
// screenshot_harness.dart for writing the PNGs.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/router/app_routes.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/api/api_error.dart';
import 'package:savestream_mobile/core/api/api_exception.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/channels/domain/models/channel_verification.dart';
import 'package:savestream_mobile/features/channels/domain/models/watch_summary.dart';
import 'package:savestream_mobile/features/channels/domain/repositories/watch_repository.dart';
import 'package:savestream_mobile/features/credits/domain/credit_balance.dart';
import 'package:savestream_mobile/features/credits/presentation/credits_providers.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/entitlement/domain/repositories/entitlement_repository.dart';
import 'package:savestream_mobile/features/entitlement/presentation/entitlement_providers.dart';
import 'package:savestream_mobile/features/home/presentation/controllers/home_dashboard_controller.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/recordings/domain/repositories/recording_repository.dart';
import 'package:savestream_mobile/features/settings/domain/models/app_notification.dart';
import 'package:savestream_mobile/features/settings/domain/models/user_profile.dart';
import 'package:savestream_mobile/features/settings/domain/repositories/notifications_repository.dart';
import 'package:savestream_mobile/features/settings/domain/repositories/profile_repository.dart';

import 'screenshot_harness.dart';

final DateTime _now = DateTime(2026, 10, 22, 20, 43, 18);
const String _code = 'SS-7K4Q';

AppConfig _config() => AppConfig(
  environment: AppEnvironment.local,
  apiBaseUrl: Uri.parse('http://localhost:8000'),
);

void main() {
  setUpAll(loadBundledFonts);

  Future<_FakeWatches> pumpChannels(
    WidgetTester tester, {
    required _FakeWatches watches,
    List<RecordingSummary> recordings = const <RecordingSummary>[],
    int minutes = 760,
    String? location,
  }) async {
    usePhoneView(tester);
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
          watchRepository: watches,
          recordingRepository: _FakeRecordings(recordings),
          profileRepository: _FakeProfile(),
          notificationsRepository: _FakeNotifications(),
          extraOverrides: <Override>[
            entitlementRepositoryProvider.overrideWithValue(
              _FakeEntitlement(_entitlement(minutes)),
            ),
            creditsRepositoryProvider.overrideWithValue(_FakeCredits(minutes)),
            homeClockProvider.overrideWithValue(() => _now),
          ],
        ),
      ),
    );
    await settle(tester);
    _router(tester).go(location ?? AppRoutes.channels);
    await settle(tester);
    return watches;
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final Finder button = find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is ButtonStyleButton,
          ),
        )
        .last;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> openSheet(WidgetTester tester, String username) async {
    await tester.tap(find.byKey(const ValueKey<String>('channels-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('add-channel-username')),
      username,
    );
    await tester.pump();
  }

  testWidgets('AChannels', (WidgetTester tester) async {
    await pumpChannels(
      tester,
      watches: _FakeWatches(_listWatches()),
      recordings: <RecordingSummary>[_liveRecording()],
    );
    expect(find.text('@my_shop_live'), findsOneWidget);
    expect(find.text('Recording · 0:42:18'), findsOneWidget);
    expect(find.text('Auto-record on · last LIVE Oct 20'), findsOneWidget);
    expect(find.text('Add SS-7K4Q to your bio to finish'), findsOneWidget);
    expect(find.text('Unverified'), findsOneWidget);
    expect(find.text('Add channel'), findsOneWidget);
    await captureScreen(tester, 'AChannels');
  });

  testWidgets('AChannelsEmpty', (WidgetTester tester) async {
    await pumpChannels(tester, watches: _FakeWatches(<WatchSummary>[]));
    expect(find.text('No channels yet'), findsOneWidget);
    await captureScreen(tester, 'AChannelsEmpty');
  });

  testWidgets('AChannelsError', (WidgetTester tester) async {
    await pumpChannels(
      tester,
      watches: _FakeWatches(<WatchSummary>[], listFails: true),
    );
    expect(find.text('Couldn’t load your channels'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await captureScreen(tester, 'AChannelsError');
  });

  testWidgets('AAddSheet', (WidgetTester tester) async {
    await pumpChannels(
      tester,
      watches: _FakeWatches(_listWatches()),
      recordings: <RecordingSummary>[_liveRecording()],
    );
    await openSheet(tester, 'my_shop_live');
    await settleForCapture(tester);
    expect(find.text('Add a channel'), findsOneWidget);
    expect(find.text('Find channel'), findsOneWidget);
    await captureScreen(tester, 'AAddSheet');
  });

  testWidgets('AAddFound', (WidgetTester tester) async {
    final _FakeWatches watches = await pumpChannels(
      tester,
      watches: _FakeWatches(_listWatches()),
      recordings: <RecordingSummary>[_liveRecording()],
    );
    await openSheet(tester, 'my_shop_live');
    await tapButton(tester, 'Find channel');
    await tester.pumpAndSettle();
    expect(find.text('Is this your channel?'), findsOneWidget);
    expect(find.text('My Shop Live'), findsOneWidget);

    // Confirming without the ownership box shows the inline error.
    await tapButton(tester, 'Yes, verify ownership');
    expect(
      find.text('Confirm you own or manage this account to continue.'),
      findsOneWidget,
    );
    expect(watches.created, isEmpty);

    await tester.tap(find.byKey(const ValueKey<String>('add-channel-owner')));
    await settleForCapture(tester);
    expect(
      find.text('Confirm you own or manage this account to continue.'),
      findsNothing,
    );
    await captureScreen(tester, 'AAddFound');

    await tapButton(tester, 'Yes, verify ownership');
    await settle(tester);
    expect(watches.created.single.ownerAttested, isTrue);
    expect(watches.created.single.autoRecord, isFalse);
    expect(find.text('Verify ownership'), findsOneWidget);
  });

  testWidgets('AAddNotFound', (WidgetTester tester) async {
    await pumpChannels(
      tester,
      watches: _FakeWatches(_listWatches(), lookupFails: true),
      recordings: <RecordingSummary>[_liveRecording()],
    );
    await openSheet(tester, 'my_shop_livee');
    await tapButton(tester, 'Find channel');
    await tester.pumpAndSettle();
    await settleForCapture(tester);
    expect(
      find.text('We couldn’t find a public profile with this username.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    await captureScreen(tester, 'AAddNotFound');
  });

  Future<_FakeWatches> pumpVerify(
    WidgetTester tester,
    _FakeWatches watches,
  ) async {
    await pumpChannels(
      tester,
      watches: watches,
      location: AppRoutes.channelVerify('w-shop'),
    );
    expect(find.text(_code), findsOneWidget);
    return watches;
  }

  testWidgets('AVerifyCode', (WidgetTester tester) async {
    await pumpVerify(tester, _FakeWatches(<WatchSummary>[_shop()]));
    expect(find.text('Expires in 30 min'), findsOneWidget);
    expect(find.text('Check my bio'), findsOneWidget);
    await captureScreen(tester, 'AVerifyCode');
  });

  testWidgets('AVerifyChecking', (WidgetTester tester) async {
    final _FakeWatches watches = await pumpVerify(
      tester,
      _FakeWatches(<WatchSummary>[_shop()], checkHangs: true),
    );
    await tapButton(tester, 'Check my bio');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Checking…'), findsOneWidget);
    expect(watches.checks, 1);
    await captureScreen(tester, 'AVerifyChecking');
  });

  testWidgets('AVerifyNotYet', (WidgetTester tester) async {
    await pumpVerify(
      tester,
      _FakeWatches(<WatchSummary>[
        _shop(),
      ], checkResult: VerificationCheckResult.codeNotFound),
    );
    await tapButton(tester, 'Check my bio');
    await settle(tester);
    expect(
      find.text('We didn’t find SS-7K4Q in your bio yet.'),
      findsOneWidget,
    );
    expect(find.text('Check again'), findsOneWidget);
    await captureScreen(tester, 'AVerifyNotYet');
  });

  testWidgets('AVerifyExpired', (WidgetTester tester) async {
    final _FakeWatches watches = await pumpVerify(
      tester,
      _FakeWatches(<WatchSummary>[_shop()], checkExpired: true),
    );
    await tapButton(tester, 'Check my bio');
    await settle(tester);
    expect(find.text('This code has expired.'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
    await captureScreen(tester, 'AVerifyExpired');

    // Get a new code asks the server again.
    await tapButton(tester, 'Get a new code');
    await settle(tester);
    expect(watches.starts, 2);
  });

  testWidgets('AVerifyDone', (WidgetTester tester) async {
    final _FakeWatches watches = await pumpVerify(
      tester,
      _FakeWatches(<WatchSummary>[
        _shop(),
      ], checkResult: VerificationCheckResult.verified),
    );
    await tapButton(tester, 'Check my bio');
    await settle(tester);
    expect(find.text('@my_shop_live is verified'), findsOneWidget);
    expect(watches.byId('w-shop').autoRecord, isTrue);
    expect(watches.byId('w-shop').notifyOnLive, isTrue);
    await captureScreen(tester, 'AVerifyDone');
  });

  final List<RecordingSummary> history = <RecordingSummary>[
    for (int i = 0; i < 11; i++)
      _recording('r$i', DateTime(2026, 10, 10 + i, 19), 5700),
  ];

  testWidgets('AChannelRecording', (WidgetTester tester) async {
    await pumpChannels(
      tester,
      watches: _FakeWatches(<WatchSummary>[
        _shop(verified: true, live: true, activeRecordingId: 'r-live'),
      ]),
      recordings: <RecordingSummary>[_liveRecording(), ...history],
      location: AppRoutes.channelDetail('w-shop'),
    );
    expect(find.text('● LIVE · Recording'), findsOneWidget);
    expect(find.text('Owner verified'), findsOneWidget);
    expect(find.text('0:42:18'), findsOneWidget);
    expect(find.text('43 minutes used · 12 h 40 min left'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('18 h'), findsOneWidget);
    expect(find.text('Oct 21'), findsOneWidget);
    await captureScreen(tester, 'AChannelRecording');
  });

  testWidgets('AChannelWaiting', (WidgetTester tester) async {
    await pumpChannels(
      tester,
      watches: _FakeWatches(<WatchSummary>[_shop(verified: true)]),
      recordings: <RecordingSummary>[
        ...history,
        _recording('r-last', DateTime(2026, 10, 21, 19), 3000),
      ],
      location: AppRoutes.channelDetail('w-shop'),
    );
    expect(find.text('Waiting for LIVE'), findsOneWidget);
    expect(find.text('Waiting for the next LIVE'), findsOneWidget);
    await captureScreen(tester, 'AChannelWaiting');
  });

  testWidgets('AChannelPaused', (WidgetTester tester) async {
    await pumpChannels(
      tester,
      watches: _FakeWatches(<WatchSummary>[
        _shop(
          verified: true,
          live: true,
          status: WatchStatus.pausedInsufficientCredit,
          autoRecordState: AutoRecordState.pausedNoCloudMinutes,
        ),
      ]),
      recordings: <RecordingSummary>[
        ...history,
        _recording('r-last', DateTime(2026, 10, 21, 19), 3000),
      ],
      minutes: 0,
      location: AppRoutes.channelDetail('w-shop'),
    );
    expect(find.text('LIVE · not recording'), findsOneWidget);
    expect(
      find.text('@my_shop_live is LIVE but we’re not recording.'),
      findsOneWidget,
    );
    expect(find.text('Buy minutes'), findsOneWidget);
    await captureScreen(tester, 'AChannelPaused');
  });

  testWidgets('AChannelUnverified', (WidgetTester tester) async {
    final _FakeWatches watches = _FakeWatches(<WatchSummary>[_shop()])
      ..pendingCode = true;
    await pumpChannels(
      tester,
      watches: watches,
      location: AppRoutes.channelDetail('w-shop'),
    );
    expect(find.text('Finish verifying to start recording.'), findsOneWidget);
    expect(
      find.text(
        'Add SS-7K4Q to your TikTok bio, then check again. We don’t record '
        'unverified channels.',
      ),
      findsOneWidget,
    );
    expect(find.text('Available after verification'), findsOneWidget);
    await captureScreen(tester, 'AChannelUnverified');
  });

  testWidgets('AChannelRemove', (WidgetTester tester) async {
    final _FakeWatches watches = await pumpChannels(
      tester,
      watches: _FakeWatches(<WatchSummary>[_shop(verified: true)]),
      recordings: history,
      location: AppRoutes.channelDetail('w-shop'),
    );
    await tapButton(tester, 'Remove channel');
    await tester.pumpAndSettle();
    expect(find.text('Remove @my_shop_live?'), findsOneWidget);
    await captureScreen(tester, 'AChannelRemove');

    await tester.tap(
      find.byKey(const ValueKey<String>('channel-remove-confirm')),
    );
    await settle(tester);
    expect(watches.deleted, <String>['w-shop']);
    expect(find.text('No channels yet'), findsOneWidget);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) {
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

Entitlement _entitlement(int minutes) {
  return Entitlement(
    plan: Plan.pro,
    hasPurchased: true,
    emailVerified: true,
    trialRecording: false,
    canAutoRecord: minutes > 0,
    cloudMinutesAvailable: minutes,
    limits: const EntitlementLimits(
      maxWatches: 5,
      maxConcurrentCloudRecordings: 1,
      cloudRetentionDays: 30,
    ),
    watchCount: 3,
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

WatchSummary _shop({
  bool verified = false,
  bool live = false,
  String? activeRecordingId,
  WatchStatus status = WatchStatus.active,
  AutoRecordState autoRecordState = AutoRecordState.active,
}) {
  return WatchSummary(
    id: 'w-shop',
    creatorDisplayName: 'My Shop Live',
    creatorUsername: 'my_shop_live',
    status: status,
    isLive: live,
    autoRecord: verified,
    notifyOnLive: verified,
    autoRecordState: verified ? autoRecordState : AutoRecordState.off,
    activeRecordingId: activeRecordingId,
    lastLiveAt: DateTime(2026, 10, 21, 19),
    ownerVerifiedAt: verified ? DateTime.utc(2026, 10, 1) : null,
    verificationRequired: !verified,
    verificationDueAt: verified ? null : DateTime.utc(2026, 10, 22, 13),
  );
}

List<WatchSummary> _listWatches() {
  return <WatchSummary>[
    _shop(verified: true, live: true, activeRecordingId: 'r-live'),
    WatchSummary(
      id: 'w-gaming',
      creatorDisplayName: 'My Gaming Stream',
      creatorUsername: 'my_gaming_stream',
      status: WatchStatus.active,
      isLive: false,
      autoRecord: true,
      autoRecordState: AutoRecordState.active,
      lastLiveAt: DateTime(2026, 10, 20, 21),
      ownerVerifiedAt: DateTime.utc(2026, 10, 1),
    ),
    WatchSummary(
      id: 'w-cooking',
      creatorDisplayName: 'My Cooking Corner',
      creatorUsername: 'my_cooking_corner',
      status: WatchStatus.active,
      isLive: false,
      autoRecord: false,
      notifyOnLive: false,
      verificationRequired: true,
      verificationDueAt: DateTime.utc(2026, 10, 22, 12),
    ),
  ];
}

RecordingSummary _liveRecording() {
  return RecordingSummary(
    id: 'r-live',
    watchId: 'w-shop',
    creatorDisplayName: 'My Shop Live',
    creatorUsername: 'my_shop_live',
    status: RecordingStatus.recording,
    actions: const RecordingActions(
      canStop: true,
      canRetry: false,
      canDelete: false,
    ),
    startedAt: DateTime(2026, 10, 22, 20, 1),
    durationSeconds: 2538,
  );
}

RecordingSummary _recording(String id, DateTime started, int seconds) {
  return RecordingSummary(
    id: id,
    watchId: 'w-shop',
    creatorDisplayName: 'My Shop Live',
    creatorUsername: 'my_shop_live',
    status: RecordingStatus.completed,
    actions: const RecordingActions(
      canStop: false,
      canRetry: false,
      canDelete: true,
    ),
    startedAt: started,
    durationSeconds: seconds,
    artifactReady: true,
  );
}

class _FakeWatches
    implements
        WatchRepository,
        CreatorLookupRepository,
        ChannelVerificationRepository {
  _FakeWatches(
    List<WatchSummary> items, {
    this.listFails = false,
    this.lookupFails = false,
    this.checkHangs = false,
    this.checkExpired = false,
    this.checkResult = VerificationCheckResult.codeNotFound,
  }) : _items = List<WatchSummary>.of(items);

  final List<WatchSummary> _items;
  final bool listFails;
  final bool lookupFails;
  final bool checkHangs;
  final bool checkExpired;
  final VerificationCheckResult checkResult;

  /// The unverified channels in the list already have a code pending.
  bool pendingCode = true;
  final List<CreateWatchCommand> created = <CreateWatchCommand>[];
  final List<String> deleted = <String>[];
  int starts = 0;
  int checks = 0;

  WatchSummary byId(String id) => _items.firstWhere((w) => w.id == id);

  DateTime get _expiresAt => _now.toUtc().add(const Duration(minutes: 30));

  ChannelVerification _state(String id, {VerificationCheckResult? result}) {
    final WatchSummary? watch = _items.where((w) => w.id == id).firstOrNull;
    final bool verified = watch?.ownerVerifiedAt != null;
    return ChannelVerification(
      watchId: id,
      verified: verified,
      ownerVerifiedAt: watch?.ownerVerifiedAt,
      verificationRequired: !verified,
      code: verified || !pendingCode ? null : _code,
      expiresAt: verified || !pendingCode ? null : _expiresAt,
      checksLeft: verified ? 0 : 19,
      result: result,
    );
  }

  void _replace(String id, WatchSummary Function(WatchSummary) update) {
    final int index = _items.indexWhere((w) => w.id == id);
    if (index >= 0) _items[index] = update(_items[index]);
  }

  @override
  Future<List<WatchSummary>> listWatches() async {
    if (listFails) {
      throw const ApiException(kind: ApiExceptionKind.network, retryable: true);
    }
    return List<WatchSummary>.of(_items);
  }

  @override
  Future<WatchSummary?> getWatch(String id) async =>
      _items.where((w) => w.id == id).firstOrNull;

  @override
  Future<CreatorLookupResult> lookupCreator(CreateWatchCommand command) async {
    if (lookupFails) {
      throw const ApiException(
        kind: ApiExceptionKind.server,
        statusCode: 503,
        retryable: true,
        apiError: ApiError(
          code: 'STREAM_UNAVAILABLE',
          message: 'Unable to resolve live status',
          retryable: true,
          details: <String, Object?>{},
        ),
      );
    }
    return CreatorLookupResult(
      username: command.sourceValue,
      displayName: 'My Shop Live',
      liveStatus: CreatorLiveStatus.offline,
    );
  }

  @override
  Future<WatchSummary> createWatch(CreateWatchCommand command) async {
    created.add(command);
    final WatchSummary watch = WatchSummary(
      id: 'w-new',
      creatorDisplayName: 'My Shop Live',
      creatorUsername: command.sourceValue,
      status: WatchStatus.active,
      isLive: false,
      autoRecord: command.autoRecord,
      notifyOnLive: command.notifyOnLive,
    );
    _items.insert(0, watch);
    return watch;
  }

  @override
  Future<WatchSummary?> setAutoRecord(
    String id, {
    required bool enabled,
  }) async {
    _replace(id, (w) => w.copyWith(autoRecord: enabled));
    return byId(id);
  }

  @override
  Future<WatchSummary?> setNotifyOnLive(
    String id, {
    required bool enabled,
  }) async {
    _replace(id, (w) => w.copyWith(notifyOnLive: enabled));
    return byId(id);
  }

  @override
  Future<WatchSummary?> pauseWatch(String id) async {
    _replace(id, (w) => w.copyWith(status: WatchStatus.paused));
    return byId(id);
  }

  @override
  Future<WatchSummary?> resumeWatch(String id) async {
    _replace(id, (w) => w.copyWith(status: WatchStatus.active));
    return byId(id);
  }

  @override
  Future<void> deleteWatch(String id) async {
    deleted.add(id);
    _items.removeWhere((w) => w.id == id);
  }

  @override
  Future<ChannelVerification> getVerification(String watchId) async =>
      _state(watchId);

  @override
  Future<ChannelVerification> startVerification(String watchId) async {
    starts += 1;
    pendingCode = true;
    return _state(watchId);
  }

  @override
  Future<ChannelVerification> checkVerification(String watchId) async {
    checks += 1;
    if (checkHangs) return Completer<ChannelVerification>().future;
    if (checkExpired) {
      throw const ApiException(
        kind: ApiExceptionKind.conflict,
        statusCode: 409,
        retryable: false,
        apiError: ApiError(
          code: 'VERIFICATION_EXPIRED',
          message: 'This code has expired.',
          retryable: false,
          details: <String, Object?>{},
        ),
      );
    }
    if (checkResult == VerificationCheckResult.verified) {
      _replace(watchId, (w) => w.copyWith(ownerVerifiedAt: _now.toUtc()));
      return _state(watchId, result: VerificationCheckResult.verified);
    }
    return _state(watchId, result: checkResult);
  }
}

class _FakeRecordings implements RecordingRepository {
  _FakeRecordings(this.items);

  final List<RecordingSummary> items;

  @override
  Future<List<RecordingSummary>> listRecordings() async => items;

  @override
  Future<RecordingPage> listRecordingPage({
    RecordingFilter filter = RecordingFilter.all,
    String? cursor,
    int limit = 4,
  }) async => RecordingPage(items: items, nextCursor: null);

  @override
  Stream<RecordingSummary?> watchRecording(String id) =>
      const Stream<RecordingSummary?>.empty();

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
  const _FakeCredits(this.minutes);

  final int minutes;

  @override
  Future<CreditBalance> getBalance() async =>
      CreditBalance(posted: minutes, reserved: 0, available: minutes);
}

class _FakeProfile implements ProfileRepository {
  @override
  Future<UserProfile> getProfile() async => const UserProfile(
    email: 'alex.morgan@example.com',
    emailVerified: true,
    displayName: 'Alex Morgan',
  );

  @override
  Future<UserProfile> updateDisplayName(String? displayName) =>
      throw UnimplementedError();
}

class _FakeNotifications implements NotificationsRepository {
  @override
  Future<NotificationPage> listNotifications({String? cursor}) async {
    return const NotificationPage(items: <AppNotification>[]);
  }

  @override
  Future<int> markAllRead() async => 0;

  @override
  Future<AppNotification> markRead(String notificationId) =>
      throw UnimplementedError();
}
