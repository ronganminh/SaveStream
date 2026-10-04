import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/widgets/savestream_widgets.dart';
import '../../../platform/video_player_ss_controller.dart';
import '../../local_recordings/domain/models/local_recording_models.dart';
import 'controllers/recording_library_controller.dart';
import 'controllers/recording_providers.dart';

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
    super.key,
  });

  final String recordingId;
  final RecordingPlaybackSource source;
  final String title;
  final int durationSeconds;

  @override
  ConsumerState<RecordingPlayerScreen> createState() =>
      _RecordingPlayerScreenState();
}

class _RecordingPlayerScreenState
    extends ConsumerState<RecordingPlayerScreen> {
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
    final LocalRecordingSummary? recording = await ref.read(
      localRecordingLibraryDetailProvider(widget.recordingId).future,
    );
    final String? path = recording?.filePath;
    if (recording == null || !recording.fileAvailable || path == null) {
      throw StateError('Local recording file is unavailable.');
    }
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

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : _error != null
              ? SsAsyncErrorState(error: _error!, onRetry: _load)
              : AnimatedBuilder(
                  animation: controller!,
                  builder: (BuildContext context, Widget? child) {
                    return SsVideoSurface(
                      controller: controller,
                      aspectRatio: controller.aspectRatio,
                      media: controller.isInitialized
                          ? VideoPlayer(controller.player)
                          : null,
                    );
                  },
                ),
        ),
      ),
    );
  }
}
