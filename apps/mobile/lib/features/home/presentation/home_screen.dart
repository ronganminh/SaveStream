/// AHome · AHomeFirstRun · AHomeLive · AHomeLoading · AHomeLow · AHomeOut.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../channels/domain/models/watch_summary.dart';
import '../../credits/presentation/ad_banner_slot.dart';
import '../../recordings/domain/models/recording_summary.dart';
import '../../settings/domain/models/user_profile.dart';
import '../../settings/presentation/controllers/notification_feed_providers.dart';
import '../../settings/presentation/controllers/settings_providers.dart';
import '../domain/models/home_credits.dart';
import '../domain/models/home_dashboard_view_model.dart';
import 'controllers/home_dashboard_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeDashboardViewModel> dashboard = ref.watch(
      homeDashboardProvider,
    );
    final UserProfile? profile = ref.watch(profileProvider).value;
    final int unread =
        ref
            .watch(notificationFeedProvider)
            .value
            ?.items
            .where((item) => !item.read)
            .length ??
        0;

    return SsV2Page(
      safeBottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _HomeHeader(name: _firstName(profile), unread: unread),
          Expanded(
            child: dashboard.when(
              skipLoadingOnRefresh: true,
              skipLoadingOnReload: true,
              loading: () => const HomeSkeleton(),
              error: (Object error, StackTrace stackTrace) => _HomeError(
                onRetry: () => ref.invalidate(homeDashboardProvider),
              ),
              data: (HomeDashboardViewModel data) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(homeDashboardProvider);
                  await ref.read(homeDashboardProvider.future);
                },
                child: HomeDashboardBody(
                  data: data,
                  now: ref.watch(homeClockProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String? _firstName(UserProfile? profile) {
    final String? display = profile?.displayName?.trim();
    if (display != null && display.isNotEmpty) {
      return display.split(RegExp(r'\s+')).first;
    }
    final String? email = profile?.email.trim();
    if (email != null && email.contains('@')) {
      final String local = email.split('@').first;
      final String first = local.split(RegExp(r'[._+\-]')).first;
      if (first.isEmpty) return null;
      return first[0].toUpperCase() + first.substring(1);
    }
    return null;
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.name, required this.unread});

  final String? name;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: SizedBox(
        height: 72,
        child: Row(
          children: <Widget>[
            const SsV2LogoMark(size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (name != null)
                    Text(
                      l10n.v2HomeGreeting(name!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: palette.textMuted),
                    ),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.v2HomeTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox.square(
              dimension: 48,
              child: IconButton(
                tooltip: l10n.v2NotificationsLabel(unread),
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
                          key: const ValueKey<String>(
                            'notification-unread-dot',
                          ),
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
            ),
          ],
        ),
      ),
    );
  }
}

/// A watch that is LIVE with a cloud recording in flight.
class _LiveItem {
  const _LiveItem(this.watch, this.recording);

  final WatchSummary watch;
  final RecordingSummary? recording;
}

const Set<RecordingStatus> _activeStatuses = <RecordingStatus>{
  RecordingStatus.recording,
  RecordingStatus.reconnecting,
};

const Set<RecordingStatus> _finishedStatuses = <RecordingStatus>{
  RecordingStatus.completed,
  RecordingStatus.partial,
  RecordingStatus.recovered,
};

class HomeDashboardBody extends StatelessWidget {
  const HomeDashboardBody({required this.data, required this.now, super.key});

  final HomeDashboardViewModel data;
  final DateTime Function() now;

  RecordingSummary? _activeRecordingFor(WatchSummary watch) {
    for (final RecordingSummary item in data.recordings) {
      if (!_activeStatuses.contains(item.status)) continue;
      if (item.id == watch.activeRecordingId ||
          (item.watchId != null && item.watchId == watch.id)) {
        return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final HomeCredits credits = data.creditsSummary;
    final bool firstRun = data.watches.isEmpty && data.recordings.isEmpty;

    final List<_LiveItem> live = <_LiveItem>[];
    final List<WatchSummary> others = <WatchSummary>[];
    for (final WatchSummary watch in data.watches) {
      final RecordingSummary? recording = _activeRecordingFor(watch);
      if (watch.isLive &&
          (recording != null || watch.activeRecordingId != null)) {
        live.add(_LiveItem(watch, recording));
      } else {
        others.add(watch);
      }
    }
    final List<RecordingSummary> recent =
        data.recordings
            .where(
              (RecordingSummary item) =>
                  _finishedStatuses.contains(item.status) || item.artifactReady,
            )
            .toList()
          ..sort(
            (RecordingSummary a, RecordingSummary b) =>
                (b.startedAt ?? DateTime(0)).compareTo(
                  a.startedAt ?? DateTime(0),
                ),
          );

    final List<Widget> children = <Widget>[
      if (credits.refundDebt > 0)
        _CreditsBanner.refundDebt(credits: credits)
      else if (credits.tone == HomeCreditsTone.out &&
          credits.caption == HomeCreditsCaption.paused)
        _CreditsBanner.out(credits: credits)
      else if (credits.tone == HomeCreditsTone.low)
        _CreditsBanner.low(credits: credits),
      if (firstRun)
        _SetupChecklist(emailVerified: data.entitlement.emailVerified),
      if (live.isNotEmpty) ...<Widget>[
        SsV2SectionHeader(title: l10n.v2LiveNow),
        for (final _LiveItem item in live) _LiveCard(item: item, now: now),
      ],
      HomeCreditsCard(credits: credits),
      if (firstRun) const _ServerInfoCard(),
      if (others.isNotEmpty) ...<Widget>[
        SsV2SectionHeader(title: l10n.v2YourChannels),
        _ChannelList(watches: others, now: now),
      ],
      if (recent.isNotEmpty) ...<Widget>[
        SsV2SectionHeader(
          title: l10n.v2RecentRecordings,
          actionLabel: l10n.v2SeeAll,
          onAction: () => context.go(AppRoutes.recordings),
        ),
        _RecordingGrid(recordings: recent.take(2).toList(), now: now),
      ],
      // Non-purchasers only (entitlement.ads.show_banners); nothing otherwise.
      AdBannerSlot(ads: data.entitlement.ads),
    ];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: ssV2Gap(children, 16),
      ),
    );
  }
}

String formatRecordingMinutes(AppLocalizations l10n, int totalMinutes) {
  final int minutes = math.max(0, totalMinutes);
  if (minutes < 60) return l10n.v2DurationMinutes(minutes);
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  return rest == 0
      ? l10n.v2DurationHours(hours)
      : l10n.v2DurationHoursMinutes(hours, rest);
}

class HomeCreditsCard extends StatelessWidget {
  const HomeCreditsCard({required this.credits, super.key});

  final HomeCredits credits;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final Color background = switch (credits.tone) {
      HomeCreditsTone.normal => palette.primary,
      HomeCreditsTone.low => palette.warningCard,
      HomeCreditsTone.out => palette.error,
    };
    final String caption = switch (credits.caption) {
      HomeCreditsCaption.trial => l10n.v2CreditsTrial,
      HomeCreditsCaption.trialUsed => l10n.v2CreditsTrialUsed(
        credits.trialMinutesUsed,
        HomeCredits.trialMinutes,
      ),
      HomeCreditsCaption.unverified => l10n.v2CreditsUnverified,
      HomeCreditsCaption.purchased => l10n.v2CreditsPurchased,
      HomeCreditsCaption.paused => l10n.v2CreditsPaused,
    };
    const Color white = Colors.white;
    return Material(
      color: background,
      // Material would otherwise impose the theme's body line height.
      textStyle: ssV2BaseText(palette),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.usage),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.v2CreditsLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatRecordingMinutes(l10n, credits.minutes),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.64,
                              fontFeatures: <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SsV2Icon(
                      SsV2IconGlyph.chevronRight,
                      size: 22,
                      color: white,
                    ),
                  ],
                ),
                if (credits.progress != null) ...<Widget>[
                  const SizedBox(height: 12),
                  SsV2ProgressBar(
                    value: credits.progress!,
                    track: white.withValues(alpha: 0.28),
                    fill: white,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: 13,
                    color: white.withValues(alpha: 0.92),
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

class _CreditsBanner extends StatelessWidget {
  const _CreditsBanner.low({required this.credits}) : _kind = 0;
  const _CreditsBanner.out({required this.credits}) : _kind = 1;
  const _CreditsBanner.refundDebt({required this.credits}) : _kind = 2;

  final HomeCredits credits;
  final int _kind;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final (String title, String body, String action) = switch (_kind) {
      0 => (
        credits.isTrial
            ? l10n.v2LowTitleTrial(credits.minutes)
            : l10n.v2LowTitle(credits.minutes),
        l10n.v2LowBody,
        l10n.v2GetMinutes,
      ),
      1 => (l10n.v2OutTitle, l10n.v2OutBody, l10n.v2BuyMinutes),
      _ => (
        l10n.v2RefundDebtTitle(credits.refundDebt),
        l10n.v2RefundDebtBody,
        l10n.v2BuyMinutes,
      ),
    };
    return SsV2Banner(
      tone: _kind == 0 ? SsV2Tone.warning : SsV2Tone.error,
      actions: <Widget>[
        SsV2Button(
          label: action,
          size: SsV2ButtonSize.small,
          expand: false,
          onPressed: () => context.push(AppRoutes.usage),
        ),
      ],
      title: title,
      child: Text(body),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.item, required this.now});

  final _LiveItem item;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final WatchSummary watch = item.watch;
    final DateTime? started = item.recording?.startedAt?.toLocal();
    final String handle = '@${watch.creatorUsername.replaceFirst('@', '')}';
    return Material(
      color: palette.errorBackground,
      textStyle: ssV2BaseText(palette),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.channelDetail(watch.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  SsV2Avatar(
                    name: handle,
                    size: 48,
                    liveRing: true,
                    imageUrl: watch.creatorAvatarUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.v2IsLive(handle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          started == null
                              ? l10n.v2RecordingInCloud
                              : l10n.v2RecordingStarted(
                                  DateFormat.Hm(
                                    Localizations.localeOf(
                                      context,
                                    ).toLanguageTag(),
                                  ).format(started),
                                ),
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.liveText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SsV2StatusChip(
                    label: l10n.v2ChipRec,
                    tone: SsV2ChipTone.recording,
                  ),
                ],
              ),
              if (started != null) ...<Widget>[
                const SizedBox(height: 12),
                _LiveTimer(
                  startedAt: started,
                  minutesCharged: item.recording?.minutesCharged ?? 0,
                  now: now,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveTimer extends StatefulWidget {
  const _LiveTimer({
    required this.startedAt,
    required this.minutesCharged,
    required this.now,
  });

  final DateTime startedAt;
  final int minutesCharged;
  final DateTime Function() now;

  @override
  State<_LiveTimer> createState() => _LiveTimerState();
}

class _LiveTimerState extends State<_LiveTimer> {
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
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final Duration elapsed = widget.now().difference(widget.startedAt);
    final int seconds = math.max(0, elapsed.inSeconds);
    final String clock =
        '${seconds ~/ 3600}:${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    // Billing is per started minute.
    final int used = math.max(widget.minutesCharged, (seconds + 59) ~/ 60);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Expanded(
          child: Text(
            clock,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            l10n.v2MinutesUsedSoFar(used),
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, color: palette.liveText),
          ),
        ),
      ],
    );
  }
}

class _ChannelList extends StatelessWidget {
  const _ChannelList({required this.watches, required this.now});

  final List<WatchSummary> watches;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return SsV2Card(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < watches.length; i++) ...<Widget>[
            if (i > 0) Container(height: 1, color: palette.divider),
            _ChannelRow(watch: watches[i], now: now),
          ],
        ],
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.watch, required this.now});

  final WatchSummary watch;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final String handle = '@${watch.creatorUsername.replaceFirst('@', '')}';
    final bool noMinutes =
        watch.status == WatchStatus.pausedInsufficientCredit ||
        watch.autoRecordState == AutoRecordState.pausedNoCloudMinutes;
    final bool paused =
        watch.status == WatchStatus.paused ||
        watch.status == WatchStatus.pausedError ||
        watch.status == WatchStatus.disabled;
    final (
      String subtitle,
      String chip,
      SsV2ChipTone tone,
    ) = watch.verificationRequired
        ? (
            l10n.v2VerifyOwnershipToRecord,
            l10n.v2ChipVerify,
            SsV2ChipTone.alert,
          )
        : watch.isLive
        ? (
            l10n.v2LiveNotRecording,
            l10n.v2ChipLiveNotRecording,
            SsV2ChipTone.liveNotRecording,
          )
        : noMinutes
        ? (l10n.v2PausedNoMinutes, l10n.v2ChipPaused, SsV2ChipTone.paused)
        : paused
        ? (l10n.v2PausedByYou, l10n.v2ChipPaused, SsV2ChipTone.paused)
        : (_lastLive(context), l10n.v2ChipWaiting, SsV2ChipTone.waiting);
    return InkWell(
      onTap: () => context.push(AppRoutes.channelDetail(watch.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            SsV2Avatar(name: handle, imageUrl: watch.creatorAvatarUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: palette.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: SsV2StatusChip(label: chip, tone: tone),
            ),
          ],
        ),
      ),
    );
  }

  String _lastLive(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DateTime? last = watch.lastLiveAt?.toLocal();
    if (last == null) return l10n.v2NoLiveYet;
    return l10n.v2LastLive(relativeDay(context, last, now()));
  }
}

