import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/core/mock/mock_scenario.dart';
import 'package:savestream_mobile/core/storage/app_settings_store.dart';
import 'package:savestream_mobile/core/widgets/savestream_widgets.dart';
import 'package:savestream_mobile/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:savestream_mobile/features/billing/domain/models/billing_models.dart';
import 'package:savestream_mobile/features/billing/presentation/billing_screen.dart';
import 'package:savestream_mobile/features/billing/presentation/controllers/billing_providers.dart';
import 'package:savestream_mobile/features/credits/presentation/credits_screen.dart';
import 'package:savestream_mobile/features/home/presentation/controllers/home_dashboard_controller.dart';
import 'package:savestream_mobile/features/home/presentation/home_screen.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/recordings/presentation/controllers/recording_providers.dart';
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

    expect(find.text('SaveStream'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Channels'), findsOneWidget);
    expect(find.text('Recordings'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('renders the aggregated home dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Welcome back, Alex'), findsOneWidget);
    expect(find.text('Available credit'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('Recording now'), findsOneWidget);
    expect(find.text('Credit is running low'), findsOneWidget);
    expect(find.text('A recording needs attention'), findsOneWidget);
    expect(find.text('12.6 / 50 recording hours'), findsOneWidget);
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

    expect(find.text('Add your first channel'), findsOneWidget);
    expect(find.text('Credit is running low'), findsNothing);
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

  testWidgets('onboarding requires recording permission confirmation', (
    WidgetTester tester,
  ) async {
    final AppSessionController session = signedOutSession(
      hasCompletedOnboarding: false,
    );

    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), session: session),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to SaveStream'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Recording continues in the cloud'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Record responsibly'), findsOneWidget);

    final FilledButton disabledStart = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Get started'),
    );
    expect(disabledStart.onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    final Finder getStartedButton = find.widgetWithText(
      FilledButton,
      'Get started',
    );
    await tester.ensureVisible(getStartedButton);
    await tester.pumpAndSettle();
    await tester.tap(getStartedButton);
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
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

  testWidgets('registers then verifies email through mock auth', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), session: signedOutSession()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'new@example.com');
    await tester.enterText(fields.at(1), 'x');
    await tester.enterText(fields.at(2), 'x');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    final Finder createAccountButton = find.widgetWithText(
      FilledButton,
      'Create account',
    );
    await tester.ensureVisible(createAccountButton);
    await tester.pumpAndSettle();
    await tester.tap(createAccountButton);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Verify email'), findsWidgets);
    expect(find.text('new@example.com'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Verify email'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
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

  testWidgets('navigates mock channel detail and preserves tab stack', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();

    await tester.tap(find.text('Channels'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Ada Live'), findsOneWidget);
    await tester.tap(find.text('Ada Live'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Channel detail'), findsOneWidget);
    expect(find.text('@ada_live'), findsOneWidget);

    await tester.tap(find.text('Recordings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Channels'));
    await tester.pump();

    expect(find.text('Channel detail'), findsOneWidget);
  });

  testWidgets('renders all Phase 5 Watch status variants', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Channels'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Ada Live'), findsOneWidget);
    expect(find.text('Nora Shop'), findsOneWidget);

    for (final String reason in <String>[
      'Monitoring paused because available credit is insufficient.',
      'Monitoring paused after a Watch error. Review and resume when ready.',
      'Monitoring is paused until you resume it.',
      'This Watch is disabled.',
    ]) {
      await tester.scrollUntilVisible(
        find.text(reason),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(reason), findsOneWidget);
    }
  });

  testWidgets('Add Channel requires authorization then creates a Watch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Channels'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byTooltip('Add channel').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '@fresh_creator');
    final Finder addButton = find.widgetWithText(
      FilledButton,
      'Add & start monitoring',
    );
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pump();

    expect(
      find.text(
        'Confirm that you are authorized to record this stream before continuing.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(addButton);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.text('Channel detail'), findsOneWidget);
    expect(find.text('Fresh Creator'), findsOneWidget);
    expect(find.text('@fresh_creator'), findsOneWidget);
  });

  testWidgets('Channel detail can pause and resume monitoring', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Channels'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Ada Live'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Monitoring settings'), findsOneWidget);
    expect(find.text('Pause monitoring'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Pause monitoring'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume monitoring'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Resume monitoring'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Pause monitoring'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Latest recording'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Latest recording'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Recording history'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Recording history'), findsOneWidget);
  });

  testWidgets('Recordings pagination exposes all lifecycle statuses', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Recordings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(RecordingsScreen)),
    );
    final RecordingListController controller = container.read(
      recordingListControllerProvider.notifier,
    );

    final Future<void> secondPage = controller.loadMore();
    await tester.pump(const Duration(milliseconds: 200));
    await secondPage;

    final Future<void> thirdPage = controller.loadMore();
    await tester.pump(const Duration(milliseconds: 200));
    await thirdPage;
    await tester.pump();

    final Set<RecordingStatus> statuses = container
        .read(recordingListControllerProvider)
        .requireValue
        .items
        .map((RecordingSummary item) => item.status)
        .toSet();

    expect(statuses, containsAll(RecordingStatus.values));
  });

  testWidgets('Recordings filters completed and failed states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Recordings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.text('Minh Streams'), findsOneWidget);
    expect(find.text('Studio North'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Failed'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.text('Studio North'), findsOneWidget);
    expect(find.text('Minh Streams'), findsNothing);
  });

  testWidgets('active recording Stop action follows canStop flag', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Recordings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

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
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.drag(find.byType(Scrollable).last, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.text('Stop requested'), findsWidgets);
    expect(find.text('Stop recording'), findsNothing);
  });

  testWidgets('failed recording exposes Retry and Delete action flags', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Recordings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Failed'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    await tester.tap(find.text('Studio North'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Recording error'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Retry recording'),
      320,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Retry recording'), findsOneWidget);
    expect(find.text('Delete recording'), findsOneWidget);
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
        .read(recordingDetailProvider('rec_003'))
        .value;

    expect(updated?.status, RecordingStatus.queued);
    expect(updated?.actions.canRetry, isFalse);
  });

  testWidgets('renders Phase 7 credit balances usage and transactions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.tap(find.text('Credits'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(CreditsScreen), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('Posted'), findsOneWidget);
    expect(find.text('7.4'), findsOneWidget);
    expect(find.text('Reserved'), findsOneWidget);
    expect(find.text('2.6'), findsOneWidget);
    expect(find.text('Available credit is low'), findsOneWidget);
    expect(find.text('Recording usage'), findsOneWidget);
    expect(find.text('12.6'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Recent transactions'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Recent transactions'), findsOneWidget);
  });

  testWidgets('renders Phase 7 empty credit transaction state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), mockScenario: MockScenario.empty),
    );
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.tap(find.text('Credits'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(CreditsScreen), findsOneWidget);
    expect(find.text('0.0'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('No transactions yet'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('No transactions yet'), findsOneWidget);
  });

  testWidgets('billing waits for backend status before showing paid', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.tap(find.text('Billing'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(BillingScreen), findsOneWidget);
    expect(find.text('25 credits'), findsWidgets);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(BillingScreen)),
    );
    final Set<PaymentOrderStatus> statuses = container
        .read(billingSnapshotProvider)
        .requireValue
        .orders
        .map((PaymentOrder order) => order.status)
        .toSet();
    expect(
      statuses,
      containsAll(<PaymentOrderStatus>[
        PaymentOrderStatus.paid,
        PaymentOrderStatus.failed,
        PaymentOrderStatus.cancelled,
        PaymentOrderStatus.expired,
      ]),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Buy package').first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Check payment status'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.widgetWithText(SsStatusChip, 'Pending'), findsOneWidget);
    expect(
      find.textContaining('Returning from checkout does not mark it paid'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Check payment status'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Check payment status'),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final BillingSnapshot refreshed = container
        .read(billingSnapshotProvider)
        .requireValue;
    expect(refreshed.orders.first.status, PaymentOrderStatus.paid);
  });

  test('persists theme and locale across settings controller recreation', () async {
    final Map<String, String> values = <String, String>{};
    final MemoryAppSettingsStore store = MemoryAppSettingsStore(values);
    final AppSettingsController first = AppSettingsController(store: store);

    first.setLocale(const Locale('vi'));
    first.setThemeMode(ThemeMode.dark);
    await Future<void>.delayed(Duration.zero);

    final AppSettingsController restored = AppSettingsController(store: store);
    await restored.initialize();

    expect(restored.locale.languageCode, 'vi');
    expect(restored.themeMode, ThemeMode.dark);

    first.dispose();
    restored.dispose();
  });

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

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vietnamese'));
    await tester.pumpAndSettle();

    expect(settings.locale.languageCode, 'vi');
    expect(find.text('Ngôn ngữ'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giao diện'));
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

    await tester.scrollUntilVisible(
      find.text('Log out'),
      320,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Log out'));
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

    await tester.scrollUntilVisible(
      find.text('Delete account'),
      320,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Delete account'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
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

    await tester.tap(find.text('Channels'));
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
    await tester.tap(find.text('Channels'));
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

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Kênh'), findsOneWidget);

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.dark);
  });
}
