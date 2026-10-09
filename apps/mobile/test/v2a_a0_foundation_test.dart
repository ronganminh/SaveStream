import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/theme/ss_theme.dart';
import 'package:savestream_mobile/core/formatters/v2_formatters.dart';
import 'package:savestream_mobile/core/mock/mock_repository_base.dart';
import 'package:savestream_mobile/core/mock/mock_scenario.dart';
import 'package:savestream_mobile/core/widgets/savestream_widgets.dart';
import 'package:savestream_mobile/features/app_status/data/repositories/mock_app_status_repository.dart';
import 'package:savestream_mobile/features/devices/data/repositories/mock_device_repository.dart';
import 'package:savestream_mobile/features/devices/domain/models/device_registration.dart';
import 'package:savestream_mobile/features/entitlement/data/repositories/mock_entitlement_repository.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/local_recordings/data/repositories/mock_local_recording_repository.dart';
import 'package:savestream_mobile/features/local_recordings/domain/models/local_recording_models.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/rewards/data/repositories/mock_reward_repository.dart';
import 'package:savestream_mobile/features/rewards/domain/models/reward.dart';
import 'package:savestream_mobile/features/store/data/repositories/mock_store_repository.dart';
import 'package:savestream_mobile/features/store/domain/models/store_models.dart';

