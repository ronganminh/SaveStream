// Credits v2 screens (Recording time, purchases, rewarded ads) at 390×844,
// one test per artboard. See screenshot_harness.dart for writing the PNGs.
// No real purchase or ad: the store, AdMob and the API are fakes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/router/app_routes.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/api/api_error.dart';
import 'package:savestream_mobile/core/api/api_exception.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/core/widgets/v2/ss_v2_widgets.dart';
import 'package:savestream_mobile/features/channels/domain/models/watch_summary.dart';
import 'package:savestream_mobile/features/channels/domain/repositories/watch_repository.dart';
import 'package:savestream_mobile/features/credits/domain/credit_balance.dart';
import 'package:savestream_mobile/features/credits/domain/credit_ledger.dart';
import 'package:savestream_mobile/features/credits/presentation/credits_providers.dart';
import 'package:savestream_mobile/features/credits/presentation/rewarded_ad_controller.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/entitlement/domain/repositories/entitlement_repository.dart';
import 'package:savestream_mobile/features/entitlement/presentation/entitlement_providers.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/recordings/domain/repositories/recording_repository.dart';
import 'package:savestream_mobile/features/settings/domain/models/app_notification.dart';
import 'package:savestream_mobile/features/settings/domain/models/user_profile.dart';
import 'package:savestream_mobile/features/settings/domain/repositories/notifications_repository.dart';
import 'package:savestream_mobile/features/settings/domain/repositories/profile_repository.dart';
import 'package:savestream_mobile/features/store/data/repositories/mock_store_repository.dart';
import 'package:savestream_mobile/features/store/domain/models/store_models.dart';
import 'package:savestream_mobile/features/store/domain/repositories/store_repository.dart';
import 'package:savestream_mobile/features/store/presentation/a5_store_providers.dart';
import 'package:savestream_mobile/platform/contracts/ads_service.dart';
import 'package:savestream_mobile/platform/contracts/purchase_service.dart';
import 'package:savestream_mobile/platform/fakes/fake_ads_service.dart';
import 'package:savestream_mobile/platform/fakes/fake_purchase_service.dart';
import 'package:savestream_mobile/platform/platform_providers.dart';

import 'screenshot_harness.dart';

final DateTime _now = DateTime(2026, 10, 22, 20, 43, 18);
const String _userId = 'usr_123';

AppConfig _config() => AppConfig(
  environment: AppEnvironment.local,
  apiBaseUrl: Uri.parse('http://localhost:8000'),
);

class _Harness {
  _Harness({
    this.rewardsLeft = 4,
    this.purchased = true,
    PurchaseEventStatus buyStatus = PurchaseEventStatus.purchased,
    List<String> restorable = const <String>[],
    RewardedAdOutcome adOutcome = RewardedAdOutcome.earned,
    this.rewardError,
    bool bannerConfigured = false,
    bool privacyRequired = false,
  }) : store = FakePurchaseService(
         buyStatus: buyStatus,
         restorable: restorable,
       ),
       ads = FakeAdsService(
         outcome: adOutcome,
         bannerConfigured: bannerConfigured,
         privacyRequired: privacyRequired,
       );

  int minutes = 760;
  int rewardsLeft;
  final bool purchased;
  final FakePurchaseService store;
  final FakeAdsService ads;
  final ApiException? rewardError;
  final List<StorePurchaseRequest> submitted = <StorePurchaseRequest>[];
  final List<String> rewardDevices = <String>[];
}

