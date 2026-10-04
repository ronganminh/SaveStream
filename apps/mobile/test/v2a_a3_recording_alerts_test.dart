import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/local_recording_alerts.dart';
import 'package:savestream_mobile/l10n/l10n.dart';
import 'package:savestream_mobile/platform/contracts/local_recorder.dart';

void main() {
  Widget app(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('R03 switches to slow copy after eight seconds', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        const LocalRecordingAlerts(
          state: LocalRecorderState(phase: LocalRecorderPhase.starting),
          creatorName: 'Lina Studio',
          remainingSeconds: 600,
          isUnlimited: false,
          minutesPerReward: 10,
        ),
      ),
    );

    expect(find.text("Connecting to Lina Studio's LIVE…"), findsOneWidget);
    expect(find.text('Connecting is taking longer than usual…'), findsNothing);

    await tester.pump(const Duration(seconds: 8));

    expect(find.text('Connecting is taking longer than usual…'), findsOneWidget);
  });

  testWidgets('R05 warns and haptics once inside sixty seconds', (
    WidgetTester tester,
  ) async {
    int warningCalls = 0;

    await tester.pumpWidget(
      app(
        LocalRecordingAlerts(
          state: const LocalRecorderState(
            phase: LocalRecorderPhase.recording,
            recordedSeconds: 542,
            sizeBytes: 214 * 1024 * 1024,
          ),
          creatorName: 'Lina Studio',
          remainingSeconds: 58,
          isUnlimited: false,
          minutesPerReward: 10,
          onMinuteWarningEntered: () => warningCalls += 1,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Less than 1 minute of Free time left'), findsOneWidget);
    expect(
      find.text('Recording will stop and save when your Free time runs out.'),
      findsOneWidget,
    );
    expect(warningCalls, 1);

    await tester.pumpWidget(
      app(
        LocalRecordingAlerts(
          state: const LocalRecorderState(
            phase: LocalRecorderPhase.recording,
            recordedSeconds: 543,
            sizeBytes: 215 * 1024 * 1024,
          ),
          creatorName: 'Lina Studio',
          remainingSeconds: 57,
          isUnlimited: false,
          minutesPerReward: 10,
          onMinuteWarningEntered: () => warningCalls += 1,
        ),
      ),
    );
    await tester.pump();

    expect(warningCalls, 1);
    expect(find.text('Advertisement'), findsNothing);
  });
}
