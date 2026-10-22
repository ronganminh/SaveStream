import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/recordings/presentation/active_recording_bar.dart';
import 'package:savestream_mobile/l10n/l10n.dart';

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
              id: 'rec_1',
              creatorName: 'Lina Studio',
              engine: Engine.cloud,
              elapsedSeconds: 372,
              route: '/recordings/rec_1',
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
              id: 'rec_1',
              creatorName: 'Lina Studio',
              engine: Engine.cloud,
              elapsedSeconds: 4360,
              route: '/recordings/rec_1',
            ),
            ActiveRecordingBarItem(
              id: 'rec_2',
              creatorName: 'Mike Fitness',
              engine: Engine.cloud,
              elapsedSeconds: 138,
              route: '/recordings/rec_2',
            ),
          ],
        ),
      ),
    );

    expect(find.text('2 recordings running'), findsOneWidget);
    expect(find.text('01:12:40 · 00:02:18'), findsOneWidget);
  });
}