/// "today", "yesterday" or a short date ("Oct 20").
String relativeDay(BuildContext context, DateTime value, DateTime now) {
  final AppLocalizations l10n = context.l10n;
  final DateTime day = DateTime(value.year, value.month, value.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  final int diff = today.difference(day).inDays;
  if (diff == 0) return l10n.v2Today;
  if (diff == 1) return l10n.v2Yesterday;
  return DateFormat.MMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(value);
}

class _RecordingGrid extends StatelessWidget {
  const _RecordingGrid({required this.recordings, required this.now});

  final List<RecordingSummary> recordings;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < 2; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: i < recordings.length
                ? _RecordingTile(recording: recordings[i], index: i)
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({required this.recording, required this.index});

  final RecordingSummary recording;
  final int index;

  static const List<List<Color>> _gradients = <List<Color>>[
    <Color>[Color(0xFF8B6CFF), Color(0xFF4A2FC9)],
    <Color>[Color(0xFF9DB8F0), Color(0xFF3D63B8)],
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final DateTime? started = recording.startedAt?.toLocal();
    final String handle = '@${recording.creatorUsername.replaceFirst('@', '')}';
    final String date = started == null
        ? ''
        : ' · ${DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).format(started)}';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(AppRoutes.recordingDetail(recording.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            image: true,
            label: l10n.v2RecordingThumbnail,
            child: Container(
              height: 128,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: const Alignment(-0.34, -0.94),
                  end: const Alignment(0.34, 0.94),
                  colors: _gradients[index % _gradients.length],
                ),
              ),
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.thumbOverlay,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  _clock(recording.durationSeconds),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            recording.creatorDisplayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '$handle$date',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: palette.textMuted),
          ),
        ],
      ),
    );
  }

  static String _clock(int totalSeconds) {
    final int s = math.max(0, totalSeconds);
    final int hours = s ~/ 3600;
    final String mm = ((s % 3600) ~/ 60).toString().padLeft(
      hours > 0 ? 2 : 1,
      '0',
    );
    final String ss = (s % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }
}

