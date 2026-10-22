// Notifications v2 screens (inbox and preferences), one test per artboard.
// See screenshot_harness.dart for writing the PNGs.
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
import 'package:savestream_mobile/features/channels/presentation/channel_detail_screen.dart';
import 'package:savestream_mobile/features/home/presentation/controllers/home_dashboard_controller.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/recordings/domain/repositories/recording_repository.dart';
import 'package:savestream_mobile/features/settings/domain/models/app_notification.dart';
import 'package:savestream_mobile/features/settings/domain/models/notification_preferences.dart';
import 'package:savestream_mobile/features/settings/domain/models/user_profile.dart';
import 'package:savestream_mobile/features/settings/domain/repositories/notifications_repository.dart';
import 'package:savestream_mobile/features/settings/domain/repositories/profile_repository.dart';
import 'package:savestream_mobile/features/settings/presentation/notification_preferences_screen.dart';
import 'package:savestream_mobile/features/settings/presentation/notifications_screen.dart';
import 'package:savestream_mobile/platform/contracts/push_service.dart';
import 'package:savestream_mobile/platform/platform_providers.dart';

import 'screenshot_harness.dart';

final DateTime _now = DateTime(2026, 10, 22, 20, 43, 18);

/// The ANotifPrefs artboard is drawn 390×900.
const Size _prefsSize = Size(390, 900);

AppConfig _config() => AppConfig(
  environment: AppEnvironment.local,
  apiBaseUrl: Uri.parse('http://localhost:8000'),
);

