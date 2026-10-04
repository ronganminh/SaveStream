import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart' show Override;
import 'package:riverpod/riverpod.dart' show Override;
import 'package:savestream_mobile/features/devices/domain/models/device_registration.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/controllers/recording_platform_controller.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/local_recovery_screen.dart';
import 'package:savestream_mobile/features/settings/presentation/android_oem_recording_guidance_screen.dart';
import 'package:savestream_mobile/features/settings/presentation/android_recording_background_screen.dart';
import 'package:savestream_mobile/features/settings/presentation/ios_recording_guidance_screen.dart';
import 'package:savestream_mobile/l10n/l10n.dart';
import 'package:savestream_mobile/platform/contracts/local_recorder.dart';
import 'package:savestream_mobile/platform/contracts/local_recovery_service.dart';
import 'package:savestream_mobile/platform/contracts/recording_platform_service.dart';
import 'package:savestream_mobile/platform/fakes/fake_device_info_service.dart';
import 'package:savestream_mobile/platform/fakes/fake_local_recovery_service.dart';
import 'package:savestream_mobile/platform/fakes/fake_recording_platform_service.dart';
import 'package:savestream_mobile/platform/platform_providers.dart';

void main() {
  Widget localized({
    required Widget child,
    List<Override> overrides = const <Override>[],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  testWidgets('AN01 maps the 60-second state to an Android notification', (
    WidgetTester tester,
  ) async {
    final FakeRecordingPlatformService service = FakeRecordingPlatformService();

    await tester.pumpWidget(
      localized(
        overrides: <Override>[
          recordingPlatformServiceProvider.overrideWithValue(service),
        ],
        child: const Scaffold(body: Text('platform')),
      ),
    );

    final BuildContext context = tester.element(find.byType(Scaffold));
    final ProviderContainer container = ProviderScope.containerOf(context);
    await container
        .read(recordingPlatformControllerProvider)
        .syncAndroidNotification(
          l10n: AppLocalizations.of(context)!,
          creatorName: 'Lina Studio',
          state: const LocalRecorderState(
            phase: LocalRecorderPhase.recording,
            recordedSeconds: 372,
          ),
          unlimited: false,
          remainingSeconds: 58,
        );

    expect(
      service.lastNotification?.kind,
      RecordingNotificationKind.minuteWarning,
    );
    expect(service.lastNotification?.title, contains('Lina Studio'));
    expect(service.lastNotification?.body, contains('10 minutes'));
  });

  testWidgets('IO01 schedules return reminder only while iOS Local is active', (
    WidgetTester tester,
  ) async {
    final FakeRecordingPlatformService service = FakeRecordingPlatformService(
      platform: DevicePlatform.ios,
      returnReminderEnabled: true,
    );

    await tester.pumpWidget(
      localized(
        overrides: <Override>[
          recordingPlatformServiceProvider.overrideWithValue(service),
        ],
        child: const Scaffold(body: Text('ios')),
      ),
    );

    final BuildContext context = tester.element(find.byType(Scaffold));
    final ProviderContainer container = ProviderScope.containerOf(context);
    final RecordingPlatformController controller = container.read(
      recordingPlatformControllerProvider,
    );

    await controller.handleIosLifecycle(
      state: AppLifecycleState.paused,
      creatorName: 'Lina Studio',
      activeRecording: true,
    );
    expect(service.iosReminderScheduled, isTrue);
    expect(service.screenAwake, isFalse);

    await controller.handleIosLifecycle(
      state: AppLifecycleState.resumed,
      creatorName: 'Lina Studio',
      activeRecording: true,
    );
    expect(service.iosReminderScheduled, isFalse);
    expect(service.screenAwake, isTrue);
  });

  testWidgets('AN02 shows battery optimization guidance', (
    WidgetTester tester,
  ) async {
    final FakeRecordingPlatformService service = FakeRecordingPlatformService(
      androidState: const AndroidRecordingPlatformState(
        batteryMode: AndroidBatteryMode.optimized,
        oemFamily: AndroidOemFamily.generic,
        deviceName: 'Pixel 9',
      ),
    );

    await tester.pumpWidget(
      localized(
        overrides: <Override>[
          recordingPlatformServiceProvider.overrideWithValue(service),
        ],
        child: const AndroidRecordingBackgroundScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make Local recording more reliable'), findsOneWidget);
    expect(find.text('Battery optimization'), findsOneWidget);
    expect(find.text('Open battery settings'), findsOneWidget);
  });

  testWidgets('AN03 renders Xiaomi HyperOS guidance', (
    WidgetTester tester,
  ) async {
    final FakeRecordingPlatformService service = FakeRecordingPlatformService(
      androidState: const AndroidRecordingPlatformState(
        batteryMode: AndroidBatteryMode.optimized,
        oemFamily: AndroidOemFamily.xiaomi,
        deviceName: 'Xiaomi 14',
        osName: 'HyperOS',
      ),
    );

    await tester.pumpWidget(
      localized(
        overrides: <Override>[
          recordingPlatformServiceProvider.overrideWithValue(service),
        ],
        child: const AndroidOemRecordingGuidanceScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keep SaveStream running on Xiaomi 14'), findsOneWidget);
    expect(find.textContaining('HyperOS can close SaveStream'), findsOneWidget);
    expect(find.text('Allow SaveStream to auto-start'), findsOneWidget);
  });

  testWidgets('IO02 uses iOS interruption copy and offers recovery', (
    WidgetTester tester,
  ) async {
    final FakeLocalRecoveryService recovery = FakeLocalRecoveryService(
      candidate: LocalRecoveryCandidate(
        tempId: 'temp_ios',
        watchId: 'watch_1',
        creatorDisplayName: 'Lina Studio',
        creatorHandle: '@linastudio',
        startedAt: DateTime.utc(2026, 10, 4, 4, 22),
        interruptedAt: DateTime.utc(2026, 10, 4, 4, 41),
        recordedSeconds: 1120,
        sizeBytes: 640 * 1024 * 1024,
      ),
      outcome: LocalRecoveryOutcome.partial,
    );

    await tester.pumpWidget(
      localized(
        overrides: <Override>[
          localRecoveryServiceProvider.overrideWithValue(recovery),
          deviceInfoServiceProvider.overrideWithValue(
            const FakeDeviceInfoService(platform: DevicePlatform.ios),
          ),
        ],
        child: const LocalRecoveryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recording was interrupted'), findsOneWidget);
    expect(find.textContaining('iOS stopped SaveStream'), findsOneWidget);
    expect(find.text('Recover'), findsOneWidget);
    expect(find.text('Advertisement'), findsNothing);
  });

  testWidgets('IO03 exposes the return-reminder toggle', (
    WidgetTester tester,
  ) async {
    final FakeRecordingPlatformService service = FakeRecordingPlatformService(
      platform: DevicePlatform.ios,
      returnReminderEnabled: true,
    );

    await tester.pumpWidget(
      localized(
        overrides: <Override>[
          recordingPlatformServiceProvider.overrideWithValue(service),
        ],
        child: const IosRecordingGuidanceScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Record on iPhone'), findsOneWidget);
    expect(find.text('Keep SaveStream open while recording'), findsOneWidget);
    expect(find.text('Remind me to return to SaveStream'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(service.returnReminderEnabled, isFalse);
  });
}
