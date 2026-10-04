import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/local_recordings/domain/models/local_recording_models.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/local_recording_screen.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
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

  testWidgets('R17 shows recorder-calculated low storage telemetry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        const LocalRecordingStorageAlert(
          state: LocalRecorderState(
            phase: LocalRecorderPhase.recording,
            storageState: LocalStorageState.low,
            freeStorageBytes: 800 * 1024 * 1024,
            estimatedStorageMinutes: 12,
          ),
        ),
      ),
    );

    expect(find.text('Storage is running low'), findsOneWidget);
    expect(find.textContaining('about 12 minutes'), findsOneWidget);
    expect(find.textContaining('250 MB'), findsOneWidget);
    expect(find.text('Clean up old recordings'), findsOneWidget);
  });

  testWidgets('R18 shows critical storage stop message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        const LocalRecordingStorageAlert(
          state: LocalRecorderState(
            phase: LocalRecorderPhase.recording,
            storageState: LocalStorageState.critical,
            freeStorageBytes: 200 * 1024 * 1024,
          ),
        ),
      ),
    );

    expect(find.text('Storage is almost full'), findsOneWidget);
    expect(find.textContaining('Less than 250 MB'), findsOneWidget);
    expect(find.text('Clean up old recordings'), findsNothing);
  });

  testWidgets('R20 finalizing uses steps and never fake percent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        const LocalRecordingFinalizingBody(
          step: LocalFinalizationStep.verifyFile,
        ),
      ),
    );

    expect(find.text('Finishing recording'), findsOneWidget);
    expect(find.text('Stop capture'), findsOneWidget);
    expect(find.text('Write final data to file'), findsOneWidget);
    expect(find.text('Verify file'), findsOneWidget);
    expect(find.text('Add to Recordings'), findsOneWidget);
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('R21 completed has recording and Home actions without ads', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        LocalRecordingCompletedBody(
          creatorName: 'Lina Studio',
          summary: LocalRecordingSummary(
            id: 'local_1',
            watchId: 'watch_1',
            creatorDisplayName: 'Lina Studio',
            creatorHandle: '@linastudio',
            deviceId: 'device_1',
            deviceName: 'Phone',
            startedAt: DateTime.utc(2026, 10, 4, 4),
            recordedSeconds: 372,
            sizeBytes: 214 * 1024 * 1024,
            status: RecordingStatus.completed,
          ),
        ),
      ),
    );

    expect(find.text('Recording saved'), findsOneWidget);
    expect(find.text('Open recording'), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
    expect(find.text('Advertisement'), findsNothing);
  });
}
