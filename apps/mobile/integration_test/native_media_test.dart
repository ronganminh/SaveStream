// Real native video decoding on Android/iOS for downloaded cloud recordings.
// Media is deterministic project-owned sample media served over localhost.
// This never touches TikTok, production accounts, ads or payment processors.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:savestream_mobile/features/recordings/presentation/recording_player_screen.dart';
import 'package:savestream_mobile/l10n/l10n.dart';
import 'package:video_player/video_player.dart';

const String mediaHost = String.fromEnvironment(
  'CI_MEDIA_HOST',
  defaultValue: '127.0.0.1',
);
const int mediaPort = int.fromEnvironment('CI_MEDIA_PORT', defaultValue: 18095);
Uri fixture(String route) => Uri.parse('http://$mediaHost:$mediaPort/$route');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android and iOS: recorded MP4 opens and plays in SaveStream player',
    (WidgetTester tester) async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'ci-playback-',
      );
      final File media = File('${temp.path}/recorded.mp4');
      final HttpClient http = HttpClient();
      try {
        final HttpClientResponse response = await (await http.getUrl(
          fixture('playback.mp4'),
        )).close().timeout(const Duration(seconds: 20));
        expect(response.statusCode, 200);
        await response.pipe(media.openWrite());
        expect(await media.length(), greaterThan(100000));

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: RecordingPlayerScreen(
                recordingId: 'ci-media',
                title: 'Actual CI recording playback',
                durationSeconds: 8,
                localPath: media.path,
              ),
            ),
          ),
        );

        for (
          int i = 0;
          i < 100 && find.byType(VideoPlayer).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        expect(
          find.byType(VideoPlayer),
          findsOneWidget,
          reason:
              'Native ExoPlayer/AVPlayer must decode the MP4 and initialize',
        );
        final VideoPlayer player = tester.widget<VideoPlayer>(
          find.byType(VideoPlayer),
        );
        expect(player.controller.value.isInitialized, isTrue);
        expect(
          player.controller.value.duration.inMilliseconds,
          greaterThan(1000),
        );

        final Finder play = find.byTooltip('Play');
        expect(play, findsOneWidget);
        await tester.tap(play);
        await tester.pump(const Duration(milliseconds: 200));
        expect(player.controller.value.isPlaying, isTrue);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1000)),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(player.controller.value.position.inMilliseconds, greaterThan(0));
        await tester.tap(find.byTooltip('Pause'));
        await tester.pump(const Duration(milliseconds: 150));
        expect(player.controller.value.isPlaying, isFalse);
      } finally {
        http.close(force: true);
        await tester.pumpWidget(const SizedBox.shrink());
        await temp.delete(recursive: true);
      }
    },
  );
}
