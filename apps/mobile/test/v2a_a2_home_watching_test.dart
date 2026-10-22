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
import 'package:savestream_mobile/core/widgets/v2/ss_v2_widgets.dart';
import 'package:savestream_mobile/features/channels/presentation/channels_screen.dart';
import 'package:savestream_mobile/features/entitlement/data/repositories/mock_entitlement_repository.dart';
import 'package:savestream_mobile/features/entitlement/presentation/entitlement_providers.dart';
import 'package:savestream_mobile/features/home/presentation/home_screen.dart';
import 'package:savestream_mobile/l10n/l10n.dart';

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

  test('A2 keeps the product primary color frozen (v2 artboards)', () {
    expect(SsColors.brandPrimary, const Color(0xFF6D4AFF));
  });

  testWidgets('Free legacy over-limit list is kept but add is blocked', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: config()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Recording time left'), findsOneWidget);
    expect(find.textContaining('credit', findRichText: true), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('nav-channels')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // All eight legacy channels stay listed.
    expect(find.byType(ChannelListCard), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('channels-add')).first);
    await tester.pumpAndSettle();

    expect(find.text('Watching is full'), findsOneWidget);
    expect(
      find.textContaining('You already have 8 channels from an older plan'),
      findsWidgets,
    );
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('per-creator LIVE alerts switch persists in repository', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: config()));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('nav-channels')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('@nora_shop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    SsV2Switch alerts() => tester.widget<SsV2Switch>(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is SsV2Switch && widget.semanticLabel == 'LIVE alerts',
      ),
    );
    expect(alerts().value, isTrue);
    alerts().onChanged!(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(alerts().value, isFalse);
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

    expect(find.text('Recording time left'), findsOneWidget);
    expect(find.text('133 h'), findsOneWidget);
    expect(
      find.text('Purchased minutes · billed per started minute'),
      findsOneWidget,
    );
    expect(find.text('Advertisement'), findsNothing);
    expect(find.textContaining('credit', findRichText: true), findsNothing);
  });

  testWidgets('waiting for a cloud slot renders on channel detail', (
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

    expect(find.text('LIVE · not recording'), findsOneWidget);
    expect(
      find.text(
        'Waiting for a free cloud slot. Recording starts as soon as one '
        'opens.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets(
    'Pro add channel covers lookup failure, then ownership and verify',
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
      await tester.tap(find.widgetWithText(FilledButton, 'Find channel'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('We couldn’t find a public profile with this username.'),
        findsOneWidget,
      );

      await tester.enterText(field, '@fresh_creator');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Found'), findsOneWidget);
      expect(find.text('Is this your channel?'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('add-channel-owner')));
      await tester.pump();

      final Finder confirm = find.widgetWithText(
        FilledButton,
        'Yes, verify ownership',
      );
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('Verify ownership'), findsOneWidget);
      expect(find.text('@fresh_creator'), findsOneWidget);
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

  test('Vietnamese strings keep the A2 Home and Watching copy', () {
    // Kept for a later release; v2.1.0 does not enable Vietnamese.
    final AppLocalizations vi = lookupAppLocalizations(const Locale('vi'));
    expect(vi.v2CreditsLabel, 'Thời gian ghi còn lại');
    expect(vi.v2YourChannels, 'Kênh của bạn');
  });

  testWidgets('a Vietnamese preference still renders Home in English', (
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

    expect(find.text('Recording time left'), findsOneWidget);
    expect(find.text('Your channels'), findsOneWidget);
    expect(find.text('Thời gian ghi còn lại'), findsNothing);
    expect(find.textContaining('credit', findRichText: true), findsNothing);
  });
}
