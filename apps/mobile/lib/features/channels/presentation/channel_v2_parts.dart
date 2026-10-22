/// Shared pieces of the v2 Channels screens (list, detail, verify).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../recordings/domain/models/recording_summary.dart';
import '../../settings/presentation/controllers/notification_feed_providers.dart';
import '../domain/models/watch_summary.dart';

/// What a channel row or detail screen shows, in priority order.
enum ChannelState {
  /// A cloud recording for this channel is in flight.
  recording,

  /// Ownership not proved yet (no `owner_verified_at`).
  unverified,

  /// Paused by the user (or disabled after errors).
  paused,

  /// LIVE now but nothing is recording.
  liveNotRecording,

  /// Offline and auto-record is held because there are no minutes.
  noMinutes,

  /// Watching for the next LIVE.
  waiting,
}

const Set<RecordingStatus> _inFlight = <RecordingStatus>{
  RecordingStatus.recording,
  RecordingStatus.reconnecting,
};

/// The in-flight recording of [watch] in [recordings], if any.
RecordingSummary? activeRecordingFor(
  WatchSummary watch,
  Iterable<RecordingSummary> recordings,
) {
  for (final RecordingSummary item in recordings) {
    if (!_inFlight.contains(item.status)) continue;
    if (item.id == watch.activeRecordingId ||
        (item.watchId != null && item.watchId == watch.id)) {
      return item;
    }
  }
  return null;
}

ChannelState channelStateOf(WatchSummary watch, {RecordingSummary? recording}) {
  if (recording != null || watch.activeRecordingId != null) {
    return ChannelState.recording;
  }
  if (!watch.isOwnerVerified) return ChannelState.unverified;
  if (watch.status == WatchStatus.paused ||
      watch.status == WatchStatus.pausedError ||
      watch.status == WatchStatus.disabled) {
    return ChannelState.paused;
  }
  if (watch.isLive) return ChannelState.liveNotRecording;
  if (watch.status == WatchStatus.pausedInsufficientCredit ||
      watch.autoRecordState == AutoRecordState.pausedNoCloudMinutes) {
    return ChannelState.noMinutes;
  }
  return ChannelState.waiting;
}

/// True when auto-record is held for lack of minutes.
bool channelOutOfMinutes(WatchSummary watch) =>
    watch.status == WatchStatus.pausedInsufficientCredit ||
    watch.autoRecordState == AutoRecordState.pausedNoCloudMinutes;

String channelHandle(WatchSummary watch) =>
    '@${watch.creatorUsername.replaceFirst('@', '')}';

/// `h:mm:ss`.
String formatRecordingClock(int totalSeconds) {
  final int seconds = math.max(0, totalSeconds);
  return '${seconds ~/ 3600}:'
      '${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Rebuilds every second with the time elapsed since [startedAt] (a server
/// timestamp).
class RecordingElapsedBuilder extends StatefulWidget {
  const RecordingElapsedBuilder({
    required this.startedAt,
    required this.now,
    required this.builder,
    super.key,
  });

  final DateTime startedAt;
  final DateTime Function() now;
  final Widget Function(BuildContext context, int seconds) builder;

  @override
  State<RecordingElapsedBuilder> createState() =>
      _RecordingElapsedBuilderState();
}

class _RecordingElapsedBuilderState extends State<RecordingElapsedBuilder> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int seconds = widget.now().difference(widget.startedAt).inSeconds;
    return widget.builder(context, math.max(0, seconds));
  }
}

/// 48px bell with the unread dot, as on Home.
class ChannelsBellButton extends ConsumerWidget {
  const ChannelsBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final int unread =
        ref
            .watch(notificationFeedProvider)
            .value
            ?.items
            .where((item) => !item.read)
            .length ??
        0;
    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        tooltip: context.l10n.v2NotificationsLabel(unread),
        onPressed: () => context.push(AppRoutes.notifications),
        icon: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            SsV2Icon(SsV2IconGlyph.bell, color: palette.text),
            if (unread > 0)
              Positioned(
                top: -1,
                right: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 64px top bar: optional back button, 22/800 title with an optional muted
/// subtitle, and trailing actions.
class ChannelsTopBar extends StatelessWidget {
  const ChannelsTopBar({
    this.title,
    this.subtitle,
    this.onBack,
    this.actions = const <Widget>[],
    super.key,
  });

  final String? title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return SizedBox(
      height: 64,
      child: Padding(
        padding: EdgeInsets.fromLTRB(onBack == null ? 20 : 4, 0, 8, 0),
        child: Row(
          children: <Widget>[
            if (onBack != null) ...<Widget>[
              SizedBox.square(
                dimension: 48,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: onBack,
                  icon: SsV2Icon(SsV2IconGlyph.back, color: palette.text),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (title != null)
                    Semantics(
                      header: true,
                      child: Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.22,
                        ),
                      ),
                    ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: palette.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Centered empty/error body: 88px tinted tile, 22/800 title, muted body and
/// one action.
class ChannelsCenteredMessage extends StatelessWidget {
  const ChannelsCenteredMessage({
    required this.glyph,
    required this.title,
    required this.body,
    required this.action,
    required this.actionWidth,
    super.key,
  });

  final SsV2IconGlyph glyph;
  final String title;
  final String body;
  final Widget action;
  final double actionWidth;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return SsV2FillScroll(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.tint,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: SsV2Icon(glyph, size: 40, color: palette.link),
                ),
                const SizedBox(height: 14),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 290),
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: palette.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(width: actionWidth, child: action),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
