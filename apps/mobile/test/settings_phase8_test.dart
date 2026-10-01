import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/core/mock/mock_scenario.dart';
import 'package:savestream_mobile/features/settings/presentation/profile_screen.dart';
import 'package:savestream_mobile/features/settings/presentation/settings_info_screen.dart';

void main() {
  AppConfig testConfig() {
    return AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    );
  }

  Future<void> openSettings(
    WidgetTester tester, {
    AppSettingsController? settings,
    AppSessionController? session,
    MockScenario mockScenario = MockScenario.success,
  }) async {
    await tester.pumpWidget(
      SaveStreamApp(
        config: testConfig(),
        settings: settings,
        session: session,
        mockScenario: mockScenario,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders Phase 8 empty profile as unverified', (
    WidgetTester tester,
  ) async {
    await openSettings(tester, mockScenario: MockScenario.empty);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('SaveStream user'), findsOneWidget);
    expect(find.text('alex@example.com'), findsWidgets);
    expect(find.text('Email not verified'), findsOneWidget);
    expect(find.text('Not verified'), findsOneWidget);
  });

  testWidgets('switches between System Light and Dark from Theme screen', (
    WidgetTester tester,
  ) async {
    final AppSettingsController settings = AppSettingsController();

    await openSettings(tester, settings: settings);
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(settings.themeMode, ThemeMode.dark);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await tester.tap(find.text('Light'));
    await tester.pump();
    expect(settings.themeMode, ThemeMode.light);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );

    await tester.tap(find.text('System'));
    await tester.pump();
    expect(settings.themeMode, ThemeMode.system);
  });

  testWidgets('switches Vietnamese and English from Language screen', (
    WidgetTester tester,
  ) async {
    final AppSettingsController settings = AppSettingsController();

    await openSettings(tester, settings: settings);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('Vietnamese'), findsOneWidget);

    await tester.tap(find.text('Vietnamese'));
    await tester.pumpAndSettle();
    expect(settings.locale.languageCode, 'vi');
    expect(find.text('Ngôn ngữ'), findsOneWidget);

    await tester.tap(find.text('Tiếng Anh'));
    await tester.pumpAndSettle();
    expect(settings.locale.languageCode, 'en');
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('opens Notifications Privacy and Terms settings entries', (
    WidgetTester tester,
  ) async {
    await openSettings(tester);

    Future<void> openInfo(String label) async {
      await tester.scrollUntilVisible(
        find.text(label),
        260,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsInfoScreen), findsOneWidget);
      expect(find.text(label), findsWidgets);

      final BuildContext context = tester.element(
        find.byType(SettingsInfoScreen),
      );
      GoRouter.of(context).pop();
      await tester.pumpAndSettle();
    }

    await openInfo('Notifications');
    await openInfo('Privacy Policy');
    await openInfo('Terms of Use');
  });

  testWidgets('cancelling Delete Account keeps the session authenticated', (
    WidgetTester tester,
  ) async {
    final AppSessionController session = AppSessionController();

    await openSettings(tester, session: session);
    await tester.scrollUntilVisible(
      find.text('Delete account'),
      320,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(session.isAuthenticated, isTrue);
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Settings'), findsWidgets);
  });
}
