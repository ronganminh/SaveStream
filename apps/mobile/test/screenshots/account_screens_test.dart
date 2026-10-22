// Account v2 screens (Account tab, Profile, Help center, Legal, Report,
// Sign out, Delete account, Suspended / Closed) at the artboard sizes, one
// test per artboard, through the real app and router with fakes. See
// screenshot_harness.dart for writing the PNGs.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/router/app_routes.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/account/data/report_repository.dart';
import 'package:savestream_mobile/features/account/presentation/account_providers.dart';
import 'package:savestream_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:savestream_mobile/features/auth/presentation/forgot_password_screen.dart';
import 'package:savestream_mobile/features/channels/domain/models/watch_summary.dart';
import 'package:savestream_mobile/features/channels/domain/repositories/watch_repository.dart';
import 'package:savestream_mobile/features/devices/domain/models/device_registration.dart';
import 'package:savestream_mobile/features/devices/domain/repositories/device_repository.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/entitlement/domain/repositories/entitlement_repository.dart';
import 'package:savestream_mobile/features/entitlement/presentation/entitlement_providers.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/recordings/domain/repositories/recording_repository.dart';
import 'package:savestream_mobile/features/settings/domain/models/app_notification.dart';
import 'package:savestream_mobile/features/settings/domain/models/user_profile.dart';
import 'package:savestream_mobile/features/settings/domain/repositories/notifications_repository.dart';
import 'package:savestream_mobile/features/settings/domain/repositories/profile_repository.dart';
import 'package:savestream_mobile/features/v2_foundation/v2_foundation_providers.dart'
    show deviceRepositoryProvider;

import 'screenshot_harness.dart';

AppConfig _config() => AppConfig(
  environment: AppEnvironment.local,
  apiBaseUrl: Uri.parse('http://localhost:8000'),
);

class _Fakes {
  final _FakeAuth auth = _FakeAuth();
  final _FakeProfile profile = _FakeProfile();
  final _FakeDevices devices = _FakeDevices();
  final _FakeReports reports = _FakeReports();
}

