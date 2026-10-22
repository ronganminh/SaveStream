/// APlayer · APlayerSaving · APlayerSaved · APlayerDelete · APlayerProcessing
/// · APlayerFailed — one cloud recording: playback, save, retention, delete.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/ss_feedback.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/video_player_ss_controller.dart';
import '../../channels/presentation/channel_v2_parts.dart';
import '../../home/presentation/controllers/home_dashboard_controller.dart';
import '../data/cloud_artifact_downloader.dart';
import '../data/cloud_recording_file_service.dart';
import '../domain/models/recording_summary.dart';
import 'controllers/recording_file_providers.dart';
import 'controllers/recording_providers.dart';
import 'recording_v2_parts.dart';

const double _heroHeight = 440;
const Color _heroProcessing = Color(0xFF3B2F6E);
const Color _heroFailed = Color(0xFF5A1A28);
const List<Color> _heroGradient = <Color>[Color(0xFF8B6CFF), Color(0xFF3B2F6E)];
const Color _toastBackground = Color(0xFF2B2840);
const Color _toastAction = Color(0xFFCFC4FF);

class RecordingDetailScreen extends ConsumerStatefulWidget {
  const RecordingDetailScreen({required this.recordingId, super.key});

  final String recordingId;

  @override
  ConsumerState<RecordingDetailScreen> createState() =>
      _RecordingDetailScreenState();
}