class _SetupChecklist extends StatelessWidget {
  const _SetupChecklist({required this.emailVerified});

  final bool emailVerified;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final int done = emailVerified ? 1 : 0;
    const int total = 4;
    final List<Widget> steps = <Widget>[
      _SetupStep(
        number: 1,
        state: emailVerified ? _StepState.done : _StepState.active,
        title: l10n.v2StepVerifyEmail,
        hint: l10n.v2StepVerifyEmailHint,
      ),
      _SetupStep(
        number: 2,
        state: emailVerified ? _StepState.active : _StepState.pending,
        title: l10n.v2StepAddChannel,
        hint: l10n.v2StepAddChannelHint,
        action: emailVerified
            ? SsV2Button(
                label: l10n.v2Start,
                size: SsV2ButtonSize.small,
                expand: false,
                onPressed: () => context.push(AppRoutes.addChannel),
              )
            : null,
      ),
      _SetupStep(
        number: 3,
        state: _StepState.pending,
        title: l10n.v2StepVerifyOwnership,
        hint: l10n.v2StepVerifyOwnershipHint,
      ),
      _SetupStep(
        number: 4,
        state: _StepState.pending,
        title: l10n.v2StepFirstRecording,
        hint: l10n.v2StepFirstRecordingHint,
      ),
    ];
    return SsV2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.v2GetSetUp,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                l10n.v2StepsDone(done, total),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.link,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SsV2ProgressBar(
            value: done / total,
            track: palette.divider,
            fill: palette.primary,
          ),
          const SizedBox(height: 4),
          for (int i = 0; i < steps.length; i++) ...<Widget>[
            if (i > 0) Container(height: 1, color: palette.divider),
            steps[i],
          ],
        ],
      ),
    );
  }
}

