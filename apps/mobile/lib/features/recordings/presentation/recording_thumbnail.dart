import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme/ss_tokens.dart';
import 'controllers/recording_library_controller.dart';
import 'controllers/recording_providers.dart';
import 'models/recording_library_item.dart';

/// Loads only the first frame and keeps playback paused, so a recording looks
/// like familiar video content without maintaining a second thumbnail store.
class RecordingThumbnail extends ConsumerStatefulWidget {
  const RecordingThumbnail({
    required this.recordingId,
    required this.storage,
    this.filePath,
    this.enabled = true,
    this.showPlayOverlay = true,
    this.onTap,
    this.borderRadius = SsRadii.md,
    super.key,
  });

  final String recordingId;
  final RecordingLibraryStorage storage;
  final String? filePath;
  final bool enabled;
  final bool showPlayOverlay;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  ConsumerState<RecordingThumbnail> createState() => _RecordingThumbnailState();
}

class _RecordingThumbnailState extends ConsumerState<RecordingThumbnail> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.enabled && !Platform.environment.containsKey('FLUTTER_TEST')) {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant RecordingThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordingId != widget.recordingId ||
        oldWidget.storage != widget.storage ||
        oldWidget.filePath != widget.filePath ||
        oldWidget.enabled != widget.enabled) {
      _disposeController();
      if (widget.enabled && !Platform.environment.containsKey('FLUTTER_TEST')) {
        _load();
      }
    }
  }

  Future<void> _load() async {
    VideoPlayerController? next;
    try {
      if (widget.storage == RecordingLibraryStorage.local) {
        final String? path =
            widget.filePath ??
            (await ref.read(
              localRecordingLibraryDetailProvider(widget.recordingId).future,
            ))?.filePath;
        if (path == null || !File(path).existsSync()) return;
        next = VideoPlayerController.file(File(path));
      } else {
        final artifacts = await ref.read(
          recordingArtifactsProvider(widget.recordingId).future,
        );
        if (artifacts.isEmpty) return;
        final download = await ref
            .read(recordingControllerProvider)
            .createArtifactDownloadUrl(artifacts.first.id);
        if (download.isExpired) return;
        next = VideoPlayerController.networkUrl(download.uri);
      }
      await next.initialize();
      await next.pause();
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() {
        _controller = next;
      });
    } on Object {
      await next?.dispose();
    }
  }

  void _disposeController() {
    final VideoPlayerController? previous = _controller;
    _controller = null;
    previous?.dispose();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final VideoPlayerController? controller = _controller;

    return Semantics(
      button: widget.onTap != null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Material(
          color: colors.surfaceContainerHighest,
          child: InkWell(
            onTap: widget.enabled ? widget.onTap : null,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (controller?.value.isInitialized ?? false)
                  FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: controller!.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  )
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          colors.primaryContainer,
                          colors.surfaceContainerHighest,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.movie_creation_outlined,
                        color: colors.onSurfaceVariant,
                        size: 34,
                      ),
                    ),
                  ),
                if (widget.showPlayOverlay && controller != null)
                  Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.62),
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(9),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