class _RecordingDetailScreenState extends ConsumerState<RecordingDetailScreen>
    with WidgetsBindingObserver {
  bool _isForeground = true;
  bool _busy = false;

  File? _saved;
  bool _checkedSaved = false;
  bool _saving = false;
  bool _cancelSave = false;
  int _received = 0;
  int? _total;
  bool _showSavedToast = false;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
    _isForeground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool foreground = state == AppLifecycleState.resumed;
    if (foreground != _isForeground) {
      setState(() => _isForeground = foreground);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toastTimer?.cancel();
    _cancelSave = true;
    super.dispose();
  }

  RecordingFileStore get _store => ref.read(cloudRecordingFileServiceProvider);

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.recordings);
    }
  }

  Future<RecordingArtifactSummary?> _artifact(String id) async {
    final List<RecordingArtifactSummary> items = await ref.read(
      recordingArtifactsProvider(id).future,
    );
    return items.isEmpty ? null : items.first;
  }

  Future<void> _checkSaved(RecordingSummary recording) async {
    try {
      final RecordingArtifactSummary? artifact = await _artifact(recording.id);
      final File? file = await _store.existingFile(
        recording.id,
        expectedSizeBytes: artifact?.sizeBytes,
      );
      if (mounted && file != null) setState(() => _saved = file);
    } on Object {
      // No saved copy (or no storage on this platform): offer Save.
    }
  }

  Future<void> _save(RecordingSummary recording) async {
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _saving = true;
      _cancelSave = false;
      _received = 0;
      _total = null;
    });
    try {
      final RecordingArtifactSummary? artifact = await _artifact(recording.id);
      if (artifact == null) throw StateError('No artifact to save.');
      if (mounted) setState(() => _total = artifact.sizeBytes);
      final File file = await _store.download(
        recordingId: recording.id,
        artifactId: artifact.id,
        isCancelled: () => _cancelSave,
        onProgress: ({required int receivedBytes, required int? totalBytes}) {
          if (!mounted) return;
          setState(() {
            _received = receivedBytes;
            _total = totalBytes ?? artifact.sizeBytes;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = file;
        _showSavedToast = true;
      });
      _toastTimer?.cancel();
      _toastTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _showSavedToast = false);
      });
    } on CloudDownloadCancelledException {
      if (mounted) setState(() => _saving = false);
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      SsSnackbar.show(context, l10n.v2PlayerSaveFailed);
    }
  }

  void _openSaved(RecordingSummary recording) {
    final File? file = _saved;
    if (file == null) return;
    final Uri uri = Uri.parse(AppRoutes.recordingPlayer(recording.id)).replace(
      queryParameters: <String, String>{
        'title': recordingHandle(recording),
        'duration': recording.durationSeconds.toString(),
        if (recording.startedAt != null)
          'started': recording.startedAt!.toIso8601String(),
        'path': file.path,
      },
    );
    context.push(uri.toString());
  }

  Future<void> _delete(RecordingSummary recording) async {
    final bool confirmed =
        await showDeleteRecordingDialog(
          context,
          name: recordingHandle(recording),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final AppLocalizations l10n = context.l10n;
    setState(() => _busy = true);
    try {
      _cancelSave = true;
      final RecordingFileStore store = _store;
      await ref.read(recordingControllerProvider).delete(recording.id);
      // The server copy is gone; removing the saved copy can finish in the
      // background (a leftover file would only take space).
      unawaited(store.delete(recording.id).catchError((Object _) {}));
      if (mounted) context.go(AppRoutes.recordings);
    } on Object {
      if (mounted) SsSnackbar.show(context, l10n.v2ActionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop(RecordingSummary recording) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await SsConfirmDialog.show(
      context,
      title: l10n.cloudRecordingStopConfirmTitle,
      message: l10n.cloudRecordingStopConfirmBody,
      cancelLabel: l10n.v2Cancel,
      confirmLabel: l10n.v2StopRecording,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(recordingControllerProvider).stop(recording.id);
    } on Object {
      if (mounted) SsSnackbar.show(context, l10n.v2ActionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final AsyncValue<RecordingSummary?> recording = _isForeground
        ? ref.watch(recordingRealtimeProvider(widget.recordingId))
        : ref.watch(recordingDetailProvider(widget.recordingId));
    final DateTime Function() clock = ref.watch(homeClockProvider);

    Widget message(String title, {VoidCallback? onRetry}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ChannelsTopBar(onBack: _back),
          Expanded(
            child: ChannelsCenteredMessage(
              glyph: SsV2IconGlyph.alert,
              title: title,
              body: onRetry == null ? '' : l10n.v2RecErrorBody,
              actionWidth: 200,
              action: onRetry == null
                  ? SsV2Button(
                      label: l10n.v2NavRecordings,
                      variant: SsV2ButtonVariant.outlined,
                      onPressed: () => context.go(AppRoutes.recordings),
                    )
                  : SsV2Button(
                      label: l10n.v2RetryShort,
                      variant: SsV2ButtonVariant.outlined,
                      onPressed: onRetry,
                    ),
            ),
          ),
        ],
      );
    }

    final Widget body = recording.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ChannelsTopBar(onBack: _back),
          const Expanded(child: Center(child: SsV2Spinner())),
        ],
      ),
      error: (Object error, StackTrace stackTrace) => message(
        l10n.v2PlayerLoadError,
        onRetry: () {
          ref.invalidate(recordingDetailProvider(widget.recordingId));
          ref.invalidate(recordingRealtimeProvider(widget.recordingId));
        },
      ),
      data: (RecordingSummary? value) {
        if (value == null) return message(l10n.v2PlayerNotFound);
        final RecordingGroup group = recordingGroupOf(value);
        if (group == RecordingGroup.ready && !_checkedSaved) {
          _checkedSaved = true;
          unawaited(_checkSaved(value));
        }
        return _content(context, value, group, clock());
      },
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: recording.value == null
          ? SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            ),
      child: Scaffold(
        backgroundColor: palette.background,
        body: DefaultTextStyle(
          style: ssV2BaseText(palette),
          child: recording.value == null ? SafeArea(child: body) : body,
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    RecordingSummary recording,
    RecordingGroup group,
    DateTime now,
  ) {
    final AppLocalizations l10n = context.l10n;
    final bool expired =
        group == RecordingGroup.ready && isExpired(recording, now);
    final bool playable = group == RecordingGroup.ready && !expired;
    final Widget hero = SizedBox(
      height: _heroHeight,
      child: switch (group) {
        RecordingGroup.ready => _PlayerSurface(
          recording: recording,
          localPath: _saved?.path,
          enabled: playable,
        ),
        RecordingGroup.processing => _StateHero(
          color: _heroProcessing,
          spinner: true,
          title: l10n.v2PlayerProcessingTitle,
          subtitle: recording.progress == null
              ? l10n.v2PlayerProcessingSub
              : l10n.v2PlayerProcessingPercent(
                  (recording.progress! * 100).round(),
                ),
        ),
        RecordingGroup.live => _LiveHero(
          recording: recording,
          clock: ref.watch(homeClockProvider),
        ),
        RecordingGroup.failed => _StateHero(
          color: _heroFailed,
          title: l10n.v2PlayerFailedTitle,
        ),
      },
    );

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                hero,
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: _Info(
                    recording: recording,
                    group: group,
                    expired: expired,
                    now: now,
                    saved: _saved != null,
                    saving: _saving,
                    busy: _busy,
                    onSave: () => _save(recording),
                    onOpenSaved: () => _openSaved(recording),
                    onDelete: () => _delete(recording),
                    onStop: () => _stop(recording),
                  ),
                ),
                // Room for the saving panel and the toast.
                if (_saving || _showSavedToast) const SizedBox(height: 200),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: _PlayerHeader(
              onBack: _back,
              onDelete: recording.actions.canDelete && !_busy
                  ? () => _delete(recording)
                  : null,
            ),
          ),
        ),
        if (_saving)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SavingPanel(
              received: _received,
              total: _total,
              onCancel: () => setState(() => _cancelSave = true),
            ),
          ),
        if (_showSavedToast && !_saving)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: _SavedToast(
                onOpen: () {
                  setState(() => _showSavedToast = false);
                  _openSaved(recording);
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.onBack, required this.onDelete});

  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 48,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
                icon: const SsV2Icon(SsV2IconGlyph.back, color: Colors.white),
              ),
            ),
            const Spacer(),
            if (onDelete != null)
              PopupMenuButton<String>(
                key: const ValueKey<String>('player-more'),
                tooltip: l10n.v2PlayerMore,
                icon: const SsV2Icon(SsV2IconGlyph.more, color: Colors.white),
                onSelected: (_) => onDelete!(),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    key: const ValueKey<String>('player-delete'),
                    value: 'delete',
                    child: Text(l10n.v2Delete),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Plain hero for processing and failed recordings.
class _StateHero extends StatelessWidget {
  const _StateHero({
    required this.color,
    required this.title,
    this.subtitle,
    this.spinner = false,
  });

  final Color color;
  final String title;
  final String? subtitle;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.v2PlayerVideo,
      container: true,
      child: ColoredBox(
        color: color,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ssV2Gap(<Widget>[
                if (spinner)
                  const RecordingRingSpinner(
                    track: Color(0xFFEEE9FF),
                    arc: Colors.white,
                    size: 40,
                    stroke: 4,
                  )
                else
                  const SsV2Icon(
                    SsV2IconGlyph.alert,
                    size: 40,
                    color: Colors.white,
                  ),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
              ], spinner ? 12 : 10),
            ),
          ),
        ),
      ),
    );
  }
}