enum _StepState { done, active, pending }

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.number,
    required this.state,
    required this.title,
    required this.hint,
    this.action,
  });

  final int number;
  final _StepState state;
  final String title;
  final String hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final Widget badge = switch (state) {
      _StepState.done => Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.success,
          shape: BoxShape.circle,
        ),
        child: const SsV2Icon(
          SsV2IconGlyph.check,
          size: 18,
          strokeWidth: 2.6,
          color: Colors.white,
        ),
      ),
      _StepState.active => Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.primary,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$number',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      _StepState.pending => Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: palette.border, width: 2),
        ),
        child: Text(
          '$number',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: palette.textMuted,
          ),
        ),
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          ExcludeSemantics(child: badge),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: state == _StepState.active
                        ? palette.text
                        : palette.textMuted,
                    decoration: state == _StepState.done
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: palette.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: TextStyle(fontSize: 13, color: palette.textMuted),
                ),
              ],
            ),
          ),
          if (action != null) ...<Widget>[const SizedBox(width: 12), action!],
        ],
      ),
    );
  }
}

class _ServerInfoCard extends StatelessWidget {
  const _ServerInfoCard();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    return SsV2Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SsV2Icon(SsV2IconGlyph.cloud, size: 20, color: palette.link),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.v2ServerInfoTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.v2ServerInfoBody,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// AHomeLoading.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    Widget row() => const Row(
      children: <Widget>[
        SsV2Skeleton(width: 44, height: 44, radius: 22),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SsV2Skeleton(widthFactor: 0.6, height: 14),
              SizedBox(height: 8),
              SsV2Skeleton(widthFactor: 0.4, height: 12),
            ],
          ),
        ),
      ],
    );
    return Semantics(
      label: l10n.v2LoadingLabel,
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: ssV2Gap(<Widget>[
            const SsV2Skeleton(height: 132, radius: 22),
            const SsV2Skeleton(widthFactor: 0.4, height: 20),
            SsV2Card(
              child: Column(
                children: <Widget>[row(), const SizedBox(height: 18), row()],
              ),
            ),
            const Row(
              children: <Widget>[
                Expanded(child: SsV2Skeleton(height: 128, radius: 16)),
                SizedBox(width: 12),
                Expanded(child: SsV2Skeleton(height: 128, radius: 16)),
              ],
            ),
          ], 16),
        ),
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: <Widget>[
        SsV2Card(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.errorBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SsV2Icon(
                  SsV2IconGlyph.alert,
                  size: 30,
                  color: palette.errorText,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.v2HomeErrorTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.v2HomeErrorBody,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: palette.textMuted),
              ),
              const SizedBox(height: 16),
              SsV2Button(label: l10n.v2Retry, onPressed: onRetry),
            ],
          ),
        ),
      ],
    );
  }
}
