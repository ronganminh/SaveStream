// Runs inside a real Android emulator or iOS simulator, not Flutter's desktop
// widget-test runner. Real app routes/widgets run with deterministic fake
// providers: NO external Apple/Google purchases, ad impressions, or production
// accounts are touched by this suite.
import 'dart:async';
import 'dart:io';

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
import 'package:savestream_mobile/core/widgets/savestream_widgets.dart';
import 'package:savestream_mobile/features/devices/domain/models/device_registration.dart';
import 'package:savestream_mobile/features/entitlement/data/repositories/mock_entitlement_repository.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/entitlement/presentation/entitlement_providers.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/local_recording_reward_sheet.dart';
import 'package:savestream_mobile/features/recordings/presentation/recording_detail_screen.dart';
import 'package:savestream_mobile/features/store/data/repositories/mock_store_repository.dart';
import 'package:savestream_mobile/features/store/domain/models/store_models.dart';
import 'package:savestream_mobile/features/store/domain/repositories/store_repository.dart';
import 'package:savestream_mobile/features/store/presentation/a5_purchase_controller.dart';
import 'package:savestream_mobile/features/store/presentation/a5_store_providers.dart';
import 'package:savestream_mobile/features/store/presentation/cloud_hours_purchase_screen.dart';
import 'package:savestream_mobile/l10n/l10n.dart';
import 'package:savestream_mobile/platform/contracts/purchase_service.dart';
import 'package:savestream_mobile/platform/fakes/fake_device_info_service.dart';
import 'package:savestream_mobile/platform/platform_providers.dart';

