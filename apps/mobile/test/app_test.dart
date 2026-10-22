import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/router/app_routes.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/core/mock/mock_scenario.dart';
import 'package:savestream_mobile/core/storage/app_settings_store.dart';
import 'package:savestream_mobile/core/widgets/v2/ss_v2_widgets.dart';
import 'package:savestream_mobile/features/account/presentation/account_screen.dart';
import 'package:savestream_mobile/features/account/presentation/profile_screen.dart';
import 'package:savestream_mobile/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:savestream_mobile/features/auth/presentation/verify_email_screen.dart';
import 'package:savestream_mobile/features/home/presentation/controllers/home_dashboard_controller.dart';
import 'package:savestream_mobile/features/home/presentation/home_screen.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/recordings/presentation/controllers/recording_library_controller.dart';
import 'package:savestream_mobile/features/recordings/presentation/recording_detail_screen.dart';
import 'package:savestream_mobile/features/recordings/presentation/recordings_screen.dart';

void main() {
  AppConfig testConfig() {
    return AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    );
  }

  AppSessionController signedOutSession({bool hasCompletedOnboarding = true}) {
    return AppSessionController(
      hasCompletedOnboarding: hasCompletedOnboarding,
      authStatus: AppAuthStatus.unauthenticated,
    );
  }

  Future<void> enterSignInCredentials(WidgetTester tester) async {
    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'alex@example.com');
    await tester.enterText(fields.at(1), 'x');
  }

  testWidgets('boots the Phase 4 shell with four destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // The Home tab opens with the v2 header (logo, greeting, bell).
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byTooltip(RegExp(r'^Notifications')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('notification-unread-dot')),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).labelBehavior,
      NavigationDestinationLabelBehavior.alwaysShow,
    );
  });

  testWidgets('renders the aggregated home dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Hi, Alex'), findsOneWidget);
    expect(find.text('Recording time left'), findsOneWidget);
    expect(find.text('Your channels'), findsOneWidget);
    expect(find.textContaining('credit', findRichText: true), findsNothing);
    expect(find.textContaining('on this device'), findsNothing);
    expect(find.text('Advertisement'), findsNothing);
    expect(find.byType(SsV2Avatar), findsWidgets);
  });

  testWidgets('renders skeleton while the home dashboard is loading', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), mockScenario: MockScenario.loading),
    );
    await tester.pump();

    expect(find.byType(HomeSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('renders the home empty account state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), mockScenario: MockScenario.empty),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Get set up'), findsOneWidget);
    expect(find.text('Recording happens on our servers'), findsOneWidget);
    expect(find.text('Advertisement'), findsNothing);
  });

  testWidgets('reports retryable home repository errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), mockScenario: MockScenario.error),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    final dashboardState = container.read(homeDashboardProvider);
    expect(dashboardState.hasError, isTrue, reason: dashboardState.toString());
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('welcome screen leads signed-out installs into auth', (
    WidgetTester tester,
  ) async {
    final AppSessionController session = signedOutSession(
      hasCompletedOnboarding: false,
    );

    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), session: session),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your LIVEs, backed up automatically.'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Add the channels you own.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Prove it’s yours with a bio code.'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(session.hasCompletedOnboarding, isTrue);
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
  });

  testWidgets('sign in validates required fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), session: signedOutSession()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('signs in through mock auth repository', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), session: signedOutSession()),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    await enterSignInCredentials(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Hi, Alex'), findsOneWidget);
  });

  testWidgets('shows invalid credentials from mock auth repository', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(
        config: testConfig(),
        session: signedOutSession(),
        authMockScenario: AuthMockScenario.invalidCredentials,
      ),
    );
    await tester.pumpAndSettle();

    await enterSignInCredentials(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(
      find.textContaining('Wrong email or password.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Incorrect password'), findsOneWidget);
  });

  testWidgets('registers then verifies email and returns to sign in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), session: signedOutSession()),
    );
    await tester.pumpAndSettle();

    final createLink = find.text('Create an account');
    await tester.ensureVisible(createLink);
    await tester.tap(createLink);
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'new@example.com');
    await tester.enterText(fields.at(1), 'password-123');

    final Finder createAccountButton = find.widgetWithText(
      FilledButton,
      'Create account',
    );
    await tester.ensureVisible(createAccountButton);
    await tester.pumpAndSettle();
    // Without the 18+/Terms/Privacy/AUP box ticked nothing is sent.
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'You must be 18+ and accept the Terms, Privacy Policy and '
        'Acceptable Use Policy to continue.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(createAccountButton);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsOneWidget);
    expect(
      find.textContaining('new@example.com', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Resend in '), findsOneWidget);

    final GoRouter router = GoRouter.of(
      tester.element(find.byType(VerifyEmailScreen)),
    );
    router.go(
      AppRoutes.verifyEmailLocation(token: 'verification-token-123456'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Email verified'), findsOneWidget);
    expect(find.text('+10 free minutes'), findsOneWidget);
    // Verifying by link does not sign in; Home leads to sign in first.
    await tester.tap(find.widgetWithText(TextButton, 'Go to Home'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('forgot password reaches generic sent state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), session: signedOutSession()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'alex@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.textContaining('alex@example.com'), findsOneWidget);
  });

  testWidgets('reset password accepts backend token contract', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), session: signedOutSession()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'alex@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final GoRouter router = GoRouter.of(
      tester.element(find.text('Check your inbox')),
    );
    router.go(
      AppRoutes.resetPasswordLocation(token: 'password-reset-token-123456'),
    );
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'new-password-123');
    await tester.enterText(fields.at(1), 'new-password-123');
    await tester.tap(find.widgetWithText(FilledButton, 'Save password'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Password updated'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('navigates mock channel detail and preserves tab stack', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('nav-channels')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('@ada_live'), findsOneWidget);
    await tester.tap(find.text('@ada_live'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Remove channel'), findsOneWidget);
    expect(find.text('@ada_live'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('nav-recordings')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey<String>('nav-channels')));
    await tester.pump();

    expect(find.text('Remove channel'), findsOneWidget);
  });

  testWidgets('renders the v2 Channels list', (WidgetTester tester) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('nav-channels')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('Only channels you own or manage, verified with a bio code.'),
      findsOneWidget,
    );
    expect(find.text('@ada_live'), findsOneWidget);
    expect(find.text('LIVE · not recording'), findsWidgets);
    expect(find.text('Paused'), findsWidgets);
    expect(find.byKey(const ValueKey<String>('channels-add')), findsOneWidget);
  });

  testWidgets('legacy Free creator list is preserved but adding is blocked', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('nav-channels')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(const ValueKey<String>('channels-add')));
    await pumpFrames(tester);

    expect(find.text('Watching is full'), findsOneWidget);
    expect(
      find.textContaining('You already have 8 channels from an older plan'),
      findsWidgets,
    );
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('Channel detail can pause and resume watching', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('nav-channels')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('@nora_shop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Waiting for the next LIVE'), findsOneWidget);
    expect(find.text('LIVE alerts'), findsOneWidget);

    await tester.tap(find.byTooltip('Channel options'));
    await pumpFrames(tester);
    await tester.tap(find.text('Pause watching'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Watching is paused'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Resume watching'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Waiting for the next LIVE'), findsOneWidget);
  });

  testWidgets('Recordings library exposes cloud lifecycle statuses', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('nav-recordings')));
    await pumpFrames(tester);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(RecordingsScreen)),
    );
    final List<RecordingSummary> items = await container.read(
      recordingLibraryProvider.future,
    );
    final Set<RecordingStatus> statuses = items
        .map((RecordingSummary item) => item.status)
        .toSet();

    expect(
      statuses,
      containsAll(<RecordingStatus>[
        RecordingStatus.queued,
        RecordingStatus.resolving,
        RecordingStatus.waitingLive,
        RecordingStatus.waitingForCloudSlot,
        RecordingStatus.recording,
        RecordingStatus.processing,
        RecordingStatus.uploading,
        RecordingStatus.completed,
        RecordingStatus.failed,
        RecordingStatus.stopRequested,
        RecordingStatus.stopped,
        RecordingStatus.missedNoCloudSlot,
      ]),
    );
    expect(find.text('@ada_live · LIVE now'), findsOneWidget);
  });

  testWidgets('Recordings library supports search and the Failed filter', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('nav-recordings')));
    await pumpFrames(tester);

    await tester.tap(find.byKey(const ValueKey<String>('recordings-search')));
    await pumpFrames(tester);
    await tester.enterText(find.byType(TextField), 'studio');
    await tester.pump();
    expect(find.text('@studio_north'), findsWidgets);
    expect(find.text('@minh_streams'), findsNothing);

    await tester.tap(find.byTooltip('Close search'));
    await pumpFrames(tester);
    expect(find.text('@minh_streams'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey<String>('recordings-filter-failed')),
    );
    await pumpFrames(tester);
    expect(find.text('Failed recordings are never charged.'), findsOneWidget);
    expect(find.text('@studio_north'), findsWidgets);
    expect(find.text('@minh_streams'), findsNothing);
  });

  testWidgets('active recording Stop action follows canStop flag', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('nav-recordings')));
    await pumpFrames(tester);

    GoRouter.of(
      tester.element(find.byType(RecordingsScreen)),
    ).push(AppRoutes.recordingDetail('rec_001'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Recording now'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('player-stop')),
    );
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey<String>('player-stop')));
    await pumpFrames(tester);

    expect(find.text('Stop cloud recording?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Stop recording').last);
    await tester.pump(const Duration(milliseconds: 200));
    await pumpFrames(tester);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Processing your recording…'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('player-stop')), findsNothing);
  });

  testWidgets('failed recording shows why and can be deleted', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('nav-recordings')));
    await pumpFrames(tester);

    GoRouter.of(
      tester.element(find.byType(RecordingsScreen)),
    ).push(AppRoutes.recordingDetail('rec_003'));
    await pumpFrames(tester);

    expect(find.text('This recording couldn’t be saved'), findsOneWidget);
    expect(
      find.text('The source connection ended before recording completed.'),
      findsOneWidget,
    );
    expect(find.text('Report a problem'), findsOneWidget);
    expect(find.text('Stop recording'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('player-delete-button')),
    );
    await pumpFrames(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('player-delete-button')),
    );
    await pumpFrames(tester);
    expect(find.text('Delete this recording?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('recording-delete-confirm')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await pumpFrames(tester);

    expect(find.byType(RecordingDetailScreen), findsNothing);
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(RecordingsScreen)),
    );
    final List<RecordingSummary> items = await container.read(
      recordingLibraryProvider.future,
    );
    expect(items.where((RecordingSummary r) => r.id == 'rec_003'), isEmpty);
  });

  test(
    'persists theme and locale across settings controller recreation',
    () async {
      final Map<String, String> values = <String, String>{};
      final MemoryAppSettingsStore store = MemoryAppSettingsStore(values);
      final AppSettingsController first = AppSettingsController(store: store);

      first.setLocale(const Locale('vi'));
      first.setThemeMode(ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);

      final AppSettingsController restored = AppSettingsController(
        store: store,
      );
      await restored.initialize();

      expect(restored.locale.languageCode, 'vi');
      expect(restored.themeMode, ThemeMode.dark);

      first.dispose();
      restored.dispose();
    },
  );

  testWidgets('renders the profile with display name and email', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('nav-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('account-edit')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Alex Nguyen'), findsWidgets);
    expect(find.text('alex@example.com'), findsWidgets);
    expect(find.text('Signed in with email'), findsOneWidget);
  });

  testWidgets('changes language and theme from the Account tab', (
    WidgetTester tester,
  ) async {
    final AppSettingsController settings = AppSettingsController();

    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), settings: settings),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('nav-account')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('account-language')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey<String>('account-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('account-language')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('account-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vietnamese'));
    await tester.pumpAndSettle();

    expect(settings.locale.languageCode, 'vi');
    expect(find.text('Ngôn ngữ'), findsWidgets);

    GoRouter.of(tester.element(find.text('Ngôn ngữ').first)).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('account-theme')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('account-theme')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tối'));
    await tester.pumpAndSettle();

    expect(settings.themeMode, ThemeMode.dark);
    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('signs out from the Account tab after confirming', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('nav-account')));
    await tester.pumpAndSettle();

    final Finder signOut = find.byKey(
      const ValueKey<String>('account-sign-out'),
    );
    await tester.scrollUntilVisible(
      signOut,
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey<String>('account-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(signOut);
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('account-sign-out-confirm')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets(
    'delete account needs DELETE typed, then shows the confirmation',
    (WidgetTester tester) async {
      await tester.pumpWidget(SaveStreamApp(config: testConfig()));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('nav-account')));
      await tester.pumpAndSettle();
      GoRouter.of(
        tester.element(find.byType(AccountScreen)),
      ).push(AppRoutes.deleteAccount);
      await tester.pumpAndSettle();

      final Finder delete = find.byKey(
        const ValueKey<String>('delete-account-confirm'),
      );
      expect(tester.widget<SsV2Button>(delete).onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey<String>('delete-confirm-field')),
        'delete',
      );
      await tester.pump();
      await tester.tap(delete);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('Your account is deleted'), findsOneWidget);
      expect(find.textContaining('alex@example.com'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('account-deleted-close')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsWidgets);
    },
  );

  testWidgets('supports loading and empty mock scenarios', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), mockScenario: MockScenario.loading),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('nav-channels')));
    await tester.pump();

    expect(find.byType(SsV2Skeleton), findsWidgets);

    await tester.pumpWidget(
      SaveStreamApp(
        key: const ValueKey<String>('empty-app'),
        config: testConfig(),
        mockScenario: MockScenario.empty,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('nav-channels')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('No channels yet'), findsOneWidget);
  });

  testWidgets('switches locale and theme at runtime', (
    WidgetTester tester,
  ) async {
    final AppSettingsController settings = AppSettingsController();

    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), settings: settings),
    );
    await tester.pump();

    settings.setLocale(const Locale('vi'));
    settings.setThemeMode(ThemeMode.dark);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Trang chủ'), findsWidgets);
    expect(find.text('Kênh'), findsWidgets);

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.dark);
  });
}

/// Pumps a few frames. The Recordings tab has spinners and running timers
/// (as drawn), so it never "settles".
Future<void> pumpFrames(WidgetTester tester) async {
  await tester.pump();
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}
