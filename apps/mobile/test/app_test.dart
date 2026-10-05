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
import 'package:savestream_mobile/core/widgets/savestream_widgets.dart';
import 'package:savestream_mobile/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:savestream_mobile/features/auth/presentation/verify_email_screen.dart';
import 'package:savestream_mobile/features/home/presentation/controllers/home_dashboard_controller.dart';
import 'package:savestream_mobile/features/home/presentation/home_screen.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/recordings/presentation/controllers/recording_library_controller.dart';
import 'package:savestream_mobile/features/recordings/presentation/controllers/recording_providers.dart';
import 'package:savestream_mobile/features/recordings/presentation/models/recording_library_item.dart';
import 'package:savestream_mobile/features/recordings/presentation/recording_detail_screen.dart';
import 'package:savestream_mobile/features/recordings/presentation/recordings_screen.dart';
import 'package:savestream_mobile/features/settings/presentation/profile_screen.dart';

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

    // The Home tab opens with the V2 greeting header instead of an app bar.
    expect(find.byType(SsLargeHeader), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });

  testWidgets('renders the aggregated home dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Welcome back, Alex'), findsOneWidget);
    expect(find.text('Free minutes today'), findsOneWidget);
    expect(find.text('6 / 10 minutes remaining'), findsOneWidget);
    expect(find.text('Watching 8/3'), findsOneWidget);
    expect(find.text('Available credit'), findsNothing);
    expect(find.textContaining('credit', findRichText: true), findsNothing);
    expect(find.text('Ada Live'), findsWidgets);
  });

  testWidgets('renders skeleton while the home dashboard is loading', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), mockScenario: MockScenario.loading),
    );
    await tester.pump();

    expect(find.byType(SsSkeleton), findsWidgets);
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

    expect(find.text('Add a creator to get started'), findsOneWidget);
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

    expect(find.text('Never miss a LIVE.'), findsOneWidget);
    expect(find.text('Theme: System'), findsOneWidget);

    // Language can be switched before signing in.
    await tester.ensureVisible(find.text('English'));
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Không bỏ lỡ LIVE nào.'), findsOneWidget);
    await tester.ensureVisible(find.text('Tiếng Việt'));
    await tester.tap(find.text('Tiếng Việt'));
    await tester.pumpAndSettle();

    final Finder createAccount = find.widgetWithText(
      FilledButton,
      'Create account',
    );
    await tester.ensureVisible(createAccount);
    await tester.tap(createAccount);
    await tester.pumpAndSettle();

    expect(session.hasCompletedOnboarding, isTrue);
    expect(find.text('Never miss a LIVE.'), findsNothing);
    expect(find.byType(TextFormField), findsWidgets);
  });

  testWidgets('sign in validates required fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), session: signedOutSession()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
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

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Welcome back, Alex'), findsOneWidget);
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

    expect(find.text('The email or password is incorrect.'), findsOneWidget);
  });

  testWidgets('registers then verifies email and returns to sign in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), session: signedOutSession()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Alex Nguyen');
    await tester.enterText(fields.at(1), 'new@example.com');
    await tester.enterText(fields.at(2), 'password-123');

    final Finder createAccountButton = find.widgetWithText(
      FilledButton,
      'Create account',
    );
    await tester.ensureVisible(createAccountButton);
    await tester.pumpAndSettle();
    await tester.tap(createAccountButton);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Verify email'), findsOneWidget);
    expect(find.textContaining('new@example.com'), findsOneWidget);

    final GoRouter router = GoRouter.of(
      tester.element(find.byType(VerifyEmailScreen)),
    );
    router.go(
      AppRoutes.verifyEmailLocation(token: 'verification-token-123456'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
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

    expect(find.text('Check your email'), findsOneWidget);
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
      tester.element(find.text('Check your email')),
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

    expect(find.text('New password saved'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('navigates mock channel detail and preserves tab stack', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Ada Live'), findsOneWidget);
    await tester.tap(find.text('Ada Live'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Channel detail'), findsOneWidget);
    expect(find.text('@ada_live'), findsOneWidget);

    await tester.tap(find.text('Recordings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(find.text('Channel detail'), findsOneWidget);
  });

  testWidgets('renders V2 Watching filters and legacy Free limit', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Ada Live'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    expect(
      find.textContaining('You already have 8 creators from an older plan'),
      findsWidgets,
    );
  });

  testWidgets('legacy Free creator list is preserved but adding is blocked', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byTooltip('Add creator').first);
    await tester.pumpAndSettle();

    expect(find.text('Watching is full'), findsOneWidget);
    expect(
      find.textContaining('You already have 8 creators from an older plan'),
      findsWidgets,
    );
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('Channel detail can pause and resume monitoring', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Ada Live'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Channel detail'), findsOneWidget);
    expect(find.text('Pause monitoring'), findsOneWidget);
    expect(find.text('Notify when LIVE'), findsOneWidget);

    final Finder pause = find.widgetWithText(
      OutlinedButton,
      'Pause monitoring',
    );
    final OutlinedButton pauseButton = tester.widget<OutlinedButton>(pause);
    pauseButton.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('PAUSED'), findsWidgets);

    final Finder resume = find.widgetWithText(
      OutlinedButton,
      'Resume monitoring',
    );
    final OutlinedButton resumeButton = tester.widget<OutlinedButton>(resume);
    resumeButton.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('Recent recording'), findsOneWidget);
  });

  testWidgets('Recordings merged library exposes cloud lifecycle statuses', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Recordings'));
    await tester.pumpAndSettle();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(RecordingsScreen)),
    );
    final List<RecordingLibraryItem> items = await container.read(
      recordingLibraryProvider.future,
    );
    final Set<RecordingStatus> statuses = items
        .map((RecordingLibraryItem item) => item.status)
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
  });

  testWidgets('Recordings merged library supports search and storage filter', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Recordings'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Studio North');
    await tester.pump();
    expect(find.text('Studio North'), findsWidgets);
    expect(find.text('Minh Streams'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cloud'));
    await tester.pump();
    expect(find.text('Cloud'), findsWidgets);
  });

  testWidgets('active recording Stop action follows canStop flag', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Recordings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ada Live'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.scrollUntilVisible(
      find.text('Stop recording'),
      320,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Stop recording'), findsOneWidget);
    expect(find.text('Retry recording'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Stop recording'));
    await tester.pumpAndSettle();

    expect(find.text('Stop cloud recording?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Stop recording').last);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.drag(find.byType(Scrollable).last, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.text('Stop requested'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Stop recording'), findsNothing);
  });

  testWidgets('failed recording exposes Retry and Delete action flags', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Recordings'));
    await tester.pumpAndSettle();

    final GoRouter router = GoRouter.of(
      tester.element(find.byType(RecordingsScreen)),
    );
    router.go(AppRoutes.recordingDetail('rec_003'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Recording error'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Retry recording'),
      320,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Retry recording'), findsOneWidget);
    expect(find.text('Delete cloud recording'), findsOneWidget);
    expect(find.text('Stop recording'), findsNothing);

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Retry recording'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(RecordingDetailScreen)),
    );
    final RecordingSummary? updated = container
        .read(recordingRealtimeProvider('rec_003'))
        .value;

    expect(updated?.status, RecordingStatus.queued);
    expect(updated?.actions.canRetry, isFalse);
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

  testWidgets('renders Phase 8 profile verification state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Alex Nguyen'), findsOneWidget);
    expect(find.text('alex@example.com'), findsWidgets);
    expect(find.text('Email verified'), findsOneWidget);
  });

  testWidgets('changes language and theme through Phase 8 settings UI', (
    WidgetTester tester,
  ) async {
    final AppSettingsController settings = AppSettingsController();

    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), settings: settings),
    );
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pump();

    final BuildContext settingsContext = tester.element(
      find.text('Settings').first,
    );
    GoRouter.of(settingsContext).push(AppRoutes.language);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vietnamese'));
    await tester.pumpAndSettle();

    expect(settings.locale.languageCode, 'vi');
    expect(find.text('Ngôn ngữ'), findsWidgets);

    final BuildContext languageContext = tester.element(
      find.text('Ngôn ngữ').first,
    );
    GoRouter.of(languageContext).pop();
    await tester.pumpAndSettle();

    final BuildContext localizedSettingsContext = tester.element(
      find.text('Cài đặt').first,
    );
    GoRouter.of(localizedSettingsContext).push(AppRoutes.theme);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tối'));
    await tester.pumpAndSettle();

    expect(settings.themeMode, ThemeMode.dark);
    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('logs out through Phase 8 settings account action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pump();

    final BuildContext settingsContext = tester.element(
      find.text('Settings').first,
    );
    GoRouter.of(settingsContext).push(AppRoutes.securityAccount);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('delete account requires destructive confirmation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pump();

    final BuildContext settingsContext = tester.element(
      find.text('Settings').first,
    );
    GoRouter.of(settingsContext).push(AppRoutes.deleteAccount);
    await tester.pumpAndSettle();

    expect(find.text('What will be deleted'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm permanent deletion'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Delete account permanently'),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('supports loading and empty mock scenarios', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), mockScenario: MockScenario.loading),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(find.byType(SsSkeleton), findsWidgets);

    await tester.pumpWidget(
      SaveStreamApp(
        key: const ValueKey<String>('empty-app'),
        config: testConfig(),
        mockScenario: MockScenario.empty,
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Add a creator to get started'), findsOneWidget);
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

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Theo dõi'), findsWidgets);

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.dark);
  });
}