/// A recording still waiting for (or capturing) its LIVE.
class _LiveHero extends StatelessWidget {
  const _LiveHero({required this.recording, required this.clock});

  final RecordingSummary recording;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    if (!isCapturing(recording)) {
      return _StateHero(
        color: _heroProcessing,
        spinner: true,
        title: l10n.v2PlayerWaitingTitle,
      );
    }
    final DateTime? started = recording.startedAt;
    const TextStyle sub = TextStyle(
      fontSize: 13,
      color: Colors.white,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    );
    return ColoredBox(
      color: _heroProcessing,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ssV2Gap(<Widget>[
            RecordingThumbChip(
              label: l10n.v2RecChipRec,
              dot: true,
              background: palette.error,
              foreground: Colors.white,
            ),
            Text(
              l10n.v2PlayerRecordingTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (started == null)
              Text(formatRecordingClock(recording.durationSeconds), style: sub)
            else
              RecordingElapsedBuilder(
                startedAt: started,
                now: clock,
                builder: (BuildContext context, int seconds) =>
                    Text(formatRecordingClock(seconds), style: sub),
              ),
          ], 12),
        ),
      ),
    );
  }
}

/// The video area: poster (server thumbnail or the artboard gradient) with
/// a Play button; playback starts only when tapped, inline.
class _PlayerSurface extends ConsumerStatefulWidget {
  const _PlayerSurface({
    required this.recording,
    required this.localPath,
    required this.enabled,
  });

