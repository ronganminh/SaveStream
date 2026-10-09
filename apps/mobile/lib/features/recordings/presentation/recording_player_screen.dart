import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/flv_timestamp_normalizer.dart';
import '../../../platform/video_player_ss_controller.dart';
import '../../local_recordings/domain/models/local_recording_models.dart';
import 'controllers/recording_library_controller.dart';
import 'controllers/recording_providers.dart';
import 'recording_ui_helpers.dart';

enum RecordingPlaybackSource {
  local,
  cloud;

  static RecordingPlaybackSource fromValue(String? value) {
    return value == 'local'
        ? RecordingPlaybackSource.local
        : RecordingPlaybackSource.cloud;
  }
}

/// L08 / L08-landscape — Player controls backed by video_player.
class RecordingPlayerScreen extends ConsumerStatefulWidget {
  const RecordingPlayerScreen({
    required this.recordingId,
    required this.source,
    required this.title,
    required this.durationSeconds,
    this.startedAt,
    this.localPath,
    super.key,
  });

  final String recordingId;
  final RecordingPlaybackSource source;
  final String title;
  final int durationSeconds;
  final DateTime? startedAt;
  final String? localPath;

  @override
  ConsumerState<RecordingPlayerScreen> createState() =>
      _RecordingPlayerScreenState();
}

class _RecordingPlayerScreenState extends ConsumerState<RecordingPlayerScreen> {
  VideoPlayerSsController? _controller;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final VideoPlayerSsController? previous = _controller;
    _controller = null;
    previous?.dispose();

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final VideoPlayerSsController controller = switch (widget.source) {
        RecordingPlaybackSource.local => await _localController(),
        RecordingPlaybackSource.cloud => await _cloudController(),
      };
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<VideoPlayerSsController> _localController() async {
    if (widget.localPath case final String path when path.isNotEmpty) {
      await normalizeFlvTimestamps(path);
      return VideoPlayerSsController.file(path);
    }
    final LocalRecordingSummary? recording = await ref.read(
      localRecordingLibraryDetailProvider(widget.recordingId).future,
    );
    final String? path = recording?.filePath;
    if (recording == null || !recording.fileAvailable || path == null) {
      throw StateError('Local recording file is unavailable.');
    }
    await normalizeFlvTimestamps(path);
    return VideoPlayerSsController.file(path);
  }

  Future<VideoPlayerSsController> _cloudController() async {
    final artifacts = await ref.read(
      recordingArtifactsProvider(widget.recordingId).future,
    );
    if (artifacts.isEmpty) {
      throw StateError('Cloud recording artifact is unavailable.');
    }

    final download = await ref
        .read(recordingControllerProvider)
        .createArtifactDownloadUrl(artifacts.first.id);
    if (download.isExpired) {
      throw StateError('Cloud recording URL expired before playback.');
    }
    return VideoPlayerSsController.network(download.uri);
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerSsController? controller = _controller;

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: SsAsyncErrorState(error: _error!, onRetry: _load),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: _loading || controller == null
            ? Stack(
                children: <Widget>[
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  SafeArea(
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            : _RecordingPlayerView(
                controller: controller,
                title: widget.title,
                durationSeconds: widget.durationSeconds,
                source: widget.source,
                startedAt: widget.startedAt,
              ),
      ),
    );
  }
}

class _RecordingPlayerView extends StatefulWidget {
  const _RecordingPlayerView({
    required this.controller,
    required this.title,
    required this.durationSeconds,
    required this.source,
    required this.startedAt,
  });

  final VideoPlayerSsController controller;
  final String title;
  final int durationSeconds;
  final RecordingPlaybackSource source;
  final DateTime? startedAt;

  @override
  State<_RecordingPlayerView> createState() => _RecordingPlayerViewState();
}

class _RecordingPlayerViewState extends State<_RecordingPlayerView> {
  Timer? _hideTimer;
  bool _showControls = true;
  bool _fullscreen = false;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!widget.controller.isPlaying) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  Future<void> _togglePlayback() async {
    if (widget.controller.isPlaying) {
      await widget.controller.pause();
      _hideTimer?.cancel();
      if (mounted) setState(() => _showControls = true);
    } else {
      await widget.controller.play();
      if (mounted) {
        setState(() => _showControls = true);
        _scheduleHide();
      }
    }
  }

  Future<void> _seekBy(Duration offset) async {
    await widget.controller.seekTo(widget.controller.position + offset);
    if (mounted) {
      setState(() => _showControls = true);
      _scheduleHide();
    }
  }

  Future<void> _toggleFullscreen() async {
    final bool next = !_fullscreen;
    _fullscreen = next;
    await widget.controller.setFullscreen(next);
    await widget.controller.setLandscape(next);
    if (mounted) setState(() {});
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    await widget.controller.setPlaybackSpeed(speed);
    if (mounted) {
      setState(() => _showControls = true);
      _scheduleHide();
    }
  }

