import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/router/app_routes.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/core/storage/app_settings_store.dart';
import 'package:savestream_mobile/features/auth/presentation/verify_email_screen.dart';
import 'package:savestream_mobile/features/devices/domain/models/device_registration.dart';
import 'package:savestream_mobile/features/onboarding/presentation/intro_watch_detect_screen.dart';
import 'package:savestream_mobile/platform/fakes/fake_device_info_service.dart';
import 'package:savestream_mobile/platform/platform_providers.dart';

void main() {
  AppConfig config() {
    return AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    );
  }

  test('A1 persists the introduction-complete flag', () async {
    final MemoryAppSettingsStore store = MemoryAppSettingsStore();
    final AppSettingsController first = AppSettingsController(
      hasCompletedIntro: false,
      store: store,
    );

    expect(first.hasCompletedIntro, isFalse);
    await first.markIntroCompleted();
    expect(first.hasCompletedIntro, isTrue);

    final AppSettingsController restored = AppSettingsController(
      hasCompletedIntro: false,
      store: store,
    );
    await restored.initialize();
    expect(restored.hasCompletedIntro, isTrue);
  });

  testWidgets('A04 password rule changes when eight characters are entered', (
    WidgetTester tester,
  ) async {
    final AppSessionController session = AppSessionController(
      hasCompletedOnboarding: true,
      authStatus: AppAuthStatus.unauthenticated,
    );
    await tester.pumpWidget(SaveStreamApp(config: config(), session: session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('At least 8 characters'), findsOneWidget);
    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(2), '12345678');
    await tester.pump();

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('A1 first-run auth and onboarding reaches Home', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final MemoryAppSettingsStore store = MemoryAppSettingsStore();
    final AppSettingsController settings = AppSettingsController(
      hasCompletedIntro: false,
      store: store,
    );
    final AppSessionController session = AppSessionController(
      hasCompletedOnboarding: false,
      authStatus: AppAuthStatus.unauthenticated,
    );

    await tester.pumpWidget(
      SaveStreamApp(config: config(), settings: settings, session: session),
    );
    await tester.pumpAndSettle();

    expect(find.text('Never miss a LIVE.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    final Finder registerFields = find.byType(TextFormField);
    await tester.enterText(registerFields.at(0), 'Alex Nguyen');
    await tester.enterText(registerFields.at(1), 'new@example.com');
    await tester.enterText(registerFields.at(2), 'password-123');
    final Finder create = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyEmailScreen), findsOneWidget);
    final GoRouter router = GoRouter.of(
      tester.element(find.byType(VerifyEmailScreen)),
    );
    router.go(
      AppRoutes.verifyEmailLocation(token: 'verification-token-123456'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final Finder signInFields = find.byType(TextFormField);
    await tester.enterText(signInFields.at(0), 'new@example.com');
    await tester.enterText(signInFields.at(1), 'password-123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.byType(IntroWatchDetectScreen), findsOneWidget);
    final Finder watchContinue = find.widgetWithText(FilledButton, 'Continue');
    await tester.ensureVisible(watchContinue);
    await tester.tap(watchContinue);
    await tester.pumpAndSettle();

    expect(find.text('Record on your device or in the cloud'), findsOneWidget);
    final Finder storageContinue = find.widgetWithText(
      FilledButton,
      'Continue',
    );
    await tester.ensureVisible(storageContinue);
    await tester.tap(storageContinue);
    await tester.pumpAndSettle();

    expect(
      find.text('Turn on notifications to know when a creator is LIVE'),
      findsOneWidget,
    );
    final Finder enableNotifications = find.widgetWithText(
      FilledButton,
      'Turn on notifications',
    );
    await tester.ensureVisible(enableNotifications);
    await tester.tap(enableNotifications);
    await tester.pumpAndSettle();

    expect(find.text('Allow recording while you switch apps'), findsOneWidget);
    final Finder androidLater = find.widgetWithText(OutlinedButton, 'Later');
    await tester.ensureVisible(androidLater);
    await tester.tap(androidLater);
    await tester.pumpAndSettle();

    expect(find.text('Add your first creator'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    final Finder add = find.widgetWithText(FilledButton, 'Add & follow');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Linastudio added'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Go to Home'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));

    expect(settings.hasCompletedIntro, isTrue);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('A09 follows the iOS onboarding branch', (
    WidgetTester tester,
  ) async {
    final AppSettingsController settings = AppSettingsController(
      hasCompletedIntro: false,
    );
    final AppSessionController session = AppSessionController(
      hasCompletedOnboarding: true,
      authStatus: AppAuthStatus.authenticated,
    );

    await tester.pumpWidget(
      SaveStreamApp(
        config: config(),
        settings: settings,
        session: session,
        extraOverrides: [
          deviceInfoServiceProvider.overrideWithValue(
            const FakeDeviceInfoService(platform: DevicePlatform.ios),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IntroWatchDetectScreen), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(
      find.text('Turn on notifications to know when a creator is LIVE'),
      findsOneWidget,
    );
    final Finder iosLater = find.widgetWithText(OutlinedButton, 'Later');
    await tester.ensureVisible(iosLater);
    await tester.tap(iosLater);
    await tester.pumpAndSettle();

    expect(
      find.text('On iPhone, keep SaveStream open while recording'),
      findsOneWidget,
    );
  });
}