  final RecordingSummary recording;
  final String? localPath;
  final bool enabled;

  @override
  ConsumerState<_PlayerSurface> createState() => _PlayerSurfaceState();
}

class _PlayerSurfaceState extends ConsumerState<_PlayerSurface> {
  VideoPlayerSsController? _controller;
  bool _loading = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<VideoPlayerSsController> _create() async {
    final String? local = widget.localPath;
    if (local != null && local.isNotEmpty) {
      return VideoPlayerSsController.file(local);
    }
    final List<RecordingArtifactSummary> artifacts = await ref.read(
      recordingArtifactsProvider(widget.recording.id).future,
    );
    if (artifacts.isEmpty) {
      throw StateError('Cloud recording artifact is unavailable.');
    }
    final ArtifactDownloadUrl download = await ref
        .read(recordingControllerProvider)
        .createArtifactDownloadUrl(artifacts.first.id);
    if (download.isExpired) {
      throw StateError('Cloud recording URL expired before playback.');
    }
    return VideoPlayerSsController.network(download.uri);
  }

  Future<void> _toggle() async {
    final VideoPlayerSsController? controller = _controller;
    if (controller != null) {
      controller.isPlaying ? await controller.pause() : await controller.play();
      return;
    }
    if (_loading || !widget.enabled) return;
    final String failed = context.l10n.v2PlayerPlaybackFailed;
    setState(() => _loading = true);
    VideoPlayerSsController? next;
    try {
      next = await _create();
      await next.initialize();
      if (!mounted) {
        next.dispose();
        return;
      }
      setState(() {
        _controller = next;
        _loading = false;
      });
      await next.play();
    } on Object {
      next?.dispose();
      if (!mounted) return;
      setState(() => _loading = false);
      SsSnackbar.show(context, failed);
    }
  }