void main() {
  setUpAll(loadBundledFonts);

  Future<(_Fakes, AppSessionController, AppSettingsController)> pumpAccount(
    WidgetTester tester, {
    String location = AppRoutes.settings,
    Size size = artboardSize,
    bool signedIn = true,
    SignInMethod? signInMethod,
    _Fakes? fakes,
  }) async {
    usePhoneView(tester, size: size);
    final _Fakes f = fakes ?? _Fakes();
    final AppSessionController session = AppSessionController(
      authStatus: signedIn
          ? AppAuthStatus.authenticated
          : AppAuthStatus.unauthenticated,
    );
    final AppSettingsController settings = AppSettingsController();
    if (signInMethod != null) settings.setSignInMethod(signInMethod);
    addTearDown(session.dispose);
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      screenshotFrame(
        SaveStreamApp(
          config: _config(),
          session: session,
          settings: settings,
          authRepository: f.auth,
          watchRepository: _FakeWatches(),
          recordingRepository: _FakeRecordings(),
          profileRepository: f.profile,
          notificationsRepository: _FakeNotifications(),
          extraOverrides: <Override>[
            entitlementRepositoryProvider.overrideWithValue(_FakeEntitlement()),
            appVersionProvider.overrideWith((_) async => '2.1.0'),
            deviceRepositoryProvider.overrideWithValue(f.devices),
            reportRepositoryProvider.overrideWithValue(f.reports),
          ],
        ),
      ),
    );
    await settle(tester);
    if (location != AppRoutes.settings || signedIn) {
      _router(tester).go(location);
      await settle(tester);
    }
    return (f, session, settings);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final Finder target = find.byKey(ValueKey<String>(key));
    if (target.evaluate().isEmpty) {
      // Not built yet in a lazy list.
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await settle(tester);
  }

  testWidgets('AAccount', (WidgetTester tester) async {
    await pumpAccount(tester, size: const Size(390, 1180));
    expect(find.text('Account'), findsWidgets);
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('alex.morgan@example.com'), findsOneWidget);
    expect(find.text('12 h 40 min left'), findsOneWidget);
    expect(find.text('Purchases & usage'), findsOneWidget);
    expect(find.text('Report content or request removal'), findsOneWidget);
    expect(find.text('Terms, Privacy & Acceptable Use'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    // v2.1.0 ships English only: the App section keeps Theme, no Language.
    expect(
      find.byKey(const ValueKey<String>('account-language')),
      findsNothing,
    );
    await captureScreen(tester, 'AAccount');

    // The footer: the installed version and the not-affiliated line.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('account-version')),
      300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey<String>('account-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('SaveStream for Android · version 2.1.0'), findsOneWidget);
    expect(
      find.text(
        'SaveStream is not affiliated with, endorsed or sponsored by TikTok '
        'or ByteDance.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('AProfile', (WidgetTester tester) async {
    final (_Fakes f, _, _) = await pumpAccount(
      tester,
      location: AppRoutes.profile,
      signInMethod: SignInMethod.password,
    );
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Signed in with email'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    await captureScreen(tester, 'AProfile');

    // Save sends the new display name (PATCH /v1/me).
    await tester.enterText(
      find.byKey(const ValueKey<String>('profile-name')),
      'Alex M.',
    );
    await tapKey(tester, 'profile-save');
    expect(f.profile.updates, <String?>['Alex M.']);
    expect(find.text('Profile saved'), findsOneWidget);
  });

  testWidgets('Profile for Google sign-in shows the method, no password', (
    WidgetTester tester,
  ) async {
    await pumpAccount(
      tester,
      location: AppRoutes.profile,
      signInMethod: SignInMethod.google,
    );
    expect(find.text('Signed in with Google'), findsOneWidget);
    expect(find.text('Password'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('profile-change-password')),
      findsNothing,
    );
  });

  testWidgets('Profile → Change opens the reset flow for this email', (
    WidgetTester tester,
  ) async {
    await pumpAccount(
      tester,
      location: AppRoutes.profile,
      signInMethod: SignInMethod.password,
    );
    await tapKey(tester, 'profile-change-password');
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.text('alex.morgan@example.com'), findsOneWidget);
  });

  testWidgets('AHelp', (WidgetTester tester) async {
    await pumpAccount(tester, location: AppRoutes.help);
    expect(find.text('Help center'), findsOneWidget);
    expect(find.text('Adding and verifying a channel'), findsOneWidget);
    expect(find.text('Why did a recording fail?'), findsOneWidget);
    expect(find.text('support@savestream.online'), findsOneWidget);
    await captureScreen(tester, 'AHelp');
  });

  testWidgets('ALegal', (WidgetTester tester) async {
    await pumpAccount(tester, location: AppRoutes.legalHub);
    expect(find.text('Copyright & Takedown Policy'), findsOneWidget);
    expect(find.text('savestream.online/refund'), findsOneWidget);
    expect(find.text('Open-source licences'), findsOneWidget);
    await captureScreen(tester, 'ALegal');
  });

  testWidgets('AReport', (WidgetTester tester) async {
    await pumpAccount(
      tester,
      location: AppRoutes.report,
      size: const Size(390, 1080),
    );
    expect(find.text('Report or request removal'), findsOneWidget);
    expect(
      find.text('Someone is recording my LIVE without permission'),
      findsOneWidget,
    );
    expect(find.text('alex.morgan@example.com'), findsOneWidget);
    await captureScreen(tester, 'AReport');
  });

  testWidgets('AReportSent', (WidgetTester tester) async {
    final (_Fakes f, _, _) = await pumpAccount(
      tester,
      location: AppRoutes.report,
      size: const Size(390, 1080),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('report-target')),
      '@my_shop_live',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('report-details')),
      'My LIVE on Oct 20 was recorded without my permission.',
    );
    await tapKey(tester, 'report-send');
    final ContentReport report = f.reports.sent.single;
    expect(report.category, ReportCategory.recordingMyLive);
    expect(reportRequestBody(report)['reporter_role'], 'self');
    expect(report.email, 'alex.morgan@example.com');
    usePhoneView(tester);
    await settle(tester);
    expect(find.text('Report received'), findsOneWidget);
    expect(
      find.text(
        'Thanks — our team will review it and reply to '
        'alex.morgan@example.com. Reference SR-1044.',
      ),
      findsOneWidget,
    );
    await captureScreen(tester, 'AReportSent');
  });

  testWidgets('ASignOut', (WidgetTester tester) async {
    final (_Fakes f, AppSessionController session, _) = await pumpAccount(
      tester,
    );
    await tapKey(tester, 'account-sign-out');
    // Back to the top, as drawn, with the dialog over the list.
    tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('account-list')),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .jumpTo(0);
    await settle(tester);
    expect(find.text('Sign out?'), findsOneWidget);
    expect(
      find.text(
        'Your channels keep being watched and recorded in the cloud while '
        'you’re signed out.',
      ),
      findsOneWidget,
    );
    await captureScreen(tester, 'ASignOut');

    // Confirm: the push device is unregistered, then the session ends.
    await tapKey(tester, 'account-sign-out-confirm');
    expect(f.devices.unregistered, <String>['dev_fake']);
    expect(f.auth.loggedOut, isTrue);
    expect(session.isAuthenticated, isFalse);
  });

  testWidgets('ADeleteAccount', (WidgetTester tester) async {
    final (_Fakes f, _, _) = await pumpAccount(
      tester,
      location: AppRoutes.deleteAccount,
      size: const Size(390, 900),
    );
    expect(find.text('This can’t be undone.'), findsOneWidget);
    expect(
      find.text(
        'Remove your remaining recording time (12 h 40 min) — it can’t be '
        'refunded or transferred',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'You can also delete your account on the web at '
        'savestream.online/delete-account.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('delete-confirm-field')),
      'DELETE',
    );
    await settleForCapture(tester);
    await captureScreen(tester, 'ADeleteAccount');
    expect(f.auth.deleted, isFalse);
  });

  testWidgets('ADeleteDone', (WidgetTester tester) async {
    final (_Fakes f, AppSessionController session, _) = await pumpAccount(
      tester,
      location: AppRoutes.deleteAccount,
      size: const Size(390, 900),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('delete-confirm-field')),
      'DELETE',
    );
    await tester.pump();
    await tapKey(tester, 'delete-account-confirm');
    expect(f.auth.deleted, isTrue);
    expect(session.isAuthenticated, isFalse);
    usePhoneView(tester);
    await settle(tester);
    expect(find.text('Your account is deleted'), findsOneWidget);
    expect(find.textContaining('alex.morgan@example.com'), findsOneWidget);
    await captureScreen(tester, 'ADeleteDone');

    await tapKey(tester, 'account-deleted-close');
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('ASuspended', (WidgetTester tester) async {
    final _Fakes fakes = _Fakes()
      ..auth.refusal = const AuthException(
        AuthFailureCode.accountSuspended,
        accountStatus: AccountStatusDetails(
          reason: 'A report that a channel was recorded without permission.',
          reference: 'SR-1040',
          email: 'alex.morgan@example.com',
        ),
      );
    await pumpAccount(
      tester,
      location: AppRoutes.signIn,
      signedIn: false,
      fakes: fakes,
    );
    await _signIn(tester);
    expect(find.text('Account suspended'), findsOneWidget);
    expect(
      find.text(
        'We paused your account (ref SR-1040). Monitoring is paused and '
        'recordings are unavailable for now.',
      ),
      findsOneWidget,
    );
    expect(find.text('Appeals: support@savestream.online'), findsOneWidget);
    await captureScreen(tester, 'ASuspended');

    await tapKey(tester, 'suspended-sign-out');
    expect(
      find.byKey(const ValueKey<String>('suspended-appeal')),
      findsNothing,
    );
  });

  testWidgets('ATerminated', (WidgetTester tester) async {
    final _Fakes fakes = _Fakes()
      ..auth.refusal = const AuthException(
        AuthFailureCode.accountTerminated,
        accountStatus: AccountStatusDetails(email: 'alex.morgan@example.com'),
      );
    await pumpAccount(
      tester,
      location: AppRoutes.signIn,
      signedIn: false,
      fakes: fakes,
    );
    await _signIn(tester);
    expect(find.text('Account closed'), findsOneWidget);
    expect(
      find.text('Think this is a mistake? support@savestream.online'),
      findsOneWidget,
    );
    await captureScreen(tester, 'ATerminated');
  });
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextFormField).first,
    'alex.morgan@example.com',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'correct-horse');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await settle(tester);
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

class _FakeAuth implements AuthRepository {
  AuthException? refusal;
  bool loggedOut = false;
  bool deleted = false;

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (refusal != null) throw refusal!;
  }

  @override
  Future<void> logout() async => loggedOut = true;

  @override
  Future<void> deleteAccount() async => deleted = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeProfile implements ProfileRepository {
  final List<String?> updates = <String?>[];
  String? _name = 'Alex Morgan';

  @override
  Future<UserProfile> getProfile() async => UserProfile(
    email: 'alex.morgan@example.com',
    emailVerified: true,
    displayName: _name,
    id: 'usr_123',
  );

  @override
  Future<UserProfile> updateDisplayName(String? displayName) async {
    updates.add(displayName);
    _name = displayName;
    return getProfile();
  }
}

class _FakeDevices implements DeviceRepository {
  final List<String> unregistered = <String>[];

  @override
  Future<DeviceRegistration> register(DeviceRegistration device) async =>
      device;

  @override
  Future<void> unregister(String deviceId) async => unregistered.add(deviceId);
}

class _FakeReports implements ReportRepository {
  final List<ContentReport> sent = <ContentReport>[];

  @override
  Future<String> submit(ContentReport report) async {
    sent.add(report);
    return 'SR-1044';
  }
}

class _FakeEntitlement implements EntitlementRepository {
  @override
  Future<Entitlement> getEntitlement() async => Entitlement(
    plan: Plan.pro,
    hasPurchased: true,
    emailVerified: true,
    canAutoRecord: true,
    cloudMinutesAvailable: 760,
    cloudMinutesCycleTotal: 1580,
    trialUsed: true,
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

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeWatches implements WatchRepository {
  @override
  Future<List<WatchSummary>> listWatches() async => const <WatchSummary>[];

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

class _FakeNotifications implements NotificationsRepository {
  @override
  Future<NotificationPage> listNotifications({String? cursor}) async {
    return const NotificationPage(items: <AppNotification>[]);
  }

  @override
  Future<AppNotification> markRead(String notificationId) =>
      throw UnimplementedError();

  @override
  Future<int> markAllRead() async => 0;
}
