import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/core/mock/mock_scenario.dart';
import 'package:savestream_mobile/core/widgets/savestream_widgets.dart';
import 'package:savestream_mobile/features/auth/data/repositories/mock_auth_repository.dart';

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
    await tester.enterText(fields.at(1), 'Password123!');
  }

  testWidgets('boots the Phase 4 shell with four destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();

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

  testWidgets('renders retryable home repository errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), mockScenario: MockScenario.error),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
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

    await enterSignInCredentials(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

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
    await tester.enterText(fields.at(1), 'Password123!');
    await tester.enterText(fields.at(2), 'Password123!');
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

  testWidgets('supports loading and empty mock scenarios', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), mockScenario: MockScenario.loading),
    );
    await tester.pump();

    await tester.tap(find.text('Channels'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

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

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Kênh'), findsOneWidget);

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.dark);
  });
}