  void _seekTo(double fraction, Duration duration) {
    final VideoPlayerSsController? controller = _controller;
    if (controller == null || duration <= Duration.zero) return;
    controller.seekTo(duration * fraction.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerSsController? controller = _controller;
    if (controller == null) return _frame(context, null);
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) =>
          _frame(context, controller),
    );
  }

  Widget _frame(BuildContext context, VideoPlayerSsController? controller) {
    final AppLocalizations l10n = context.l10n;
    final Duration reported = controller?.duration ?? Duration.zero;
    final Duration duration = reported >= const Duration(seconds: 2)
        ? reported
        : Duration(seconds: widget.recording.durationSeconds);
    final Duration position = controller == null
        ? Duration.zero
        : controller.position > duration
        ? duration
        : controller.position;
    final double fraction = duration.inMilliseconds <= 0
        ? 0
        : position.inMilliseconds / duration.inMilliseconds;
    final bool playing = controller?.isPlaying ?? false;
    String clock(Duration value) => duration.inHours > 0
        ? formatRecordingClock(value.inSeconds)
        : recordingClock(value.inSeconds);

    return Semantics(
      label: l10n.v2PlayerVideo,
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: playing ? _toggle : null,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (controller != null && controller.isInitialized)
              ColoredBox(
                color: Colors.black,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: controller.aspectRatio,
                    child: VideoPlayer(controller.player),
                  ),
                ),
              )
            else
              RecordingThumbnailFill(
                recording: widget.recording,
                colors: _heroGradient,
              ),
            if (!playing && widget.enabled)
              Center(
                child: _loading
                    ? const SizedBox.square(
                        dimension: 72,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      )
                    : Semantics(
                        button: true,
                        label: l10n.v2PlayerPlay,
                        child: Material(
                          key: const ValueKey<String>('player-play'),
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _toggle,
                            child: const SizedBox.square(
                              dimension: 72,
                              child: Center(
                                child: SsV2Icon(
                                  SsV2IconGlyph.play,
                                  size: 30,
                                  color: Color(0xFF15122B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints box) {
                      void seek(Offset local) =>
                          _seekTo(local.dx / box.maxWidth, duration);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (TapDownDetails d) => seek(d.localPosition),
                        onHorizontalDragUpdate: (DragUpdateDetails d) =>
                            seek(d.localPosition),
                        child: SizedBox(
                          height: 14,
                          child: _ProgressTrack(fraction: fraction),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 3),
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(clock(position)),
                        Text(clock(duration)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4px track with the white fill and a 14px thumb.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double x = box.maxWidth * fraction.clamp(0.0, 1.0);
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              top: 5,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 5,
              width: x,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Positioned(
              left: x - 7,
              top: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Info extends ConsumerWidget {
  const _Info({
    required this.recording,
    required this.group,
    required this.expired,
    required this.now,
    required this.saved,
    required this.saving,
    required this.busy,
    required this.onSave,
    required this.onOpenSaved,
    required this.onDelete,
    required this.onStop,
  });

  final RecordingSummary recording;
  final RecordingGroup group;
  final bool expired;
  final DateTime now;
  final bool saved;
  final bool saving;
  final bool busy;
  final VoidCallback onSave;
  final VoidCallback onOpenSaved;
  final VoidCallback onDelete;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final DateTime? started = recording.startedAt;
    final List<String> meta = <String>[
      recordingHandle(recording),
      if (started != null) recordingDayTime(context, started),
      if (group != RecordingGroup.failed && recording.durationSeconds > 0)
        recordingClock(recording.durationSeconds),
    ];
    // LIVE titles aren't in the API yet: the handle is the title and the
    // line under it carries the date and length.
    final Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            meta.first,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        if (meta.length > 1) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            meta.skip(1).join(' · '),
            style: TextStyle(fontSize: 14, color: palette.textMuted),
          ),
        ],
      ],
    );

    final List<Widget> children = <Widget>[heading];
    switch (group) {
      case RecordingGroup.ready:
        if (expired) {
          children.add(
            SsV2Banner(
              tone: SsV2Tone.warning,
              child: Text(l10n.v2PlayerExpired),
            ),
          );
          break;
        }
        children.add(
          saved
              ? SsV2Button(
                  key: const ValueKey<String>('player-play-saved'),
                  label: l10n.v2PlayerPlaySaved,
                  variant: SsV2ButtonVariant.outlined,
                  leading: SsV2Icon(
                    SsV2IconGlyph.play,
                    size: 20,
                    color: palette.text,
                  ),
                  onPressed: onOpenSaved,
                )
              : SsV2Button(
                  key: const ValueKey<String>('player-save'),
                  label: l10n.v2PlayerSave,
                  leading: const SsV2Icon(
                    SsV2IconGlyph.download,
                    size: 20,
                    color: Colors.white,
                  ),
                  onPressed: saving || busy ? null : onSave,
                ),
        );
        final DateTime? expiresAt = recording.expiresAt;
        if (expiresAt != null) {
          final int days = daysUntil(expiresAt, now);
          final TextStyle bold = TextStyle(
            fontWeight: FontWeight.w700,
            color: palette.text,
          );
          children.add(
            _InfoRow(
              glyph: SsV2IconGlyph.clock,
              child: Text.rich(
                days < 1
                    ? TextSpan(text: l10n.v2PlayerKeptToday)
                    : TextSpan(
                        children: <InlineSpan>[
                          TextSpan(text: l10n.v2PlayerKeptBefore),
                          TextSpan(
                            text: l10n.v2PlayerKeptDays(days),
                            style: bold,
                          ),
                          TextSpan(text: l10n.v2PlayerKeptAfter),
                        ],
                      ),
              ),
            ),
          );
        }
        final RecordingArtifactSummary? artifact = ref
            .watch(recordingArtifactsProvider(recording.id))
            .value
            ?.firstOrNull;
        final int? width = artifact?.width;
        final int? height = artifact?.height;
        final List<String> details = <String>[
          if (width != null && height != null)
            '${width < height ? width : height}p',
          if (artifact != null && artifact.sizeBytes > 0)
            formatFileSize(artifact.sizeBytes),
          l10n.v2PlayerOnServers,
        ];
        final String line = details.join(' · ');
        children.add(
          _InfoRow(
            glyph: SsV2IconGlyph.cloud,
            child: Text(line[0].toUpperCase() + line.substring(1)),
          ),
        );
      case RecordingGroup.processing:
      case RecordingGroup.live:
        children.add(
          SsV2Banner(
            tone: SsV2Tone.info,
            glyph: SsV2IconGlyph.clock,
            child: Text(
              group == RecordingGroup.processing
                  ? l10n.v2PlayerProcessingBanner
                  : l10n.v2PlayerRecordingBanner,
            ),
          ),
        );
        if (group == RecordingGroup.live &&
            recording.actions.canStop &&
            isCapturing(recording)) {
          children.add(
            _OutlinedDangerButton(
              key: const ValueKey<String>('player-stop'),
              label: l10n.v2StopRecording,
              onPressed: busy ? null : onStop,
            ),
          );
        } else {
          children.add(_DisabledSaveButton(label: l10n.v2PlayerSave));
        }
      case RecordingGroup.failed:
        children.add(
          SsV2Banner(
            tone: SsV2Tone.error,
            title: l10n.v2RecWhy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(failureReason(l10n, recording)),
                const SizedBox(height: 10),
                Text(
                  l10n.v2PlayerMinutesCharged(recording.minutesCharged),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        );
        final bool shortLive = (recording.errorCode ?? '').startsWith(
          'STREAM_',
        );
        children.add(
          Text(
            shortLive
                ? '${l10n.v2PlayerShortLiveNote} ${l10n.v2PlayerFailedAdvice}'
                : l10n.v2PlayerFailedAdvice,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: palette.textMuted,
            ),
          ),
        );
        children.add(
          Row(
            children: <Widget>[
              Expanded(
                child: SsV2Button(
                  label: l10n.v2PlayerReport,
                  variant: SsV2ButtonVariant.outlined,
                  onPressed: () => context.push(AppRoutes.reportIssue),
                ),
              ),
              if (recording.actions.canDelete) ...<Widget>[
                const SizedBox(width: 10),
                Expanded(
                  child: _OutlinedDangerButton(
                    key: const ValueKey<String>('player-delete-button'),
                    label: l10n.v2Delete,
                    onPressed: busy ? null : onDelete,
                  ),
                ),
              ],
            ],
          ),
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: ssV2Gap(children, 14),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.glyph, required this.child});

  final SsV2IconGlyph glyph;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Row(
      children: <Widget>[
        SsV2Icon(glyph, size: 18, color: palette.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: DefaultTextStyle.merge(
            style: TextStyle(fontSize: 14, color: palette.textMuted),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// White button with red label and border (Delete, Stop recording).
class _OutlinedDangerButton extends StatelessWidget {
  const _OutlinedDangerButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: palette.surface,
        foregroundColor: palette.errorText,
        fixedSize: const Size.fromHeight(52),
        minimumSize: const Size(double.infinity, 52),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: BorderSide(color: palette.errorBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: SsTypography.uiFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Grey "Save to device" while the video is not ready.
class _DisabledSaveButton extends StatelessWidget {
  const _DisabledSaveButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Semantics(
      button: true,
      enabled: false,
      label: label,
      excludeSemantics: true,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: palette.skeleton,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SsV2Icon(SsV2IconGlyph.download, size: 20, color: palette.disabled),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.disabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// APlayerSaving: the bottom panel while the video downloads.
class _SavingPanel extends StatelessWidget {
  const _SavingPanel({
    required this.received,
    required this.total,
    required this.onCancel,
  });

  final int received;
  final int? total;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final int? size = total;
    final double? fraction = size == null || size <= 0
        ? null
        : (received / size).clamp(0.0, 1.0);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          28 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.divider)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x5915122B),
              offset: Offset(0, -12),
              blurRadius: 30,
              spreadRadius: -16,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: ssV2Gap(<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.v2PlayerSavingTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (fraction != null)
                  Text(
                    '${(fraction * 100).round()}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.link,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
              ],
            ),
            fraction == null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      backgroundColor: palette.divider,
                      color: palette.primary,
                    ),
                  )
                : SsV2ProgressBar(
                    value: fraction,
                    track: palette.divider,
                    fill: palette.primary,
                  ),
            if (size != null)
              Text(
                l10n.v2PlayerSavingDetail(
                  formatFileSize(received),
                  formatFileSize(size),
                ),
                style: TextStyle(fontSize: 13, color: palette.textMuted),
              ),
            SsV2Button(
              key: const ValueKey<String>('player-save-cancel'),
              label: l10n.v2Cancel,
              variant: SsV2ButtonVariant.text,
              size: SsV2ButtonSize.small,
              onPressed: onCancel,
            ),
          ], 12),
        ),
      ),
    );
  }
}

/// APlayerSaved: "Saved on this device · Open".
class _SavedToast extends StatelessWidget {
  const _SavedToast({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        decoration: BoxDecoration(
          color: _toastBackground,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x8015122B),
              offset: Offset(0, 10),
              blurRadius: 30,
              spreadRadius: -10,
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.v2PlayerSaved,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            TextButton(
              key: const ValueKey<String>('player-saved-open'),
              onPressed: onOpen,
              style: TextButton.styleFrom(
                foregroundColor: _toastAction,
                minimumSize: const Size(48, 40),
                textStyle: const TextStyle(
                  fontFamily: SsTypography.uiFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(l10n.v2PlayerOpen),
            ),
          ],
        ),
      ),
    );
  }
}

/// APlayerDelete: "Delete this recording?". Completes with true on Delete.
Future<bool?> showDeleteRecordingDialog(
  BuildContext context, {
  required String name,
}) {
  final SsV2Palette palette = SsV2Palette.of(context);
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierColor: palette.scrim,
    builder: (BuildContext dialogContext) {
      final AppLocalizations l10n = dialogContext.l10n;
      ButtonStyle style(Color background, Color foreground) =>
          TextButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            fixedSize: const Size.fromHeight(52),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontFamily: SsTypography.uiFamily,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          );
      return Dialog(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: DefaultTextStyle(
          style: ssV2BaseText(palette),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: ssV2Gap(<Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.errorBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SsV2Icon(
                      SsV2IconGlyph.trash,
                      size: 22,
                      color: palette.errorText,
                    ),
                  ),
                ),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.v2PlayerDeleteTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  l10n.v2PlayerDeleteBody(name),
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: palette.textMuted,
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: style(Colors.transparent, palette.link),
                      child: Text(l10n.v2Cancel),
                    ),
                    TextButton(
                      key: const ValueKey<String>('recording-delete-confirm'),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: style(palette.error, Colors.white),
                      child: Text(l10n.v2Delete),
                    ),
                  ],
                ),
              ], 16),
            ),
          ),
        ),
      );
    },
  );
}
