import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/widgets/ss_video_surface.dart';
import 'package:savestream_mobile/platform/contracts/share_service.dart';

void main() {
  test('A4 fake share service records local file shares only', () async {
    final FakeShareService service = FakeShareService();

    await service.shareFile(
      filePath: '/recordings/local.mp4',
      displayName: 'Local recording',
    );

    expect(service.sharedFiles, hasLength(1));
    expect(service.sharedFiles.single.filePath, '/recordings/local.mp4');
    expect(service.sharedFiles.single.displayName, 'Local recording');
  });

  testWidgets('A4 video surface delegates playback controls', (
    WidgetTester tester,
  ) async {
    final _FakeVideoController controller = _FakeVideoController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SsVideoSurface(controller: controller),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(controller.isPlaying, isTrue);

    await tester.tap(find.byTooltip('Forward 10 seconds'));
    await tester.pump();
    expect(controller.position, const Duration(seconds: 10));

    await tester.tap(find.byTooltip('Fullscreen'));
    await tester.tap(find.byTooltip('Rotate'));
    await tester.pump();
    expect(controller.fullscreen, isTrue);
    expect(controller.landscape, isTrue);
  });
}

class _FakeVideoController implements SsVideoController {
  @override
  bool isPlaying = false;

  @override
  Duration position = Duration.zero;

  @override
  Duration duration = const Duration(minutes: 2);

  bool fullscreen = false;
  bool landscape = false;

  @override
  Future<void> pause() async {
    isPlaying = false;
  }

  @override
  Future<void> play() async {
    isPlaying = true;
  }

  @override
  Future<void> seekTo(Duration position) async {
    this.position = position < Duration.zero
        ? Duration.zero
        : position > duration
        ? duration
        : position;
  }

  @override
  Future<void> setFullscreen(bool fullscreen) async {
    this.fullscreen = fullscreen;
  }

  @override
  Future<void> setLandscape(bool landscape) async {
    this.landscape = landscape;
  }
}
