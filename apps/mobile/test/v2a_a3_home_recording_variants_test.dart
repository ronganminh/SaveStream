import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/home/presentation/home_recording_widgets.dart';
import 'package:savestream_mobile/features/recordings/presentation/active_recording_bar.dart';
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

  testWidgets('recording bar renders one active recording compactly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        const ActiveRecordingBar(
          items: <ActiveRecordingBarItem>[
            ActiveRecordingBarItem(
              id: 'local_1',
              creatorName: 'Lina Studio',
              engine: Engine.local,
              elapsedSeconds: 372,
              route: '/recordings/local/watch_1',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Lina Studio is recording'), findsOneWidget);
    expect(find.text('00:06:12'), findsOneWidget);
  });

  testWidgets('recording bar summarizes two active recordings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        const ActiveRecordingBar(
          items: <ActiveRecordingBarItem>[
            ActiveRecordingBarItem(
              id: 'local_1',
              creatorName: 'Lina Studio',
              engine: Engine.local,
              elapsedSeconds: 4360,
              route: '/recordings/local/watch_1',
            ),
            ActiveRecordingBarItem(
              id: 'local_2',
              creatorName: 'Mike Fitness',
              engine: Engine.local,
              elapsedSeconds: 138,
              route: '/recordings/local/watch_2',
            ),
          ],
        ),
      ),
    );

    expect(find.text('2 recordings running'), findsOneWidget);
    expect(find.text('01:12:40 · 00:02:18'), findsOneWidget);
  });

  testWidgets('H04 Local active card shows elapsed and server lease remaining', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        const HomeLocalRecordingCard(
          creatorName: 'Lina Studio',
          watchId: 'watch_1',
          state: LocalRecorderState(
            phase: LocalRecorderPhase.recording,
            recordedSeconds: 372,
            sizeBytes: 214 * 1024 * 1024,
          ),
          remainingSeconds: 228,
          unlimited: false,
        ),
      ),
    );

    expect(find.text('Lina Studio'), findsOneWidget);
    expect(find.text('00:06:12'), findsOneWidget);
    expect(find.textContaining('00:03:48 remaining'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
  });

  testWidgets('H05 second Local slot shows server expiry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        HomeSecondSlotOpenCard(
          expiresAt: DateTime(2026, 10, 4, 15, 42),
        ),
      ),
    );

    expect(find.text('Local slot #2 is open'), findsOneWidget);
    expect(find.textContaining('15:42'), findsOneWidget);
  });

  testWidgets('H07 finalizing shows step number instead of percent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        const HomeFinalizingRecordingCard(
          creatorName: 'Lina Studio',
          step: LocalFinalizationStep.flushFile,
        ),
      ),
    );

    expect(find.text('Finishing Lina Studio'), findsOneWidget);
    expect(
      find.text('Step 2/4 · Write final data to file'),
      findsOneWidget,
    );
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('H09 shows exhausted Free minutes and rewarded-ad cap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        HomeDailyRecordingExhaustedCard(
          dailyMinutes: 10,
          rewardsUsed: 8,
          rewardsCap: 8,
          resetLabel: '3 h 20 min',
          onBuyCloudHours: () {},
        ),
      ),
    );

    expect(
      find.text('Free recording and rewarded ads are used up today'),
      findsOneWidget,
    );
    expect(
      find.textContaining('0 / 10 Free minutes · 8/8 rewarded ads'),
      findsOneWidget,
    );
    expect(find.text('Buy cloud hours'), findsOneWidget);
  });
}
