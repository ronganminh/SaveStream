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

  testWidgets(
    'A04 password helper turns into an error under eight characters',
    (WidgetTester tester) async {
      final AppSessionController session = AppSessionController(
        hasCompletedOnboarding: true,
        authStatus: AppAuthStatus.unauthenticated,
      );
      await tester.pumpWidget(
        SaveStreamApp(config: config(), session: session),
      );
      await tester.pumpAndSettle();

      final createLink = find.text('Create an account');
      await tester.ensureVisible(createLink);
      await tester.tap(createLink);
      await tester.pumpAndSettle();

      expect(find.text('At least 8 characters'), findsOneWidget);
      final Finder fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'new@example.com');
      await tester.enterText(fields.at(1), '1234567');
      final Finder create = find.widgetWithText(FilledButton, 'Create account');
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pump();

      expect(find.text('Use at least 8 characters'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsNothing);

      await tester.enterText(fields.at(1), '12345678');
      await tester.pump();
      expect(find.text('Use at least 8 characters'), findsNothing);
      expect(find.text('At least 8 characters'), findsOneWidget);
    },
  );

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

    expect(find.text('Your LIVEs, backed up automatically.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    final Finder registerFields = find.byType(TextFormField);
    await tester.enterText(registerFields.at(0), 'new@example.com');
    await tester.enterText(registerFields.at(1), 'password-123');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
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

    expect(find.text('Email verified'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Go to Home'));
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

    expect(
      find.text('Turn on notifications to know when your channel is LIVE'),
      findsOneWidget,
    );
    final Finder enableNotifications = find.widgetWithText(
      FilledButton,
      'Turn on notifications',
    );
    await tester.ensureVisible(enableNotifications);
    await tester.tap(enableNotifications);
    await tester.pumpAndSettle();

    expect(find.text('Add your TikTok channel'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    final Finder add = find.widgetWithText(FilledButton, 'Add channel');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Linastudio added'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Go to Home'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));

    expect(settings.hasCompletedIntro, isTrue);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('A09 skips platform recording screens on iOS', (
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
      find.text('Turn on notifications to know when your channel is LIVE'),
      findsOneWidget,
    );
    final Finder iosLater = find.widgetWithText(OutlinedButton, 'Later');
    await tester.ensureVisible(iosLater);
    await tester.tap(iosLater);
    await tester.pumpAndSettle();

    expect(find.text('Add your TikTok channel'), findsOneWidget);
  });
}
