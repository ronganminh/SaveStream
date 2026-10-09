import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/router/app_routes.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/app/theme/ss_tokens.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/core/mock/mock_scenario.dart';
import 'package:savestream_mobile/features/entitlement/data/repositories/mock_entitlement_repository.dart';
import 'package:savestream_mobile/features/entitlement/presentation/entitlement_providers.dart';
import 'package:savestream_mobile/features/home/presentation/home_screen.dart';

void main() {
  AppConfig config() {
    return AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    );
  }

  const MockBehavior behavior = MockBehavior(
    scenario: MockScenario.success,
    latency: Duration.zero,
  );
  const MockEntitlementRepository proEntitlement = MockEntitlementRepository(
    behavior,
    state: EntitlementMockState.pro,
  );

  test('A2 keeps the product primary color frozen', () {
    expect(SsColors.brandPrimary, const Color(0xFF4F46E5));
  });

  testWidgets('Free legacy over-limit list is kept but add is blocked', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: config()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Free minutes today'), findsOneWidget);
    expect(find.text('6 / 10 minutes remaining'), findsOneWidget);
    expect(find.text('Watching'), findsWidgets);
    expect(find.text('8/3'), findsOneWidget);
    expect(find.textContaining('credit', findRichText: true), findsNothing);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Watching 8/3 creators · FREE'), findsOneWidget);
    expect(
      find.textContaining('You already have 8 creators from an older plan'),
      findsWidgets,
    );

    await tester.tap(find.byTooltip('Add creator').first);
    await tester.pumpAndSettle();

    expect(find.text('Watching is full'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('per-creator LIVE notification switch persists in repository', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: config()));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final Finder notifyTile = find
        .widgetWithText(SwitchListTile, 'Notify when LIVE')
        .first;
    await tester.scrollUntilVisible(
      notifyTile,
      260,
      scrollable: find.byType(Scrollable).last,
    );
    final Finder notifySwitch = find.descendant(
      of: notifyTile,
      matching: find.byType(Switch),
    );
    expect(notifySwitch, findsOneWidget);
    final Switch switchWidget = tester.widget<Switch>(notifySwitch);
    switchWidget.onChanged!(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    final Switch updatedSwitch = tester.widget<Switch>(
      find
          .descendant(
            of: find.widgetWithText(SwitchListTile, 'Notify when LIVE').first,
            matching: find.byType(Switch),
          )
          .first,
    );
    expect(updatedSwitch.value, isFalse);
  });

  testWidgets('Pro Home shows hours/minutes and never credit or ads', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(
        config: config(),
        extraOverrides: [
          entitlementRepositoryProvider.overrideWithValue(proEntitlement),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Cloud time available'), findsOneWidget);
    expect(find.text('133 hours'), findsOneWidget);
    expect(find.textContaining('Cloud slots'), findsOneWidget);
    expect(find.textContaining('Watching 8/20'), findsOneWidget);
    expect(find.text('Advertisement'), findsNothing);
    expect(find.textContaining('credit', findRichText: true), findsNothing);
  });

  testWidgets('queue and missed cloud-slot states render on creator detail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(
        config: config(),
        extraOverrides: [
          entitlementRepositoryProvider.overrideWithValue(proEntitlement),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final GoRouter router = GoRouter.of(
      tester.element(find.byType(HomeScreen)),
    );
    router.go(AppRoutes.channelDetail('watch_007'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Waiting for a cloud slot'), findsOneWidget);
    expect(find.text('Queue position 1'), findsOneWidget);

    router.go(AppRoutes.channelDetail('watch_008'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Missed'), findsOneWidget);
    expect(
      find.textContaining('No cloud minutes were charged'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Pro add creator covers lookup failure then success without checkbox',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        SaveStreamApp(
          config: config(),
          extraOverrides: [
            entitlementRepositoryProvider.overrideWithValue(proEntitlement),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final GoRouter router = GoRouter.of(
        tester.element(find.byType(HomeScreen)),
      );
      router.go(AppRoutes.addChannel);
      await tester.pumpAndSettle();

      final Finder field = find.byType(TextFormField);
      await tester.enterText(field, '@notfound_creator');
      await tester.tap(find.widgetWithText(FilledButton, 'Find creator'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Creator not found'), findsOneWidget);

      await tester.enterText(field, '@fresh_creator');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Find creator'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Found'), findsOneWidget);
      expect(find.text('Use recordings responsibly'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);

      final Finder add = find.widgetWithText(FilledButton, 'Add & follow');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Channel detail'), findsOneWidget);
      expect(find.textContaining('@fresh_creator'), findsOneWidget);
    },
  );

  testWidgets('W15 and LIVE notification deep-link routes render', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(
        config: config(),
        extraOverrides: [
          entitlementRepositoryProvider.overrideWithValue(proEntitlement),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final GoRouter router = GoRouter.of(
      tester.element(find.byType(HomeScreen)),
    );

    router.go(AppRoutes.autoRecordSettings('watch_001'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Auto-record'), findsOneWidget);
    expect(find.text('Kept for 30 days'), findsOneWidget);
    expect(find.text('133 hours remaining'), findsOneWidget);

    router.go(AppRoutes.liveNotification('watch_001', state: 'live'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Record now'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);

    router.go(AppRoutes.liveNotification('watch_001', state: 'ended'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Livestream ended'), findsOneWidget);
  });

  testWidgets('Vietnamese locale contains A2 Home and Watching copy', (
    WidgetTester tester,
  ) async {
    final AppSettingsController settings = AppSettingsController(
      locale: const Locale('vi'),
    );
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      SaveStreamApp(config: config(), settings: settings),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Phút Free hôm nay'), findsOneWidget);
    expect(find.text('Theo dõi'), findsWidgets);
    expect(find.textContaining('credit', findRichText: true), findsNothing);
  });
}