  String _clock(Duration value) {
    final int hours = value.inHours;
    final String minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final String seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final Duration reportedDuration = widget.controller.duration;
        final Duration fallbackDuration = Duration(
          seconds: widget.durationSeconds,
        );
        final Duration duration = reportedDuration >= const Duration(seconds: 2)
            ? reportedDuration
            : fallbackDuration;
        final Duration position = widget.controller.position > duration
            ? duration
            : widget.controller.position;
        final double max = duration.inMilliseconds <= 0
            ? 1
            : duration.inMilliseconds.toDouble();
        final double value = position.inMilliseconds.toDouble().clamp(0, max);
        final bool buffering = widget.controller.player.value.isBuffering;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Center(
                child: AspectRatio(
                  aspectRatio: widget.controller.aspectRatio,
                  child: VideoPlayer(widget.controller.player),
                ),
              ),
              if (buffering)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.center,
                            colors: <Color>[Colors.black87, Colors.transparent],
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: .42,
                          widthFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: <Color>[
                                  Colors.black.withValues(alpha: .92),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SsSpacing.sm,
                            vertical: SsSpacing.xs,
                          ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Row(
                              children: <Widget>[
                                IconButton(
                                  tooltip: 'Close',
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: SsSpacing.xs),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        widget.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(color: Colors.white),
                                      ),
                                      if (widget.startedAt != null)
                                        Text(
                                          recordingTimestamp(
                                            context,
                                            widget.startedAt,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: Colors.white70),
                                        ),
                                    ],
                                  ),
                                ),
                                SsStatusChip(
                                  label:
                                      widget.source ==
                                          RecordingPlaybackSource.local
                                      ? context.l10n.localLabel
                                      : context.l10n.cloudLabel,
                                  tone:
                                      widget.source ==
                                          RecordingPlaybackSource.local
                                      ? SsStatusTone.local
                                      : SsStatusTone.cloud,
                                  icon:
                                      widget.source ==
                                          RecordingPlaybackSource.local
                                      ? Icons.smartphone_rounded
                                      : Icons.cloud_rounded,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              SsSpacing.lg,
                              0,
                              SsSpacing.sm,
                              SsSpacing.sm,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white30,
                                    thumbColor: Colors.white,
                                    overlayColor: Colors.white12,
                                    trackHeight: 3,
                                  ),
                                  child: Slider(
                                    value: value,
                                    max: max,
                                    onChanged: (double milliseconds) {
                                      widget.controller.seekTo(
                                        Duration(
                                          milliseconds: milliseconds.round(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Row(
                                  children: <Widget>[
                                    Text(
                                      _clock(position),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(color: Colors.white),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _clock(duration),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(color: Colors.white),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: <Widget>[
                                    PopupMenuButton<double>(
                                      tooltip: context
                                          .l10n
                                          .recordingPlayerSpeedTooltip,
                                      initialValue:
                                          widget.controller.playbackSpeed,
                                      color: Colors.black87,
                                      onSelected: _setPlaybackSpeed,
                                      itemBuilder: (_) => <PopupMenuEntry<double>>[
                                        for (final double speed in <double>[
                                          .5,
                                          1,
                                          1.5,
                                          2,
                                        ])
                                          PopupMenuItem<double>(
                                            value: speed,
                                            child: Text(
                                              '${speed == speed.roundToDouble() ? speed.toInt() : speed}×',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: SsSpacing.sm,
                                          vertical: SsSpacing.md,
                                        ),
                                        child: Text(
                                          '${widget.controller.playbackSpeed == widget.controller.playbackSpeed.roundToDouble() ? widget.controller.playbackSpeed.toInt() : widget.controller.playbackSpeed}×',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    _PlayerRoundButton(
                                      tooltip: 'Back 10 seconds',
                                      icon: Icons.replay_10_rounded,
                                      onPressed: () =>
                                          _seekBy(const Duration(seconds: -10)),
                                    ),
                                    const SizedBox(width: SsSpacing.md),
                                    _PlayerRoundButton(
                                      tooltip: widget.controller.isPlaying
                                          ? 'Pause'
                                          : 'Play',
                                      icon: widget.controller.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      prominent: true,
                                      onPressed: _togglePlayback,
                                    ),
                                    const SizedBox(width: SsSpacing.md),
                                    _PlayerRoundButton(
                                      tooltip: 'Forward 10 seconds',
                                      icon: Icons.forward_10_rounded,
                                      onPressed: () =>
                                          _seekBy(const Duration(seconds: 10)),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: 'Fullscreen',
                                      onPressed: _toggleFullscreen,
                                      icon: Icon(
                                        _fullscreen
                                            ? Icons.fullscreen_exit_rounded
                                            : Icons.fullscreen_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerRoundButton extends StatelessWidget {
  const _PlayerRoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.prominent = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: prominent
            ? Colors.white
            : Colors.black.withValues(alpha: .48),
        foregroundColor: prominent ? Colors.black : Colors.white,
        minimumSize: Size.square(prominent ? 68 : 52),
      ),
      iconSize: prominent ? 38 : 28,
      icon: Icon(icon),
    );
  }
}
