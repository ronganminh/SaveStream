import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/core/mock/mock_scenario.dart';

void main() {
  AppConfig testConfig() {
    return AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    );
  }

  testWidgets('boots the Phase 2 shell with four destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();

    expect(find.text('SaveStream'), findsOneWidget);
    expect(find.text('Mobile foundation is ready'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Channels'), findsOneWidget);
    expect(find.text('Recordings'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('auth guard redirects unauthenticated session to sign in', (
    WidgetTester tester,
  ) async {
    final AppSessionController session = AppSessionController(
      authStatus: AppAuthStatus.unauthenticated,
    );

    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), session: session),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Enter preview app'), findsOneWidget);
  });

  testWidgets('onboarding guard has priority over auth guard', (
    WidgetTester tester,
  ) async {
    final AppSessionController session = AppSessionController(
      hasCompletedOnboarding: false,
      authStatus: AppAuthStatus.unauthenticated,
    );

    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), session: session),
    );
    await tester.pumpAndSettle();

    expect(find.text('Onboarding'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
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