void registerDeviceJourneys() {
  AppConfig config() => AppConfig(
    environment: AppEnvironment.local,
    apiBaseUrl: Uri.parse('http://localhost:8000'),
  );

  testWidgets('device: onboarding -> sign in -> authenticated home', (
    WidgetTester tester,
  ) async {
    final AppSessionController session = AppSessionController(
      hasCompletedOnboarding: false,
      authStatus: AppAuthStatus.unauthenticated,
    );
    await tester.pumpWidget(SaveStreamApp(config: config(), session: session));
    await _waitFor(tester, find.text('Never miss a LIVE.'));

    final Finder signIn = find.widgetWithText(OutlinedButton, 'Sign in');
    await tester.ensureVisible(signIn);
    await tester.tap(signIn);
    await _waitFor(tester, find.byType(TextFormField));
    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'alex@example.com');
    await tester.enterText(fields.at(1), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));

    await _waitFor(tester, find.text('Welcome back, Alex Nguyen'));
    expect(session.isAuthenticated, isTrue);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('device: watching -> add creator -> channel detail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      SaveStreamApp(
        config: config(),
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
    await _waitFor(tester, find.byIcon(Icons.visibility_outlined));
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await _waitFor(tester, find.text('Ada Live'));
    await tester.tap(find.byTooltip('Add creator').first);
    await _waitFor(tester, find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), '@ci_creator');
    await tester.tap(find.widgetWithText(FilledButton, 'Find creator'));
    await _waitFor(tester, find.text('Use recordings responsibly'));

    final Finder add = find.widgetWithText(FilledButton, 'Add & follow');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await _waitFor(tester, find.text('Channel detail'));
    await _waitFor(tester, find.textContaining('@ci_creator'));
    expect(find.text('Notify when LIVE'), findsWidgets);
  });

  testWidgets('device: recordings -> stop -> lifecycle acknowledgement', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: config()));
    await _waitFor(tester, find.text('Recordings'));
    await tester.tap(find.text('Recordings'));
    await _waitFor(tester, find.text('Ada Live'));
    await tester.tap(find.text('Ada Live').first);
    await _waitFor(tester, find.byType(RecordingDetailScreen));
    await tester.scrollUntilVisible(
      find.text('Stop recording'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    final Finder stop = find.widgetWithText(FilledButton, 'Stop recording');
    await tester.ensureVisible(stop);
    await tester.tap(stop);
    await _waitFor(tester, find.text('Stop cloud recording?'));
    await tester.tap(find.widgetWithText(FilledButton, 'Stop recording').last);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 800));
    await tester.pumpAndSettle();
    await _waitFor(tester, find.text('Stop requested'));
    expect(find.widgetWithText(FilledButton, 'Stop recording'), findsNothing);
  });

  testWidgets('device: rewarded ad offer and daily reward cap UI', (
    WidgetTester tester,
  ) async {
    Widget sheet(int used) => ProviderScope(
      key: ValueKey<int>(used),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RewardedMinutesSheet(
            entitlement: LocalEntitlement(
              enabled: true,
              unlimited: false,
              dailyMinutes: 10,
              minutesRemaining: 1,
              resetsAt: DateTime.utc(2026, 10, 10),
              rewardsUsedToday: used,
              rewardsCapPerDay: 8,
              minutesPerReward: 10,
              extensionsCapPerRecording: 4,
            ),
            extensionsUsed: 1,
          ),
        ),
      ),
    );
    await tester.pumpWidget(sheet(2));
    expect(find.text('+10 minutes for this recording'), findsOneWidget);
    expect(find.text('Rewarded ads today 2/8'), findsOneWidget);
    expect(find.text('Watch ad'), findsOneWidget);
    await tester.pumpWidget(sheet(8));
    await tester.pump();
    expect(find.text('Daily rewarded-ad limit reached'), findsWidgets);
    expect(find.text('Watch ad'), findsNothing);
  });

  testWidgets('device: settings -> Vietnamese -> dark theme', (
    WidgetTester tester,
  ) async {
    final AppSettingsController settings = AppSettingsController();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      SaveStreamApp(config: config(), settings: settings),
    );
    await _waitFor(tester, find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await _waitFor(tester, find.text('Settings'));
    final BuildContext context = tester.element(find.text('Settings').first);
    GoRouter.of(context).push(AppRoutes.language);
    await _waitFor(tester, find.text('Vietnamese'));
    await tester.tap(find.text('Vietnamese'));
    await _waitFor(tester, find.text('Ngôn ngữ'));
    expect(settings.locale.languageCode, 'vi');

    GoRouter.of(tester.element(find.text('Ngôn ngữ').first)).pop();
    await _waitFor(tester, find.text('Cài đặt'));
    GoRouter.of(
      tester.element(find.text('Cài đặt').first),
    ).push(AppRoutes.theme);
    await _waitFor(tester, find.text('Tối'));
    await tester.tap(find.text('Tối'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(settings.themeMode, ThemeMode.dark);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets('device: cloud-hours offers -> mock store -> credited', (
    WidgetTester tester,
  ) async {
    final _CiPurchaseService store = _CiPurchaseService();
    final _CiStoreRepository backend = _CiStoreRepository();
    addTearDown(store.dispose);
    final DevicePlatform devicePlatform = Platform.isIOS
        ? DevicePlatform.ios
        : DevicePlatform.android;

    await tester.pumpWidget(
      SaveStreamApp(
        config: config(),
        extraOverrides: [
          purchaseServiceProvider.overrideWithValue(store),
          storeRepositoryProvider.overrideWithValue(backend),
          deviceInfoServiceProvider.overrideWithValue(
            FakeDeviceInfoService(platform: devicePlatform),
          ),
        ],
      ),
    );
    await _waitFor(tester, find.text('Home'));
    GoRouter.of(tester.element(find.text('Home').first)).go(
      AppRoutes.cloudHoursLocation(CloudHoursPurchaseContext.autoRecord.name),
    );
    await _waitFor(tester, find.byType(CloudHoursPurchaseScreen));
    await _waitFor(tester, find.text(r'$59.99'));

    expect(find.text(r'$9.99'), findsOneWidget);
    expect(find.text(r'$24.99'), findsOneWidget);
    expect(find.text(r'$59.99'), findsOneWidget);

    final Finder buy = find.widgetWithText(SsPrimaryButton, 'Buy cloud hours');
    expect(buy, findsNWidgets(3));
    await tester.ensureVisible(buy.first);
    await tester.tap(buy.first);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(CloudHoursPurchaseScreen)),
    );
    for (int i = 0; i < 35; i++) {
      if (container.read(cloudHoursPurchaseControllerProvider).phase ==
          CloudHoursPurchasePhase.credited)
        break;
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(
      container.read(cloudHoursPurchaseControllerProvider).phase,
      CloudHoursPurchasePhase.credited,
    );
    expect(store.purchases, <String>['savestream.hours.50']);
    expect(store.completedTransactions, <String>['ci_savestream.hours.50']);
    expect(backend.requests, hasLength(1));
    expect(
      backend.requests.single.platform,
      Platform.isIOS
          ? StorePurchasePlatform.appStore
          : StorePurchasePlatform.googlePlay,
    );
    expect(backend.requests.single.receipt, 'fake-ci-only-receipt');
  });
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (int attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets, reason: 'Timed out waiting for native screen');
}

final class _CiPurchaseService implements PurchaseService {
  final StreamController<PurchaseServiceEvent> _events =
      StreamController<PurchaseServiceEvent>.broadcast(sync: true);
  final List<String> purchases = <String>[];
  final List<String> completedTransactions = <String>[];

  @override
  Stream<PurchaseServiceEvent> get purchaseEvents => _events.stream;

  @override
  Future<List<StoreProductInfo>> loadProducts(Iterable<String> ids) async => ids
      .map(
        (String id) => StoreProductInfo(
          id: id,
          localizedPrice: switch (id) {
            'savestream.hours.50' => r'$9.99',
            'savestream.hours.150' => r'$24.99',
            'savestream.hours.400' => r'$59.99',
            _ => 'UNKNOWN',
          },
        ),
      )
      .toList(growable: false);

  @override
  Future<void> buy(String productId) async {
    purchases.add(productId);
    _events.add(
      PurchaseServiceEvent(
        productId: productId,
        status: PurchaseEventStatus.purchased,
        transactionId: 'ci_$productId',
        receipt: 'fake-ci-only-receipt',
      ),
    );
  }

  @override
  Future<void> restore() async {}

  @override
  Future<void> completePurchase(String transactionId) async {
    completedTransactions.add(transactionId);
  }

  Future<void> dispose() => _events.close();
}

final class _CiStoreRepository implements StoreRepository {
  final List<StorePurchaseRequest> requests = <StorePurchaseRequest>[];

  @override
  Future<List<StorePackage>> listPackages() async =>
      MockStoreRepository.packages;

  @override
  Future<StorePurchaseResult> submitPurchase(
    StorePurchaseRequest request,
  ) async {
    requests.add(request);
    final StorePackage pack = MockStoreRepository.packages.firstWhere(
      (StorePackage item) => item.productIds.appStore == request.productId,
    );
    return StorePurchaseResult(
      status: StorePurchaseStatus.credited,
      paymentOrderId: 'ci-order-only',
      cloudMinutesAdded: pack.cloudMinutes,
      cloudMinutesAvailable: pack.cloudMinutes,
    );
  }
}
