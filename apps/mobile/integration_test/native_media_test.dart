// Real native video decoding on Android/iOS, plus Android foreground recording.
// Media is deterministic project-owned sample media served over localhost.
// This never touches TikTok, production accounts, ads or payment processors.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:savestream_mobile/features/local_recordings/domain/models/local_recording_models.dart';
import 'package:savestream_mobile/features/recordings/presentation/recording_player_screen.dart';
import 'package:savestream_mobile/platform/android_local_recorder.dart';
import 'package:savestream_mobile/platform/contracts/local_recorder.dart';
import 'package:savestream_mobile/platform/video_player_ss_controller.dart';
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
              home: RecordingPlayerScreen(
                recordingId: 'ci-media',
                source: RecordingPlaybackSource.local,
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

  test(
    'Android: real native foreground recorder captures FLV bytes to disk',
    () async {
      if (!Platform.isAndroid) return;
      final AndroidLocalRecorder recorder = AndroidLocalRecorder(
        currentUserId: () async => 'ci-user',
      );
      final Completer<LocalRecorderState> completed =
          Completer<LocalRecorderState>();
      final subscription = recorder.watch().listen((LocalRecorderState state) {
        if (state.phase == LocalRecorderPhase.stopped ||
            state.phase == LocalRecorderPhase.error) {
          if (!completed.isCompleted) completed.complete(state);
        }
      });
      try {
        await recorder.start(
          LocalRecordingSession(
            sessionId: 'ci-native-capture',
            watchId: 'ci-stream',
            deviceId: 'ci-android',
            grantedSeconds: 12,
            leaseExpiresAt: DateTime.now().add(const Duration(seconds: 12)),
            streamUrl: fixture('stream.flv'),
            streamFormat: LocalStreamFormat.flv,
          ),
        );
        final LocalRecorderState state = await completed.future.timeout(
          const Duration(seconds: 35),
          onTimeout: () =>
              throw StateError('Android native recording never finalized'),
        );
        expect(
          state.phase,
          LocalRecorderPhase.stopped,
          reason: state.errorMessage ?? 'Unexpected native service failure',
        );
        expect(state.sizeBytes, greaterThan(64000));
        final Directory appDir = await getApplicationSupportDirectory();
        final File recorded = File(
          '${appDir.path}/local_recordings/ci-user/ci-android/ci-native-capture.flv',
        );
        expect(
          await recorded.exists(),
          isTrue,
          reason:
              'Android must persist its foreground recording in app storage',
        );
        expect(await recorded.length(), greaterThan(64000));
        expect(
          (await recorded.openRead(0, 3).toList()).expand((x) => x).toList(),
          <int>[0x46, 0x4c, 0x56],
        );
        final File metadata = File(
          '${recorded.parent.path}/ci-native-capture.json',
        );
        expect(await metadata.exists(), isTrue);
        // Actually play the same FLV written by the native foreground service.
        final VideoPlayerSsController playback = VideoPlayerSsController.file(
          recorded.path,
        );
        try {
          await playback.initialize().timeout(const Duration(seconds: 25));
          expect(playback.isInitialized, isTrue);
          expect(playback.duration.inMilliseconds, greaterThan(1000));
          await playback.play();
          expect(playback.isPlaying, isTrue);
          await playback.pause();
        } finally {
          playback.dispose();
        }
        await recorded.delete();
        await metadata.delete();
      } finally {
        await subscription.cancel();
      }
    },
    skip: Platform.isIOS ? 'iOS has no native Local recorder' : null,
  );
}
