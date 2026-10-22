/// Shared pieces of the v2 Recordings library and Player.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/recording_summary.dart';

/// Where a recording is in its life, as the library and player show it.
enum RecordingGroup {
  /// Waiting for the LIVE or recording it now.
  live,

  /// The LIVE ended; the video is being prepared.
  processing,

  /// The video can be played and saved.
  ready,

  /// Nothing was saved.
  failed,
}

RecordingGroup recordingGroupOf(RecordingSummary recording) {
  return switch (recording.status) {
    RecordingStatus.starting ||
    RecordingStatus.queued ||
    RecordingStatus.resolving ||
    RecordingStatus.waitingLive ||
    RecordingStatus.waitingForCloudSlot ||
    RecordingStatus.recording ||
    RecordingStatus.reconnecting => RecordingGroup.live,
    RecordingStatus.stopRequested ||
    RecordingStatus.processing ||
    RecordingStatus.uploading ||
    RecordingStatus.finalizing => RecordingGroup.processing,
    RecordingStatus.failed ||
    RecordingStatus.missedNoCloudSlot => RecordingGroup.failed,
    RecordingStatus.completed ||
    RecordingStatus.partial ||
    RecordingStatus.recovered ||
    RecordingStatus.stopped =>
      // Finished on the server but the video file is not ready yet.
      recording.artifactReady
          ? RecordingGroup.ready
          : RecordingGroup.processing,
  };
}

/// True while the recording is being captured (not merely waiting).
bool isCapturing(RecordingSummary recording) =>
    recording.status == RecordingStatus.recording ||
    recording.status == RecordingStatus.reconnecting;

/// Past the server's `expires_at`.
bool isExpired(RecordingSummary recording, DateTime now) {
  final DateTime? expiry = recording.expiresAt;
  return expiry != null && !expiry.isAfter(now);
}

/// Server expiry within three days.
bool isExpiringSoon(RecordingSummary recording, DateTime now) {
  final DateTime? expiry = recording.expiresAt;
  if (expiry == null || !expiry.isAfter(now)) return false;
  return expiry.difference(now) <= const Duration(days: 3);
}

/// Whole days until [expiresAt] (a server timestamp), rounded up.
int daysUntil(DateTime expiresAt, DateTime now) {
  final int hours = expiresAt.difference(now).inHours;
  return math.max(0, (hours / 24).ceil());
}

String recordingHandle(RecordingSummary recording) =>
    '@${recording.creatorUsername.replaceFirst('@', '')}';

/// `m:ss` under an hour, `h:mm:ss` from one hour.
String recordingClock(int totalSeconds) {
  final int s = math.max(0, totalSeconds);
  final int hours = s ~/ 3600;
  final String mm = ((s % 3600) ~/ 60).toString().padLeft(
    hours > 0 ? 2 : 1,
    '0',
  );
  final String ss = (s % 60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

String _locale(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();

/// "Oct 21".
String recordingDay(BuildContext context, DateTime value) =>
    DateFormat.MMMd(_locale(context)).format(value.toLocal());

/// "Oct 21, 20:01".
String recordingDayTime(BuildContext context, DateTime value) {
  final DateTime local = value.toLocal();
  return '${DateFormat.MMMd(_locale(context)).format(local)}, '
      '${DateFormat.Hm(_locale(context)).format(local)}';
}

/// The server's plain-English reason a recording failed (`failure_reason`),
/// else its raw `error.message`, else what its status says.
String failureReason(AppLocalizations l10n, RecordingSummary recording) {
  for (final String? text in <String?>[
    recording.failureReason,
    recording.errorMessage,
  ]) {
    final String? message = text?.trim();
    if (message != null && message.isNotEmpty) return message;
  }
  if (recording.status == RecordingStatus.missedNoCloudSlot) {
    return l10n.v2RecMissedNoSlot;
  }
  return l10n.v2RecFailedGeneric;
}

/// What the user can do: localized advice by the server's `error.code`, else
/// the server's `failure_guidance`; null when neither has any.
String? failureAdvice(AppLocalizations l10n, RecordingSummary recording) {
  final String code = recording.errorCode ?? '';
  if (code.startsWith('STREAM_')) return l10n.v2RecAdviceStream;
  if (code == 'SERVICE_UNAVAILABLE') return l10n.v2RecAdviceService;
  final String? guidance = recording.failureGuidance?.trim();
  return guidance == null || guidance.isEmpty ? null : guidance;
}

/// Thumbnail fills of the artboards, picked per recording.
const List<List<Color>> recordingGradients = <List<Color>>[
  <Color>[Color(0xFFFFB38A), Color(0xFFE0662E)],
  <Color>[Color(0xFF9DB8F0), Color(0xFF3D63B8)],
  <Color>[Color(0xFFF2A7C9), Color(0xFFB5487D)],
  <Color>[Color(0xFF7FD3B5), Color(0xFF2A8F6E)],
  <Color>[Color(0xFF8B6CFF), Color(0xFF4A2FC9)],
];

/// CSS `linear-gradient(160deg, …)`.
LinearGradient recordingGradient(List<Color> colors) {
  return LinearGradient(
    begin: const Alignment(-0.34, -0.94),
    end: const Alignment(0.34, 0.94),
    colors: colors,
  );
}

List<Color> gradientFor(String id) {
  int hash = 0;
  for (final int unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return recordingGradients[hash % recordingGradients.length];
}

/// The server thumbnail (`thumbnail_url`) over the artboard gradient, which
/// also shows while it loads or when it fails.
class RecordingThumbnailFill extends StatelessWidget {
  const RecordingThumbnailFill({
    required this.recording,
    this.colors,
    super.key,
  });

  final RecordingSummary recording;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final String? url = recording.thumbnailUrl;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: recordingGradient(colors ?? gradientFor(recording.id)),
      ),
      child: url == null
          ? const SizedBox.expand()
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
    );
  }
}

/// Small pill on a thumbnail ("● REC", "3 days left").
class RecordingThumbChip extends StatelessWidget {
  const RecordingThumbChip({
    required this.label,
    required this.background,
    required this.foreground,
    this.dot = false,
    super.key,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        dot ? '● $label' : label,
        maxLines: 1,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

/// Duration badge at the bottom right of a thumbnail.
class RecordingDurationBadge extends StatelessWidget {
  const RecordingDurationBadge({required this.seconds, super.key});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: palette.thumbOverlay,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        recordingClock(seconds),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// 32px ring spinner with a custom arc color (the shared one is primary).
class RecordingRingSpinner extends StatelessWidget {
  const RecordingRingSpinner({
    required this.track,
    required this.arc,
    this.size = 32,
    this.stroke = 3,
    super.key,
  });

  final Color track;
  final Color arc;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    // Holds still when animations are off (screenshots), like the
    // artboard's first frame: a quarter arc centered at the top.
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Widget ring = CircularProgressIndicator(
      value: still ? 0.25 : null,
      strokeWidth: stroke,
      color: arc,
      backgroundColor: track,
      strokeCap: StrokeCap.butt,
    );
    return SizedBox.square(
      dimension: size,
      child: still ? Transform.rotate(angle: -math.pi / 4, child: ring) : ring,
    );
  }
}
