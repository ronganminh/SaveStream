// Auth + Home v2 screens at 390×844, one test per artboard. See
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
import 'package:savestream_mobile/app/splash/splash_screen.dart';
import 'package:savestream_mobile/app/theme/ss_theme.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/core/legal/legal_consent.dart';
import 'package:savestream_mobile/features/auth/domain/repositories/auth_repository.dart';
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
import 'package:savestream_mobile/l10n/l10n.dart';

import 'screenshot_harness.dart';

const String _email = 'alex.morgan@example.com';
const String _password = 'password12';
final DateTime _now = DateTime(2026, 10, 22, 20, 43, 18);

AppConfig _config() => AppConfig(
  environment: AppEnvironment.local,
  apiBaseUrl: Uri.parse('http://localhost:8000'),
);

void main() {
  setUpAll(loadBundledFonts);

  Future<AppSessionController> pumpAuthApp(
    WidgetTester tester, {
    _FakeAuth? auth,
    bool onboarded = true,
    String? location,
  }) async {
    usePhoneView(tester);
    final AppSessionController session = AppSessionController(
      hasCompletedOnboarding: onboarded,
      authStatus: AppAuthStatus.unauthenticated,
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(
      screenshotFrame(
        SaveStreamApp(
          config: _config(),
          session: session,
          authRepository: auth ?? _FakeAuth(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (location != null) {
      _router(tester).go(location);
      await tester.pumpAndSettle();
    }
    return session;
  }

  Future<void> fill(WidgetTester tester, List<String> values) async {
    final Finder fields = find.byType(TextFormField);
    for (int i = 0; i < values.length; i++) {
      await tester.enterText(fields.at(i), values[i]);
    }
    await tester.pump();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final Finder button = find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is ButtonStyleButton,
          ),
        )
        .first;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('ASplash', (WidgetTester tester) async {
    usePhoneView(tester);
    await tester.pumpWidget(
      screenshotFrame(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: SsTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SplashScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Cloud backup for your own LIVEs'), findsOneWidget);
    expect(
      find.text(
        'SaveStream is not affiliated with, endorsed or sponsored by TikTok '
        'or ByteDance.',
      ),
      findsOneWidget,
    );
    await captureScreen(tester, 'ASplash');
  });

  for (int page = 0; page < 3; page++) {
    testWidgets('AOnboard${page + 1}', (WidgetTester tester) async {
      await pumpAuthApp(tester, onboarded: false);
      for (int i = 0; i < page; i++) {
        await tapButton(tester, 'Next');
        await tester.pumpAndSettle();
      }
      expect(
        find.text(switch (page) {
          0 => 'Your LIVEs, backed up automatically.',
          1 => 'Add the channels you own.',
          _ => 'Prove it’s yours with a bio code.',
        }),
        findsOneWidget,
      );
      await captureScreen(tester, 'AOnboard${page + 1}');
    });
  }

  testWidgets('ASignIn', (WidgetTester tester) async {
    await pumpAuthApp(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    await fill(tester, <String>[_email, _password]);
    await settleForCapture(tester);
    await captureScreen(tester, 'ASignIn');
  });

  testWidgets('ASignInError', (WidgetTester tester) async {
    await pumpAuthApp(
      tester,
      auth: _FakeAuth(signInFailure: AuthFailureCode.invalidCredentials),
    );
    await fill(tester, <String>[_email, _password]);
    await tapButton(tester, 'Sign in');
    await settleForCapture(tester);
    expect(find.text('Incorrect password'), findsOneWidget);
    await captureScreen(tester, 'ASignInError');
  });

  testWidgets('ASignUp', (WidgetTester tester) async {
    await pumpAuthApp(tester, location: AppRoutes.register);
    await fill(tester, <String>[_email, _password]);
    await tester.tap(find.byType(Checkbox));
    await settleForCapture(tester);
    await captureScreen(tester, 'ASignUp');
  });

  testWidgets('ASignUpError', (WidgetTester tester) async {
    final _FakeAuth auth = _FakeAuth();
    await pumpAuthApp(tester, auth: auth, location: AppRoutes.register);
    await fill(tester, <String>[_email, _password]);
    await tapButton(tester, 'Create account');
    await settleForCapture(tester);
    expect(auth.registerCalls, 0);
    expect(
      find.text(
        'You must be 18+ and accept the Terms, Privacy Policy and Acceptable '
        'Use Policy to continue.',
      ),
      findsOneWidget,
    );
    await captureScreen(tester, 'ASignUpError');
  });

  testWidgets('AForgot', (WidgetTester tester) async {
    await pumpAuthApp(tester, location: AppRoutes.forgotPassword);
    await fill(tester, <String>[_email]);
    await settleForCapture(tester);
    await captureScreen(tester, 'AForgot');
  });

  testWidgets('AForgotSent', (WidgetTester tester) async {
    await pumpAuthApp(tester, location: AppRoutes.checkEmailLocation(_email));
    expect(find.text('Check your inbox'), findsOneWidget);
    await captureScreen(tester, 'AForgotSent');
  });

  testWidgets('AReset', (WidgetTester tester) async {
    await pumpAuthApp(
      tester,
      location: AppRoutes.resetPasswordLocation(
        token: 'reset-token-0123456789',
      ),
    );
    await fill(tester, <String>[_password, 'passwor']);
    await tapButton(tester, 'Save password');
    await settleForCapture(tester);
    expect(find.text('Passwords don’t match'), findsOneWidget);
    await captureScreen(tester, 'AReset');
  });

  testWidgets('AResetDone', (WidgetTester tester) async {
    await pumpAuthApp(
      tester,
      location: AppRoutes.resetPasswordLocation(
        token: 'reset-token-0123456789',
      ),
    );
    await fill(tester, <String>[_password, _password]);
    await tapButton(tester, 'Save password');
    await tester.pumpAndSettle();
    expect(find.text('Password updated'), findsOneWidget);
    await captureScreen(tester, 'AResetDone');
  });

  testWidgets('AVerifyEmail', (WidgetTester tester) async {
    final AppSessionController session = await pumpAuthApp(tester);
    session.setPendingVerificationEmail(_email);
    _router(tester).go(AppRoutes.verifyEmailLocation(sent: true));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 18));
    expect(find.text('Resend in 0:42'), findsOneWidget);
    await captureScreen(tester, 'AVerifyEmail');
  });

  testWidgets('AVerifyEmailError', (WidgetTester tester) async {
    final AppSessionController session = await pumpAuthApp(
      tester,
      auth: _FakeAuth(verifyFailure: AuthFailureCode.invalidToken),
    );
    session.setPendingVerificationEmail(_email);
    _router(
      tester,
    ).go(AppRoutes.verifyEmailLocation(token: 'expired-token-0123456789'));
    await tester.pumpAndSettle();
    expect(
      find.text('That link is wrong or expired. Request a new one.'),
      findsOneWidget,
    );
    await captureScreen(tester, 'AVerifyEmailError');
  });

  testWidgets('AVerified', (WidgetTester tester) async {
    final AppSessionController session = await pumpAuthApp(tester);
    session.setPendingVerificationEmail(_email);
    _router(
      tester,
    ).go(AppRoutes.verifyEmailLocation(token: 'valid-token-0123456789'));
    await tester.pumpAndSettle();
    expect(find.text('Email verified'), findsOneWidget);
    await captureScreen(tester, 'AVerified');
  });

  testWidgets('AGoogleLoading', (WidgetTester tester) async {
    final _FakeAuth auth = _FakeAuth(socialCompleter: Completer<void>());
    await pumpAuthApp(tester, auth: auth);
    await tapButton(tester, 'Continue with Google');
    expect(find.text('Signing in with Google…'), findsOneWidget);
    await captureScreen(tester, 'AGoogleLoading');
    auth.socialCompleter!.completeError(
      const AuthException(AuthFailureCode.cancelled),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('AGoogleError', (WidgetTester tester) async {
    await pumpAuthApp(
      tester,
      auth: _FakeAuth(socialFailure: AuthFailureCode.offlineLike),
    );
    await tapButton(tester, 'Continue with Google');
    await tester.pumpAndSettle();
    expect(find.text('Google sign-in didn’t finish'), findsOneWidget);
    await captureScreen(tester, 'AGoogleError');
  });

  Future<void> pumpHome(
    WidgetTester tester,
    _HomeFixture fixture, {
    bool settle = true,
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
          watchRepository: _FakeWatches(fixture.watches, fixture.loading),
          recordingRepository: _FakeRecordings(
            fixture.recordings,
            fixture.loading,
          ),
          profileRepository: _FakeProfile(),
          notificationsRepository: _FakeNotifications(),
          extraOverrides: <Override>[
            entitlementRepositoryProvider.overrideWithValue(
              _FakeEntitlement(fixture.entitlement),
            ),
            creditsRepositoryProvider.overrideWithValue(
              _FakeCredits(fixture.credits),
            ),
            homeClockProvider.overrideWithValue(() => _now),
          ],
        ),
      ),
    );
    if (settle) {
      // Mock repositories answer after a short timer; let them land.
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('AHome', (WidgetTester tester) async {
    await pumpHome(tester, _HomeFixture.normal());
    expect(find.text('Hi, Alex'), findsOneWidget);
    expect(find.text('12 h 40 min'), findsOneWidget);
    expect(find.text('Recent recordings'), findsOneWidget);
    await captureScreen(tester, 'AHome');
  });

  testWidgets('AHomeFirstRun', (WidgetTester tester) async {
    await pumpHome(tester, _HomeFixture.firstRun());
    expect(find.text('Get set up'), findsOneWidget);
    expect(find.text('1 of 4 done'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
    await captureScreen(tester, 'AHomeFirstRun');
  });

  testWidgets('AHomeLive', (WidgetTester tester) async {
    await pumpHome(tester, _HomeFixture.live());
    expect(find.text('@my_shop_live is LIVE'), findsOneWidget);
    expect(find.text('0:42:18'), findsOneWidget);
    expect(find.text('43 min used so far'), findsOneWidget);
    await captureScreen(tester, 'AHomeLive');
  });

  testWidgets('AHomeLoading', (WidgetTester tester) async {
    await pumpHome(tester, _HomeFixture.loadingState(), settle: false);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    await captureScreen(tester, 'AHomeLoading');
  });

  testWidgets('AHomeLow', (WidgetTester tester) async {
    await pumpHome(tester, _HomeFixture.low());
    expect(
      find.textContaining('Only 2 trial minutes left.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Free trial · 8 of 10 minutes used'), findsOneWidget);
    await captureScreen(tester, 'AHomeLow');
  });

  testWidgets('AHomeOut', (WidgetTester tester) async {
    await pumpHome(tester, _HomeFixture.out());
    expect(
      find.textContaining(
        'You’re out of recording minutes.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('LIVE · not recording'), findsOneWidget);
    expect(find.text('Paused — no minutes'), findsOneWidget);
    await captureScreen(tester, 'AHomeOut');
  });
}

GoRouter _router(WidgetTester tester) {
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

class _HomeFixture {
  const _HomeFixture({
    required this.entitlement,
    required this.watches,
    required this.recordings,
    this.credits,
    this.loading = false,
  });

  final Entitlement entitlement;
  final List<WatchSummary> watches;
  final List<RecordingSummary> recordings;
  final CreditBalance? credits;
  final bool loading;

  static Entitlement _entitlement({
    required int minutes,
    required bool purchased,
  }) {
    return Entitlement(
      plan: purchased ? Plan.pro : Plan.free,
      hasPurchased: purchased,
      emailVerified: true,
      trialRecording: !purchased,
      canAutoRecord: minutes > 0,
      cloudMinutesAvailable: minutes,
      limits: const EntitlementLimits(
        maxWatches: 3,
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

  static WatchSummary _shop({
    bool live = false,
    String? activeRecordingId,
    DateTime? lastLiveAt,
  }) {
    return WatchSummary(
      id: 'w-shop',
      creatorDisplayName: 'My Shop Live',
      creatorUsername: 'my_shop_live',
      status: WatchStatus.active,
      isLive: live,
      autoRecordState: AutoRecordState.active,
      activeRecordingId: activeRecordingId,
      lastLiveAt: lastLiveAt ?? DateTime(2026, 10, 21, 19, 0),
    );
  }

  static WatchSummary _gaming({WatchStatus status = WatchStatus.active}) {
    return WatchSummary(
      id: 'w-gaming',
      creatorDisplayName: 'My Gaming Stream',
      creatorUsername: 'my_gaming_stream',
      status: status,
      isLive: false,
      lastLiveAt: DateTime(2026, 10, 20, 21, 0),
    );
  }

  static RecordingSummary _recording(
    String id,
    WatchSummary watch,
    DateTime started,
    int seconds,
  ) {
    return RecordingSummary(
      id: id,
      watchId: watch.id,
      creatorDisplayName: watch.creatorDisplayName,
      creatorUsername: watch.creatorUsername,
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

  factory _HomeFixture.normal() {
    final WatchSummary shop = _shop();
    final WatchSummary gaming = _gaming();
    return _HomeFixture(
      entitlement: _entitlement(minutes: 760, purchased: true),
      credits: const CreditBalance(posted: 760, reserved: 0, available: 760),
      watches: <WatchSummary>[shop, gaming],
      recordings: <RecordingSummary>[
        _recording('r1', shop, DateTime(2026, 10, 21, 19, 0), 5942),
        _recording('r2', gaming, DateTime(2026, 10, 20, 21, 0), 3494),
      ],
    );
  }

  factory _HomeFixture.firstRun() {
    return _HomeFixture(
      entitlement: _entitlement(minutes: 10, purchased: false),
      credits: const CreditBalance(posted: 10, reserved: 0, available: 10),
      watches: const <WatchSummary>[],
      recordings: const <RecordingSummary>[],
    );
  }

  factory _HomeFixture.live() {
    final WatchSummary shop = _shop(live: true, activeRecordingId: 'r-live');
    return _HomeFixture(
      entitlement: _entitlement(minutes: 760, purchased: true),
      watches: <WatchSummary>[shop, _gaming()],
      recordings: <RecordingSummary>[
        RecordingSummary(
          id: 'r-live',
          watchId: shop.id,
          creatorDisplayName: shop.creatorDisplayName,
          creatorUsername: shop.creatorUsername,
          status: RecordingStatus.recording,
          actions: const RecordingActions(
            canStop: true,
            canRetry: false,
            canDelete: false,
          ),
          startedAt: DateTime(2026, 10, 22, 20, 1),
          durationSeconds: 2538,
        ),
      ],
    );
  }

  factory _HomeFixture.loadingState() {
    return _HomeFixture(
      entitlement: _entitlement(minutes: 0, purchased: false),
      watches: const <WatchSummary>[],
      recordings: const <RecordingSummary>[],
      loading: true,
    );
  }

  factory _HomeFixture.low() {
    return _HomeFixture(
      entitlement: _entitlement(minutes: 2, purchased: false),
      credits: const CreditBalance(posted: 2, reserved: 0, available: 2),
      watches: <WatchSummary>[_shop(lastLiveAt: DateTime(2026, 10, 22, 18))],
      recordings: const <RecordingSummary>[],
    );
  }

  factory _HomeFixture.out() {
    return _HomeFixture(
      entitlement: _entitlement(minutes: 0, purchased: false),
      credits: const CreditBalance(posted: 0, reserved: 0, available: 0),
      watches: <WatchSummary>[
        _shop(live: true),
        _gaming(status: WatchStatus.pausedInsufficientCredit),
      ],
      recordings: const <RecordingSummary>[],
    );
  }
}

class _FakeAuth implements AuthRepository, SocialAuthRepository {
  _FakeAuth({
    this.signInFailure,
    this.verifyFailure,
    this.socialFailure,
    this.socialCompleter,
  });

  final AuthFailureCode? signInFailure;
  final AuthFailureCode? verifyFailure;
  final AuthFailureCode? socialFailure;
  final Completer<void>? socialCompleter;
  int registerCalls = 0;

  @override
  Future<void> signIn({required String email, required String password}) {
    final AuthFailureCode? failure = signInFailure;
    return failure == null
        ? Future<void>.value()
        : Future<void>.error(AuthException(failure));
  }

  @override
  Future<void> signInSocial(
    SocialAuthProvider provider, {
    LegalConsent? consent,
  }) async {
    if (socialCompleter != null) await socialCompleter!.future;
    final AuthFailureCode? failure = socialFailure;
    if (failure != null) throw AuthException(failure);
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    LegalConsent? consent,
  }) async {
    registerCalls += 1;
  }

  @override
  Future<void> verifyEmail({required String token}) async {
    final AuthFailureCode? failure = verifyFailure;
    if (failure != null) throw AuthException(failure);
  }

  @override
  Future<void> resendVerification({required String email}) async {}

  @override
  Future<void> forgotPassword({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}
}

class _FakeWatches implements WatchRepository {
  _FakeWatches(this.items, this.loading);

  final List<WatchSummary> items;
  final bool loading;

  @override
  Future<List<WatchSummary>> listWatches() =>
      loading ? Completer<List<WatchSummary>>().future : Future.value(items);

  @override
  Future<WatchSummary?> getWatch(String id) async =>
      items.where((WatchSummary w) => w.id == id).firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeRecordings implements RecordingRepository {
  _FakeRecordings(this.items, this.loading);

  final List<RecordingSummary> items;
  final bool loading;

  @override
  Future<List<RecordingSummary>> listRecordings() => loading
      ? Completer<List<RecordingSummary>>().future
      : Future.value(items);

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
  const _FakeCredits(this.value);

  final CreditBalance? value;

  @override
  Future<CreditBalance> getBalance() async =>
      value ?? (throw StateError('no balance'));
}

class _FakeProfile implements ProfileRepository {
  @override
  Future<UserProfile> getProfile() async => const UserProfile(
    email: _email,
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
    return NotificationPage(
      items: <AppNotification>[
        for (int i = 0; i < 2; i++)
          AppNotification(
            id: 'n$i',
            type: AppNotificationType.recordingReady,
            title: 'Recording ready',
            body: '',
            read: false,
            createdAt: DateTime.utc(2026, 10, 22),
          ),
      ],
    );
  }

  @override
  Future<int> markAllRead() async => 0;

  @override
  Future<AppNotification> markRead(String notificationId) =>
      throw UnimplementedError();
}
