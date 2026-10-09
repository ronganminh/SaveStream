import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../core/widgets/ss_video_surface.dart';

final class VideoPlayerSsController extends ChangeNotifier
    implements SsVideoController {
  VideoPlayerSsController.file(String path)
    : _player = VideoPlayerController.file(File(path)) {
    _player.addListener(_relay);
  }

  VideoPlayerSsController.network(Uri uri)
    : _player = VideoPlayerController.networkUrl(uri) {
    _player.addListener(_relay);
  }

  final VideoPlayerController _player;
  bool _closed = false;

  VideoPlayerController get player => _player;

  bool get isInitialized => _player.value.isInitialized;

  double get aspectRatio {
    final double value = _player.value.aspectRatio;
    return value > 0 ? value : 16 / 9;
  }

  Future<void> initialize() async {
    await _player.initialize();
    notifyListeners();
  }

  @override
  bool get isPlaying => _player.value.isPlaying;

  @override
  Duration get position => _player.value.position;

  @override
  Duration get duration => _player.value.duration;

  double get playbackSpeed => _player.value.playbackSpeed;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  Future<void> setPlaybackSpeed(double speed) =>
      _player.setPlaybackSpeed(speed);

  @override
  Future<void> seekTo(Duration value) {
    final Duration target = value < Duration.zero
        ? Duration.zero
        : duration >= const Duration(seconds: 2) && value > duration
        ? duration
        : value;
    return _player.seekTo(target);
  }

  @override
  Future<void> setFullscreen(bool fullscreen) {
    return SystemChrome.setEnabledSystemUIMode(
      fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  @override
  Future<void> setLandscape(bool landscape) {
    return SystemChrome.setPreferredOrientations(
      landscape
          ? <DeviceOrientation>[
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : <DeviceOrientation>[
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
    );
  }

  Future<void> _disposePlayer() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
    await _player.dispose();
  }

  void _relay() {
    if (!_closed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _player.removeListener(_relay);
    unawaited(_disposePlayer());
    super.dispose();
  }
}
