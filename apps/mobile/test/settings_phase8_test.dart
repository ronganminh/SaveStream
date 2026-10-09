import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/router/app_routes.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/core/mock/mock_scenario.dart';
import 'package:savestream_mobile/features/entitlement/data/repositories/mock_entitlement_repository.dart';
import 'package:savestream_mobile/features/entitlement/presentation/entitlement_providers.dart';
import 'package:savestream_mobile/features/settings/presentation/legal_link_screen.dart';
import 'package:savestream_mobile/features/settings/presentation/notification_settings_screen.dart';
import 'package:savestream_mobile/features/settings/presentation/profile_screen.dart';

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

    final BuildContext settingsContext = tester.element(
      find.text('Settings').first,
    );
    GoRouter.of(settingsContext).push(AppRoutes.profile);
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
    final BuildContext settingsContext = tester.element(
      find.text('Settings').first,
    );
    GoRouter.of(settingsContext).push(AppRoutes.theme);
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
    final BuildContext settingsContext = tester.element(
      find.text('Settings').first,
    );
    GoRouter.of(settingsContext).push(AppRoutes.language);
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

    Future<void> openInfo(String route, String label, Type screen) async {
      final BuildContext settingsContext = tester.element(
        find.text('Settings').first,
      );
      GoRouter.of(settingsContext).push(route);
      await tester.pumpAndSettle();

      expect(find.byType(screen), findsOneWidget);
      expect(find.text(label), findsWidgets);

      final BuildContext context = tester.element(find.byType(screen));
      GoRouter.of(context).pop();
      await tester.pumpAndSettle();
    }

    await openInfo(
      AppRoutes.notifications,
      'Notifications',
      NotificationSettingsScreen,
    );
    expect(find.text('https://savestream.online/privacy'), findsNothing);
    await openInfo(AppRoutes.privacy, 'Privacy Policy', LegalLinkScreen);
    await openInfo(AppRoutes.terms, 'Terms of Use', LegalLinkScreen);
  });

  testWidgets('cancelling Delete Account keeps the session authenticated', (
    WidgetTester tester,
  ) async {
    final AppSessionController session = AppSessionController();

    await openSettings(tester, session: session);
    final BuildContext settingsContext = tester.element(
      find.text('Settings').first,
    );
    GoRouter.of(settingsContext).push(AppRoutes.deleteAccount);
    await tester.pumpAndSettle();

    expect(find.text('What will be deleted'), findsOneWidget);
    GoRouter.of(tester.element(find.text('What will be deleted'))).pop();
    await tester.pumpAndSettle();

    expect(session.isAuthenticated, isTrue);
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('Pro settings show cloud balance and unlimited Local recording', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(
        config: testConfig(),
        extraOverrides: [
          entitlementRepositoryProvider.overrideWithValue(
            const MockEntitlementRepository(
              MockBehavior(
                scenario: MockScenario.success,
                latency: Duration.zero,
              ),
              state: EntitlementMockState.pro,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('SaveStream Pro'), findsOneWidget);
    expect(find.textContaining('133 hours'), findsOneWidget);
    expect(find.textContaining('ads'), findsNothing);
    expect(find.text('Local recording'), findsOneWidget);
    expect(find.text('Unlimited on this device'), findsWidgets);

    final Text email = tester.widget<Text>(find.text('alex@example.com').first);
    expect(email.maxLines, 1);
    expect(email.overflow, TextOverflow.ellipsis);
  });
}
