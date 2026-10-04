import 'package:flutter/material.dart';

import '../../../core/widgets/savestream_widgets.dart';

/// L08 / L08-landscape — Player controls. Track C supplies the real controller.
class RecordingPlayerScreen extends StatelessWidget {
  const RecordingPlayerScreen({
    required this.title,
    required this.durationSeconds,
    super.key,
  });

  final String title;
  final int durationSeconds;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SsVideoSurface(
            controller: _PreviewVideoController(
              duration: Duration(seconds: durationSeconds),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewVideoController implements SsVideoController {
  _PreviewVideoController({required this.duration});

  @override
  bool isPlaying = false;

  @override
  Duration position = Duration.zero;

  @override
  final Duration duration;

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
  Future<void> seekTo(Duration value) async {
    position = value < Duration.zero
        ? Duration.zero
        : value > duration
        ? duration
        : value;
  }

  @override
  Future<void> setFullscreen(bool value) async {
    fullscreen = value;
  }

  @override
  Future<void> setLandscape(bool value) async {
    landscape = value;
  }
}