void main() {
  setUpAll(loadBundledFonts);

  Future<void> pumpCredits(
    WidgetTester tester,
    _Harness harness, {
    String location = AppRoutes.usage,
  }) async {
    usePhoneView(tester);
    final AppSessionController session = AppSessionController();
    final AppSettingsController settings = AppSettingsController();
    addTearDown(session.dispose);
    addTearDown(settings.dispose);
    addTearDown(harness.store.dispose);
    final _FakeApi api = _FakeApi(harness);
    await tester.pumpWidget(
      screenshotFrame(
        SaveStreamApp(
          config: _config(),
          session: session,
          settings: settings,
          watchRepository: _FakeWatches(),
          recordingRepository: _FakeRecordings(),
          profileRepository: _FakeProfile(),
          notificationsRepository: _FakeNotifications(),
          extraOverrides: <Override>[
            entitlementRepositoryProvider.overrideWithValue(api),
            creditsRepositoryProvider.overrideWithValue(api),
            creditLedgerRepositoryProvider.overrideWithValue(api),
            rewardsRepositoryProvider.overrideWithValue(api),
            storeRepositoryProvider.overrideWithValue(api),
            purchaseServiceProvider.overrideWithValue(harness.store),
            adsServiceProvider.overrideWithValue(harness.ads),
            creditsClockProvider.overrideWithValue(() => _now),
            rewardPollingProvider.overrideWithValue(
              const RewardPolling(interval: Duration(milliseconds: 10)),
            ),
          ],
        ),
      ),
    );
    await settle(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await settle(tester);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final Finder target = find.byKey(ValueKey<String>(key));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await settle(tester);
  }

  testWidgets('ACredits', (WidgetTester tester) async {
    await pumpCredits(tester, _Harness());
    expect(find.text('Recording time'), findsOneWidget);
    expect(find.text('12 h 40 min'), findsOneWidget);
    expect(find.text('Watch an ad, get 5 minutes'), findsOneWidget);
    expect(
      find.text('Optional · up to 6 a day · 2 of 6 used today'),
      findsOneWidget,
    );
    expect(find.text('Watch ad · +5 min'), findsOneWidget);
    expect(find.text('Most popular'), findsOneWidget);
    expect(find.text('150 h of recording · one-time'), findsOneWidget);
    // Prices come from the store (here the fake), never from the app.
    expect(find.text(r'$24.99'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('Usage history'), findsOneWidget);
    await captureScreen(tester, 'ACredits');
  });

  testWidgets('ARewardEarned', (WidgetTester tester) async {
    final _Harness harness = _Harness();
    await pumpCredits(tester, harness);
    await tapKey(tester, 'credits-watch-ad');
    expect(harness.rewardDevices, <String>['dev_fake']);
    // The ad carries the intent's SSV user id and custom data.
    expect(harness.ads.shown.single.userId, _userId);
    expect(harness.ads.shown.single.customData, 'rwd_1');
    // Personalized ads are on by default (UMP still governs where it
    // applies).
    expect(harness.ads.shown.single.personalized, isTrue);
    expect(find.text('+5 minutes added to your balance'), findsOneWidget);
    expect(
      find.text('Optional · up to 6 a day · 3 of 6 used today'),
      findsOneWidget,
    );
    await captureScreen(tester, 'ARewardEarned');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ARewardCooldown', (WidgetTester tester) async {
    final _Harness harness = _Harness(
      rewardsLeft: 3,
      rewardError: ApiException(
        kind: ApiExceptionKind.rateLimited,
        statusCode: 429,
        retryable: true,
        apiError: ApiError(
          code: 'REWARD_LOCKED',
          message: 'Reward verification is temporarily locked',
          retryable: true,
          details: <String, Object?>{
            'locked_until': _now
                .add(const Duration(minutes: 4, seconds: 32))
                .toUtc()
                .toIso8601String(),
          },
        ),
      ),
    );
    await pumpCredits(tester, harness);
    await tapKey(tester, 'credits-watch-ad');
    expect(find.text('Next ad in 4:32'), findsOneWidget);
    expect(harness.ads.shown, isEmpty);
    await captureScreen(tester, 'ARewardCooldown');
  });

  testWidgets('ARewardLimit', (WidgetTester tester) async {
    await pumpCredits(tester, _Harness(rewardsLeft: 0));
    expect(
      find.text('Optional · up to 6 a day · 6 of 6 used today'),
      findsOneWidget,
    );
    expect(
      find.text('You’ve used all 6 for today. More tomorrow.'),
      findsOneWidget,
    );
    expect(find.text('Watch ad · +5 min'), findsNothing);
    await captureScreen(tester, 'ARewardLimit');
  });

  testWidgets('ARewardFailed', (WidgetTester tester) async {
    final _Harness harness = _Harness(
      adOutcome: RewardedAdOutcome.failedToLoad,
    );
    await pumpCredits(tester, harness);
    await tapKey(tester, 'credits-watch-ad');
    expect(
      find.text(
        'The ad didn’t load. No minutes were used — try again in a moment.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    await captureScreen(tester, 'ARewardFailed');
  });

  testWidgets('rewarded ads switched off on the server hide the card', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness(
      rewardError: const ApiException(
        kind: ApiExceptionKind.conflict,
        statusCode: 409,
        retryable: false,
        apiError: ApiError(
          code: 'REWARDED_ADS_UNAVAILABLE',
          message: 'Rewarded ads are not available right now',
          retryable: false,
          details: <String, Object?>{},
        ),
      ),
    );
    await pumpCredits(tester, harness);
    await tapKey(tester, 'credits-watch-ad');
    expect(find.text('Watch an ad, get 5 minutes'), findsNothing);
  });

  testWidgets('APurchaseSuccess', (WidgetTester tester) async {
    final _Harness harness = _Harness();
    await pumpCredits(tester, harness);
    await tapKey(tester, 'credits-pack-savestream.hours.150');
    expect(harness.store.purchases, <String>['savestream.hours.150']);
    // obfuscatedAccountId = sha256(user id), as the server checks it.
    expect(
      harness.store.accountReferences.single,
      'ca010ec7feb32be7e30002f602d7c2ab062fb7a2be105ae6b8b1fb739cb72c77',
    );
    expect(harness.submitted.single.receipt, 'fake-token-savestream.hours.150');
    // Consumed only after the server credited it.
    expect(harness.store.completedTransactions, <String>['GPA.0000-1']);
    expect(find.text('150 hours added'), findsOneWidget);
    expect(find.text('Standard · 150 h'), findsOneWidget);
    expect(find.text(r'$24.99'), findsOneWidget);
    expect(find.text('GPA.0000-1'), findsOneWidget);
    expect(find.text('162 h 40 min'), findsOneWidget);
    await captureScreen(tester, 'APurchaseSuccess');

    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('Buy recording time'), findsOneWidget);
  });

  testWidgets('APurchasePending', (WidgetTester tester) async {
    final _Harness harness = _Harness(buyStatus: PurchaseEventStatus.pending);
    await pumpCredits(tester, harness);
    await tapKey(tester, 'credits-pack-savestream.hours.150');
    expect(find.text('Payment pending'), findsOneWidget);
    expect(
      find.text(
        'Google Play is still confirming your payment for the Standard pack '
        '(150 h). We’ll add the time as soon as it’s confirmed — you can '
        'close the app.',
      ),
      findsOneWidget,
    );
    expect(harness.submitted, isEmpty);
    await captureScreen(tester, 'APurchasePending');
  });

  testWidgets('APurchaseFailed', (WidgetTester tester) async {
    final _Harness harness = _Harness(buyStatus: PurchaseEventStatus.failed);
    await pumpCredits(tester, harness);
    await tapKey(tester, 'credits-pack-savestream.hours.150');
    expect(find.text('Purchase didn’t go through'), findsOneWidget);
    expect(
      find.text(
        'Google Play couldn’t complete the payment. You weren’t charged.',
      ),
      findsOneWidget,
    );
    expect(harness.submitted, isEmpty);
    await captureScreen(tester, 'APurchaseFailed');

    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(harness.store.purchases, hasLength(2));
  });

  testWidgets('ARestore', (WidgetTester tester) async {
    final _Harness harness = _Harness(
      restorable: <String>['savestream.hours.150'],
    );
    await pumpCredits(tester, harness);
    await tester.tap(find.text('Restore purchases'));
    await settle(tester);
    expect(find.text('Purchases restored'), findsOneWidget);
    expect(
      find.textContaining('Standard · 150 h. It’s now in your balance.'),
      findsOneWidget,
    );
    expect(
      find.text('Already-added purchases are never added twice.'),
      findsOneWidget,
    );
    expect(harness.store.completedTransactions, <String>[
      'GPA.restored-savestream.hours.150',
    ]);
    await captureScreen(tester, 'ARestore');
  });

  testWidgets('restore with nothing new says so', (WidgetTester tester) async {
    await pumpCredits(tester, _Harness());
    await tester.tap(find.text('Restore purchases'));
    await settle(tester);
    expect(find.text('Nothing to restore'), findsOneWidget);
  });

  testWidgets('AUsageHistory', (WidgetTester tester) async {
    await pumpCredits(tester, _Harness(), location: AppRoutes.creditsHistory);
    expect(find.text('Last 14 days'), findsOneWidget);
    expect(find.text('Recording · @my_shop_live'), findsOneWidget);
    expect(
      find.text('Oct 21 · 1 h 39 min · billed per started minute'),
      findsOneWidget,
    );
    expect(find.text('−99 min'), findsOneWidget);
    expect(find.text('Rewarded ad'), findsOneWidget);
    expect(find.text('+5 min'), findsOneWidget);
    expect(
      find.text('Oct 20 · 58 min 14 s · billed per started minute'),
      findsOneWidget,
    );
    expect(find.text('Failed recording · refunded'), findsOneWidget);
    await captureScreen(tester, 'AUsageHistory');

    await tester.scrollUntilVisible(
      find.text('Free trial'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Standard pack · Google Play'), findsOneWidget);
    expect(find.text('+150 h'), findsOneWidget);
    expect(find.text('Free trial'), findsOneWidget);
    expect(find.text('Oct 2 · after email verification'), findsOneWidget);
  });

  testWidgets('APurchases', (WidgetTester tester) async {
    await pumpCredits(tester, _Harness(), location: AppRoutes.purchases);
    expect(find.text('Purchases & usage'), findsOneWidget);
    expect(find.text('Standard · 150 h'), findsOneWidget);
    expect(find.text('Starter · 50 h'), findsOneWidget);
    expect(find.text('Added'), findsNWidgets(2));
    await captureScreen(tester, 'APurchases');
  });

  testWidgets('the banner shows on Home only for non-purchasers', (
    WidgetTester tester,
  ) async {
    await pumpCredits(
      tester,
      _Harness(purchased: false, bannerConfigured: true),
      location: AppRoutes.home,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('fake-ad-banner')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const ValueKey<String>('fake-ad-banner')), findsOne);
  });

  testWidgets('no banner on Home after a purchase', (
    WidgetTester tester,
  ) async {
    await pumpCredits(
      tester,
      _Harness(bannerConfigured: true),
      location: AppRoutes.home,
    );
    expect(find.byKey(const ValueKey<String>('fake-ad-banner')), findsNothing);
  });

  testWidgets('AAdPrivacy', (WidgetTester tester) async {
    final _Harness harness = _Harness();
    await pumpCredits(tester, harness, location: AppRoutes.adPrivacy);
    expect(find.text('Ad privacy choices'), findsOneWidget);
    expect(find.text('Personalized ads'), findsOneWidget);
    expect(
      find.text(
        'You bought a pack, so other ads are removed. Rewarded ads stay '
        'available if you choose to watch them.',
      ),
      findsOneWidget,
    );
    await captureScreen(tester, 'AAdPrivacy');

    await tester.tap(find.text('Review privacy choices'));
    await settle(tester);
    expect(harness.ads.consentChecks, 1);
    expect(harness.ads.privacyFormsShown, 0);
    expect(
      find.text(
        'No privacy form is needed in your region. You can still turn '
        'personalized ads off above.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('UMP privacy options open when UMP requires them', (
    WidgetTester tester,
  ) async {
    // EEA/UK/Switzerland, or a US state with the AdMob US-states message.
    final _Harness harness = _Harness(privacyRequired: true);
    await pumpCredits(tester, harness, location: AppRoutes.adPrivacy);
    await tester.tap(find.text('Review privacy choices'));
    await settle(tester);
    expect(harness.ads.privacyFormsShown, 1);
  });

  testWidgets('turning personalized ads off sends non-personalized requests', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();
    await pumpCredits(tester, harness, location: AppRoutes.adPrivacy);
    final Finder toggle = find.descendant(
      of: find.byKey(const ValueKey<String>('ad-privacy-personalized')),
      matching: find.byType(SsV2Switch),
    );
    expect(tester.widget<SsV2Switch>(toggle).value, isTrue);
    await tester.tap(toggle);
    await settle(tester);
    expect(tester.widget<SsV2Switch>(toggle).value, isFalse);

    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).go(AppRoutes.usage);
    await settle(tester);
    await tapKey(tester, 'credits-watch-ad');
    expect(harness.ads.shown.single.personalized, isFalse);
    await tester.pump(const Duration(seconds: 5));
  });
}

Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.pumpAndSettle();
}

/// The API: entitlement, balance, ledger, payment orders, rewards, packs and
/// store purchase verification.
class _FakeApi
    implements
        EntitlementRepository,
        CreditsRepository,
        CreditLedgerRepository,
        RewardsRepository,
        StoreRepository {
  _FakeApi(this.h);

  final _Harness h;
  int _rewards = 0;

  @override
  Future<Entitlement> getEntitlement() async => Entitlement(
    plan: Plan.pro,
    hasPurchased: h.purchased,
    emailVerified: true,
    canAutoRecord: true,
    cloudMinutesAvailable: h.minutes,
    limits: const EntitlementLimits(
      maxWatches: 5,
      maxConcurrentCloudRecordings: 1,
      cloudRetentionDays: 30,
    ),
    watchCount: 2,
    local: LocalEntitlement(
      enabled: false,
      unlimited: false,
      dailyMinutes: 0,
      minutesRemaining: 0,
      resetsAt: DateTime.utc(2026, 10, 23),
      rewardsUsedToday: 0,
      rewardsCapPerDay: 0,
      minutesPerReward: 0,
      extensionsCapPerRecording: 0,
    ),
    updatedAt: DateTime.utc(2026, 10, 22),
    ads: AdsEntitlement(
      rewardedAvailable: h.rewardsLeft > 0,
      rewardsLeftToday: h.rewardsLeft,
      rewardsCapPerDay: 6,
      minutesPerReward: 5,
      resetsAt: DateTime.utc(2026, 10, 23),
      showBanners: !h.purchased,
    ),
  );

  @override
  Future<CreditBalance> getBalance() async =>
      CreditBalance(posted: h.minutes, reserved: 0, available: h.minutes);

  @override
  Future<RewardIntent> createCloudMinutesReward({
    required String deviceId,
  }) async {
    h.rewardDevices.add(deviceId);
    if (h.rewardError != null) throw h.rewardError!;
    _rewards += 1;
    return RewardIntent(
      rewardId: 'rwd_$_rewards',
      ssvUserId: _userId,
      ssvCustomData: 'rwd_$_rewards',
      expiresAt: _now.add(const Duration(hours: 1)),
    );
  }

  @override
  Future<RewardStatus> getRewardStatus(String rewardId) async {
    // AdMob's callback reached the server: +5 minutes, one more used today.
    h.minutes += 5;
    h.rewardsLeft -= 1;
    return RewardStatus.valid;
  }

  @override
  Future<List<StorePackage>> listPackages() async =>
      MockStoreRepository.packages;

  @override
  Future<StorePurchaseResult> submitPurchase(
    StorePurchaseRequest request,
  ) async {
    h.submitted.add(request);
    final StorePackage package = MockStoreRepository.packages.firstWhere(
      (StorePackage item) => item.productIds.googlePlay == request.productId,
    );
    h.minutes += package.cloudMinutes;
    return StorePurchaseResult(
      status: StorePurchaseStatus.credited,
      paymentOrderId: 'ord_${h.submitted.length}',
      cloudMinutesAdded: package.cloudMinutes,
      cloudMinutesAvailable: h.minutes,
    );
  }

  @override
  Future<List<PaymentOrder>> listPaymentOrders() async => <PaymentOrder>[
    PaymentOrder(
      id: 'ord_std',
      packageId: 'standard',
      status: PaymentOrderStatus.paid,
      credits: 9000,
      provider: 'google_play',
      createdAt: DateTime(2026, 10, 15, 12),
    ),
    PaymentOrder(
      id: 'ord_web',
      packageId: 'starter',
      status: PaymentOrderStatus.paid,
      credits: 3000,
      provider: 'paypal',
      createdAt: DateTime(2026, 9, 20, 12),
    ),
    PaymentOrder(
      id: 'ord_start',
      packageId: 'starter',
      status: PaymentOrderStatus.paid,
      credits: 3000,
      provider: 'google_play',
      createdAt: DateTime(2026, 9, 2, 12),
    ),
  ];

  @override
  Future<CreditTransactionPage> listTransactions({
    String? cursor,
    int limit = 50,
  }) async {
    CreditTransaction tx(
      String id,
      CreditTransactionType type,
      int amount,
      String reference,
      DateTime at, {
      String? referenceId,
    }) => CreditTransaction(
      id: id,
      type: type,
      amount: amount,
      balanceAfter: 0,
      referenceType: reference,
      referenceId: referenceId,
      createdAt: at,
    );
    const CreditTransactionType charge = CreditTransactionType.charge;
    return CreditTransactionPage(
      items: <CreditTransaction>[
        tx(
          't1',
          charge,
          -99,
          'recording',
          DateTime(2026, 10, 21, 21),
          referenceId: 'r-shop',
        ),
        tx(
          't1r',
          CreditTransactionType.release,
          0,
          'recording',
          DateTime(2026, 10, 21, 21),
          referenceId: 'r-shop',
        ),
        tx(
          't2',
          CreditTransactionType.grant,
          5,
          'reward',
          DateTime(2026, 10, 21, 9),
        ),
        tx(
          't3',
          charge,
          -59,
          'recording',
          DateTime(2026, 10, 20, 22),
          referenceId: 'r-gaming',
        ),
        tx(
          't4',
          CreditTransactionType.release,
          0,
          'recording',
          DateTime(2026, 10, 19, 20),
          referenceId: 'r-failed',
        ),
        for (final (int day, int minutes) in <(int, int)>[
          (18, 70),
          (17, 50),
          (15, 100),
          (13, 30),
          (12, 45),
          (10, 60),
          (9, 20),
        ])
          tx(
            'c$day',
            charge,
            -minutes,
            'recording',
            DateTime(2026, 10, day, 21),
            referenceId: 'r-$day',
          ),
        tx(
          't5',
          CreditTransactionType.grant,
          9000,
          'payment_order',
          DateTime(2026, 10, 15, 12),
          referenceId: 'ord_std',
        ),
        tx(
          't6',
          CreditTransactionType.grant,
          10,
          'signup_bonus',
          DateTime(2026, 10, 2, 9),
        ),
      ],
    );
  }
}

class _FakeRecordings implements RecordingRepository {
  RecordingSummary _item(String id, String handle, int seconds) =>
      RecordingSummary(
        id: id,
        creatorDisplayName: handle,
        creatorUsername: handle,
        status: RecordingStatus.completed,
        actions: const RecordingActions(
          canStop: false,
          canRetry: false,
          canDelete: true,
        ),
        startedAt: _now,
        durationSeconds: seconds,
      );

  @override
  Future<List<RecordingSummary>> listRecordings() async =>
      const <RecordingSummary>[];

  @override
  Future<RecordingPage> listRecordingPage({
    RecordingFilter filter = RecordingFilter.all,
    String? cursor,
    int limit = 4,
  }) async => RecordingPage(
    items: <RecordingSummary>[
      _item('r-shop', 'my_shop_live', 5940),
      _item('r-gaming', 'my_gaming_stream', 3494),
    ],
    nextCursor: null,
  );

  @override
  Stream<RecordingSummary?> watchRecording(String id) =>
      const Stream<RecordingSummary?>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeWatches implements WatchRepository {
  @override
  Future<List<WatchSummary>> listWatches() async => const <WatchSummary>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeProfile implements ProfileRepository {
  @override
  Future<UserProfile> getProfile() async => const UserProfile(
    email: 'alex.morgan@example.com',
    emailVerified: true,
    displayName: 'Alex Morgan',
    id: _userId,
  );
}

class _FakeNotifications implements NotificationsRepository {
  @override
  Future<NotificationPage> listNotifications({String? cursor}) async {
    return const NotificationPage(items: <AppNotification>[]);
  }

  @override
  Future<AppNotification> markRead(String notificationId) =>
      throw UnimplementedError();
}