void main() {
  const MockBehavior behavior = MockBehavior(
    scenario: MockScenario.success,
    latency: Duration.zero,
  );

  test('A0 entitlement mock exposes Free and Pro variants', () async {
    final Entitlement free = await const MockEntitlementRepository(
      behavior,
      state: EntitlementMockState.free,
    ).getEntitlement();
    final Entitlement pro = await const MockEntitlementRepository(
      behavior,
      state: EntitlementMockState.pro,
    ).getEntitlement();

    expect(free.plan, Plan.free);
    expect(free.local.minutesRemaining, 6);
    expect(pro.plan, Plan.pro);
    expect(pro.local.unlimited, isTrue);
    expect(pro.limits.maxConcurrentCloudRecordings, 3);
  });

  test('A0 local recording mock starts, extends, finishes and lists', () async {
    final MockLocalRecordingRepository repository =
        MockLocalRecordingRepository(behavior);
    final session = await repository.start(
      watchId: 'watch_1',
      deviceId: 'dev_1',
    );
    final extended = await repository.extend(session.sessionId);
    expect(extended.grantedSeconds, greaterThan(session.grantedSeconds));

    await repository.finish(
      session.sessionId,
      recordedSeconds: 120,
      sizeBytes: 1024,
      endReason: RecordingEndReason.userStopped,
      status: RecordingStatus.completed,
    );
    expect(await repository.list(), hasLength(1));
  });

  test('A0 reward mock validates created reward on status poll', () async {
    final MockRewardRepository repository = MockRewardRepository(behavior);
    final Reward reward = await repository.create(
      purpose: RewardPurpose.localMinutes,
    );
    expect(reward.status, RewardStatus.pending);
    expect(
      (await repository.getStatus(reward.rewardId)).status,
      RewardStatus.valid,
    );
  });

  test('A0 store packages match V2 purchased-hour products', () async {
    final List<StorePackage> packages = await const MockStoreRepository(
      behavior,
    ).listPackages();
    expect(packages.map((StorePackage item) => item.cloudMinutes), <int>[
      3000,
      9000,
      24000,
    ]);
  });

  test('A0 app status mock returns supported-version data', () async {
    final status = await const MockAppStatusRepository(behavior).getStatus();
    expect(status.minSupportedVersion.android, '2.0.0');
    expect(status.maintenance.active, isFalse);
  });

  test('A0 device mock registers and unregisters a device', () async {
    final MockDeviceRepository repository = MockDeviceRepository(behavior);
    const DeviceRegistration device = DeviceRegistration(
      deviceId: 'dev_1',
      platform: DevicePlatform.android,
      deviceName: 'Pixel',
      appVersion: '2.0.0',
      locale: 'en',
    );
    expect((await repository.register(device)).deviceId, 'dev_1');
    await repository.unregister('dev_1');
  });

  test('A0 mocks inherit all five base scenarios', () async {
    const MockEntitlementRepository errorRepository = MockEntitlementRepository(
      const MockBehavior(scenario: MockScenario.error, latency: Duration.zero),
    );
    await expectLater(
      errorRepository.getEntitlement(),
      throwsA(isA<MockRepositoryException>()),
    );

    const MockStoreRepository emptyRepository = MockStoreRepository(
      const MockBehavior(scenario: MockScenario.empty, latency: Duration.zero),
    );
    expect(await emptyRepository.listPackages(), isEmpty);
  });

  test('A0 formatters use minutes and HH:MM:SS', () {
    expect(
      formatMinutesAsHoursMinutes(
        8000,
        hoursLabel: 'hours',
        minutesLabel: 'minutes',
      ),
      '133 hours 20 minutes',
    );
    expect(formatDurationHms(const Duration(seconds: 3723)), '01:02:03');
    expect(formatFileSize(1024), '1.0 KB');
  });

  testWidgets('A0 shared widgets all render', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SsTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                const SsLocationChip(engine: Engine.local),
                const SsPlanBadge(plan: Plan.pro),
                const SsLiveBadge(isLive: true),
                const SsQuotaCard(
                  title: 'Cloud time',
                  value: '50 hours',
                  progress: .5,
                ),
                const SsCreatorTile(
                  name: 'Creator',
                  handle: '@creator',
                  isLive: true,
                ),
                const SsRecordingTile(
                  title: 'Recording',
                  subtitle: 'Today',
                  engine: Engine.cloud,
                ),
                const SsActiveRecordingCard(
                  creatorName: 'Creator',
                  elapsed: '00:01:02',
                  engine: Engine.local,
                ),
                const SsRecordingBar(
                  label: 'Recording active',
                  elapsed: '00:01:02',
                ),
                const SsInlineAlert(
                  title: 'Warning',
                  tone: SsInlineAlertTone.warning,
                ),
                SsFilterChips(
                  items: const <String>['All', 'LIVE', 'Offline'],
                  selectedIndex: 0,
                  onSelected: (_) {},
                ),
                const SsBannerAdSlot(label: 'Ad slot'),
                const SsChecklist(
                  items: <SsChecklistItem>[
                    SsChecklistItem(label: 'Finalize', done: true),
                  ],
                ),
                Builder(
                  builder: (BuildContext context) {
                    return Column(
                      children: <Widget>[
                        TextButton(
                          onPressed: () {
                            showModalBottomSheet<void>(
                              context: context,
                              builder: (BuildContext context) {
                                return const SsBottomSheet(
                                  title: 'Sheet',
                                  child: Text('Sheet body'),
                                );
                              },
                            );
                          },
                          child: const Text('Open sheet'),
                        ),
                        TextButton(
                          onPressed: () => SsToast.show(context, 'Toast'),
                          child: const Text('Show toast'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SsLocationChip), findsAtLeastNWidgets(3));
    expect(find.byType(SsPlanBadge), findsOneWidget);
    expect(find.byType(SsLiveBadge), findsAtLeastNWidgets(2));
    expect(find.byType(SsQuotaCard), findsOneWidget);
    expect(find.byType(SsCreatorTile), findsOneWidget);
    final SsAvatar liveAvatar = tester.widget<SsAvatar>(
      find.descendant(
        of: find.byType(SsCreatorTile),
        matching: find.byType(SsAvatar),
      ),
    );
    expect(liveAvatar.isLive, isTrue);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey<String>('ss-live-avatar-pulse-opacity')),
          )
          .opacity,
      .78,
    );
    await tester.pump(const Duration(milliseconds: 850));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey<String>('ss-live-avatar-pulse-opacity')),
          )
          .opacity,
      .22,
    );
    expect(find.byType(SsRecordingTile), findsOneWidget);
    expect(find.byType(SsActiveRecordingCard), findsOneWidget);
    expect(find.byType(SsRecordingBar), findsOneWidget);
    expect(find.byType(SsInlineAlert), findsOneWidget);
    expect(find.byType(SsFilterChips), findsOneWidget);
    expect(find.byType(SsBannerAdSlot), findsOneWidget);
    expect(find.byType(SsChecklist), findsOneWidget);

    await tester.ensureVisible(find.text('Open sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    expect(find.byType(SsBottomSheet), findsOneWidget);
    Navigator.of(tester.element(find.byType(SsBottomSheet))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Show toast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show toast'));
    await tester.pump();
    expect(find.text('Toast'), findsOneWidget);
  });
}
