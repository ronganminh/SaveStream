import 'package:flutter/material.dart';

abstract interface class SsVideoController {
  bool get isPlaying;
  Duration get position;
  Duration get duration;

  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> setFullscreen(bool fullscreen);
  Future<void> setLandscape(bool landscape);
}

class SsVideoSurface extends StatefulWidget {
  const SsVideoSurface({
    required this.controller,
    this.aspectRatio = 16 / 9,
    super.key,
  });

  final SsVideoController controller;
  final double aspectRatio;

  @override
  State<SsVideoSurface> createState() => _SsVideoSurfaceState();
}

class _SsVideoSurfaceState extends State<SsVideoSurface> {
  bool _fullscreen = false;
  bool _landscape = false;

  @override
  Widget build(BuildContext context) {
    final SsVideoController controller = widget.controller;
    final Duration duration = controller.duration;
    final int durationMs = duration.inMilliseconds <= 0
        ? 1
        : duration.inMilliseconds;
    final double progress =
        (controller.position.inMilliseconds / durationMs).clamp(0.0, 1.0);

    return Semantics(
      container: true,
      label: 'Video player',
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            children: <Widget>[
              const Expanded(
                child: Center(child: Icon(Icons.play_circle_outline_rounded, size: 56)),
              ),
              Slider(
                value: progress,
                onChanged: (double value) async {
                  await controller.seekTo(
                    Duration(milliseconds: (durationMs * value).round()),
                  );
                  if (mounted) setState(() {});
                },
              ),
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: controller.isPlaying ? 'Pause' : 'Play',
                    onPressed: () async {
                      if (controller.isPlaying) {
                        await controller.pause();
                      } else {
                        await controller.play();
                      }
                      if (mounted) setState(() {});
                    },
                    icon: Icon(
                      controller.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Back 10 seconds',
                    onPressed: () async {
                      await controller.seekTo(
                        controller.position - const Duration(seconds: 10),
                      );
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.replay_10_rounded),
                  ),
                  IconButton(
                    tooltip: 'Forward 10 seconds',
                    onPressed: () async {
                      await controller.seekTo(
                        controller.position + const Duration(seconds: 10),
                      );
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.forward_10_rounded),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Rotate',
                    onPressed: () async {
                      _landscape = !_landscape;
                      await controller.setLandscape(_landscape);
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.screen_rotation_rounded),
                  ),
                  IconButton(
                    tooltip: 'Fullscreen',
                    onPressed: () async {
                      _fullscreen = !_fullscreen;
                      await controller.setFullscreen(_fullscreen);
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.fullscreen_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