void main() {
  setUpAll(loadBundledFonts);

  Future<void> pumpApp(
    WidgetTester tester, {
    required String location,
    _FakeNotifications? notifications,
    _FakePreferences? preferences,
    _FakePush? push,
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
          recordingRepository: _FakeRecordings(),
          profileRepository: _FakeProfile(),
          notificationsRepository: notifications ?? _FakeNotifications(),
          notificationPreferencesRepository: preferences ?? _FakePreferences(),
          extraOverrides: <Override>[
            pushServiceProvider.overrideWithValue(push ?? _FakePush()),
            homeClockProvider.overrideWithValue(() => _now),
          ],
        ),
      ),
    );
    await settle(tester);
    _router(tester).go(location);
    await settle(tester);
  }

  testWidgets('ANotifications', (WidgetTester tester) async {
    final _FakeNotifications notifications = _FakeNotifications();
    await pumpApp(
      tester,
      location: AppRoutes.notifications,
      notifications: notifications,
    );
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
    expect(find.text('Channel is LIVE'), findsOneWidget);
    expect(find.text('20:01'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Missed a LIVE'), findsOneWidget);
    expect(find.text('Running low'), findsOneWidget);
    expect(find.text('Out of minutes'), findsOneWidget);
    expect(find.text('Expiring soon'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('notification-unread-n-live')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('notification-unread-n-ready')),
      findsOneWidget,
    );
    await captureScreen(tester, 'ANotifications');

    // Mark all read clears every dot and hides the action.
    await tester.tap(
      find.byKey(const ValueKey<String>('notifications-mark-all')),
    );
    await settle(tester);
    expect(notifications.markAllCalls, 1);
    expect(
      find.byKey(const ValueKey<String>('notification-unread-n-live')),
      findsNothing,
    );
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('Mark all read restores the dots when the server refuses', (
    WidgetTester tester,
  ) async {
    final _FakeNotifications notifications = _FakeNotifications(
      markAllFails: true,
    );
    await pumpApp(
      tester,
      location: AppRoutes.notifications,
      notifications: notifications,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('notifications-mark-all')),
    );
    await settle(tester);
    expect(
      find.byKey(const ValueKey<String>('notification-unread-n-live')),
      findsOneWidget,
    );
    expect(
      find.text('Couldn’t mark your notifications as read. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a notification opens it and marks it read', (
    WidgetTester tester,
  ) async {
    final _FakeNotifications notifications = _FakeNotifications();
    await pumpApp(
      tester,
      location: AppRoutes.notifications,
      notifications: notifications,
    );
    await tester.tap(find.text('Channel is LIVE'));
    await settle(tester);
    expect(notifications.markedRead, <String>['n-live']);
    expect(find.byType(ChannelDetailScreen), findsOneWidget);
    expect(find.text('@my_shop_live'), findsWidgets);
  });

  test('notification links', () {
    AppNotification item(String kind, {String? type, String? id}) {
      return AppNotification(
        id: kind,
        type: AppNotificationType.other,
        kind: kind,
        title: '',
        body: '',
        read: false,
        createdAt: _now,
        resourceType: type,
        resourceId: id,
      );
    }

    expect(
      notificationRoute(item('creator_live', type: 'watch', id: 'w1')),
      AppRoutes.channelDetail('w1'),
    );
    expect(
      notificationRoute(item('recording_ready', type: 'recording', id: 'r1')),
      AppRoutes.recordingDetail('r1'),
    );
    expect(
      notificationRoute(
        item('recording_expiring', type: 'recording', id: 'r2'),
      ),
      AppRoutes.recordingDetail('r2'),
    );
    expect(notificationRoute(item('credits_low')), AppRoutes.usage);
    expect(
      notificationRoute(
        item('cloud_minutes_exhausted', type: 'recording', id: 'r3'),
      ),
      AppRoutes.usage,
    );
    expect(notificationRoute(item('admin_system')), isNull);
  });

  testWidgets('ANotificationsEmpty', (WidgetTester tester) async {
    await pumpApp(
      tester,
      location: AppRoutes.notifications,
      notifications: _FakeNotifications(items: <AppNotification>[]),
    );
    expect(find.text('You’re all caught up'), findsOneWidget);
    expect(find.text('Mark all read'), findsNothing);
    await captureScreen(tester, 'ANotificationsEmpty');
  });

  testWidgets('ANotificationsError', (WidgetTester tester) async {
    final _FakeNotifications notifications = _FakeNotifications(fails: true);
    await pumpApp(
      tester,
      location: AppRoutes.notifications,
      notifications: notifications,
    );
    expect(find.text('Couldn’t load notifications'), findsOneWidget);
    await captureScreen(tester, 'ANotificationsError');

    notifications.fails = false;
    await tester.tap(find.text('Retry'));
    await settle(tester);
    expect(find.text('Channel is LIVE'), findsOneWidget);
  });

  testWidgets('the Home bell opens the inbox', (WidgetTester tester) async {
    await pumpApp(tester, location: AppRoutes.home);
    expect(
      find.byKey(const ValueKey<String>('notification-unread-dot')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip(RegExp(r'^Notifications')));
    await settle(tester);
    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  testWidgets('ANotifPrefs', (WidgetTester tester) async {
    final _FakePreferences preferences = _FakePreferences();
    final _FakePush push = _FakePush(PushPermissionStatus.denied);
    await pumpApp(
      tester,
      location: AppRoutes.notificationPreferences,
      preferences: preferences,
      push: push,
      size: _prefsSize,
    );
    expect(find.byType(NotificationPreferencesScreen), findsOneWidget);
    expect(
      find.text(
        'Notifications are off for SaveStream in Android settings. Turn them '
        'on to get LIVE alerts.',
      ),
      findsOneWidget,
    );
    expect(find.text('LIVE started'), findsOneWidget);
    expect(find.text('Product news'), findsOneWidget);
    await captureScreen(tester, 'ANotifPrefs');

    await tester.tap(
      find.byKey(const ValueKey<String>('notif-prefs-open-settings')),
    );
    await tester.pump();
    expect(push.settingsOpened, 1);

    // Back from Android settings with notifications allowed.
    push.status = PushPermissionStatus.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(
      find.byKey(const ValueKey<String>('notif-prefs-os-off')),
      findsNothing,
    );

    // Each switch saves its own server preference.
    await tester.tap(
      find.byKey(const ValueKey<String>('notif-pref-expiring-push')),
    );
    await settle(tester);
    expect(preferences.saved.last.recordingExpiring, isTrue);
    expect(preferences.saved.last.emailRecordingExpiring, isTrue);

    await tester.tap(
      find.byKey(const ValueKey<String>('notif-pref-low-email')),
    );
    await settle(tester);
    expect(preferences.saved.last.emailCreditsLow, isTrue);

    await tester.tap(find.byKey(const ValueKey<String>('notif-pref-news-all')));
    await settle(tester);
    expect(preferences.saved.last.marketing, isTrue);

    // "Always on" cells are not switches.
    final int saves = preferences.saved.length;
    await tester.tap(find.byKey(const ValueKey<String>('notif-pref-out-push')));
    await settle(tester);
    expect(preferences.saved.length, saves);
  });

  testWidgets('a refused save restores the switch', (
    WidgetTester tester,
  ) async {
    final _FakePreferences preferences = _FakePreferences(saveFails: true);
    await pumpApp(
      tester,
      location: AppRoutes.notificationPreferences,
      preferences: preferences,
      push: _FakePush(PushPermissionStatus.granted),
      size: _prefsSize,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('notif-pref-live-email')),
    );
    await settle(tester);
    expect(
      find.text(
        'Couldn’t save your notification preferences. Your previous settings '
        'were kept.',
      ),
      findsOneWidget,
    );
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

List<AppNotification> _seed() {
  AppNotification n(
    String id,
    String kind,
    String title,
    String body,
    DateTime at, {
    bool read = true,
    String? type,
    String? resource,
  }) {
    return AppNotification(
      id: id,
      type: AppNotificationType.other,
      kind: kind,
      title: title,
      body: body,
      read: read,
      createdAt: at,
      resourceType: type,
      resourceId: resource,
    );
  }

  // Titles and bodies as the server writes them.
  return <AppNotification>[
    n(
      'n-live',
      'creator_live',
      'Creator is LIVE',
      '@my_shop_live is LIVE now.',
      DateTime(2026, 10, 22, 20, 1),
      read: false,
      type: 'watch',
      resource: 'w-shop',
    ),
    n(
      'n-ready',
      'recording_ready',
      'Recording ready',
      '@my_shop_live finished recording and the recording is ready.',
      DateTime(2026, 10, 21, 22, 40),
      read: false,
      type: 'recording',
      resource: 'r-ready',
    ),
    n(
      'n-failed',
      'recording_failed',
      'Recording ended',
      '@my_shop_live recording failed. Open the recording for details.',
      DateTime(2026, 10, 19, 18),
      type: 'recording',
      resource: 'r-failed',
    ),
    n(
      'n-missed',
      'recording_missed',
      'Recording missed',
      '@my_gaming_stream ended before a cloud recording slot became '
          'available.',
      DateTime(2026, 10, 18, 21),
      type: 'recording',
      resource: 'r-missed',
    ),
    n(
      'n-low',
      'credits_low',
      'Cloud credits are running low',
      'You have 15 cloud recording minutes left.',
      DateTime(2026, 10, 17, 19),
    ),
    n(
      'n-out',
      'cloud_minutes_exhausted',
      'Cloud minutes exhausted',
      'Your available cloud recording minutes have reached zero.',
      DateTime(2026, 10, 17, 18),
      type: 'recording',
      resource: 'r-out',
    ),
    n(
      'n-expiring',
      'recording_expiring',
      'Recording expires soon',
      'This cloud recording will expire in about 24 hours.',
      DateTime(2026, 10, 16, 9),
      type: 'recording',
      resource: 'r-expiring',
    ),
  ];
}

class _FakeNotifications implements NotificationsRepository {
  _FakeNotifications({
    List<AppNotification>? items,
    this.fails = false,
    this.markAllFails = false,
  }) : _items = items ?? _seed();

  List<AppNotification> _items;
  bool fails;
  final bool markAllFails;
  int markAllCalls = 0;
  final List<String> markedRead = <String>[];

  @override
  Future<NotificationPage> listNotifications({String? cursor}) async {
    if (fails) {
      throw const ApiException(kind: ApiExceptionKind.network, retryable: true);
    }
    return NotificationPage(items: List<AppNotification>.of(_items));
  }

  @override
  Future<AppNotification> markRead(String notificationId) async {
    markedRead.add(notificationId);
    _items = <AppNotification>[
      for (final AppNotification item in _items)
        item.id == notificationId ? item.copyWith(read: true) : item,
    ];
    return _items.firstWhere((item) => item.id == notificationId);
  }

  @override
  Future<int> markAllRead() async {
    markAllCalls += 1;
    if (markAllFails) {
      throw const ApiException(kind: ApiExceptionKind.server, retryable: true);
    }
    final int unread = _items.where((item) => !item.read).length;
    _items = <AppNotification>[
      for (final AppNotification item in _items) item.copyWith(read: true),
    ];
    return unread;
  }
}

class _FakePreferences implements NotificationPreferencesRepository {
  _FakePreferences({this.saveFails = false});

  final bool saveFails;
  final List<NotificationPreferences> saved = <NotificationPreferences>[];

  // As drawn: Running low email, Expiring push and Product news off.
  NotificationPreferences _value = const NotificationPreferences(
    recordingStarted: true,
    recordingReady: true,
    recordingFailed: true,
    recordingExpiring: false,
    emailCreditsLow: false,
  );

  @override
  Future<NotificationPreferences> getPreferences() async => _value;

  @override
  Future<NotificationPreferences> updatePreferences(
    NotificationPreferences preferences,
  ) async {
    if (saveFails) {
      throw const ApiException(kind: ApiExceptionKind.server, retryable: true);
    }
    saved.add(preferences);
    return _value = preferences;
  }
}

class _FakePush implements PushService {
  _FakePush([this.status = PushPermissionStatus.granted]);

  PushPermissionStatus status;
  int settingsOpened = 0;

  @override
  Future<PushPermissionStatus> get permissionStatus async => status;

  @override
  Future<PushPermissionStatus> requestPermission() async => status;

  @override
  Future<bool> openSystemSettings() async {
    settingsOpened += 1;
    return true;
  }

  @override
  Stream<String?> get tokenStream => const Stream<String?>.empty();

  @override
  Stream<PushOpenedMessage> get openedMessageStream =>
      const Stream<PushOpenedMessage>.empty();
}

class _FakeWatches implements WatchRepository {
  @override
  Future<List<WatchSummary>> listWatches() async => <WatchSummary>[
    WatchSummary(
      id: 'w-shop',
      creatorDisplayName: 'My Shop Live',
      creatorUsername: 'my_shop_live',
      status: WatchStatus.active,
      isLive: false,
      autoRecord: true,
      autoRecordState: AutoRecordState.active,
      ownerVerifiedAt: DateTime.utc(2026, 10, 1),
    ),
  ];

  @override
  Future<WatchSummary?> getWatch(String id) async =>
      (await listWatches()).where((w) => w.id == id).firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeRecordings implements RecordingRepository {
  @override
  Future<List<RecordingSummary>> listRecordings() async =>
      const <RecordingSummary>[];

  @override
  Future<RecordingPage> listRecordingPage({
    RecordingFilter filter = RecordingFilter.all,
    String? cursor,
    int limit = 4,
  }) async =>
      const RecordingPage(items: <RecordingSummary>[], nextCursor: null);

  @override
  Stream<RecordingSummary?> watchRecording(String id) =>
      const Stream<RecordingSummary?>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
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
