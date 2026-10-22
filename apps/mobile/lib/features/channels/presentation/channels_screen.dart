/// AChannels · AChannelsEmpty · AChannelsError — the v2 Channels tab.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../home/presentation/controllers/home_dashboard_controller.dart';
import '../../home/presentation/home_screen.dart' show relativeDay;
import '../../recordings/domain/models/recording_summary.dart';
import '../domain/models/channel_verification.dart';
import '../domain/models/watch_summary.dart';
import 'add_channel_sheet.dart';
import 'channel_v2_parts.dart';
import 'controllers/watch_providers.dart';
import 'watch_limit_sheet.dart';

class ChannelsScreen extends ConsumerStatefulWidget {
  const ChannelsScreen({this.openAddSheet = false, super.key});

  /// Opens the Add channel sheet right away (route `/channels/add`).
  final bool openAddSheet;

  @override
  ConsumerState<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends ConsumerState<ChannelsScreen> {
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.openAddSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final GoRouter router = GoRouter.of(context);
        _sheetOpen = true;
        final WatchSummary? created = await showAddChannelSheet(context);
        _sheetOpen = false;
        // Leave the /channels/add page once the sheet is gone.
        if (router.canPop()) {
          router.pop();
        } else {
          router.go(AppRoutes.channels);
        }
        if (created != null) {
          router.push(AppRoutes.channelVerify(created.id));
        }
      });
    }
  }

  Future<void> _add(List<WatchSummary> watches) async {
    Entitlement? entitlement;
    try {
      entitlement = await ref.read(entitlementProvider.future);
    } on Object {
      // The server enforces the limit too; let the user try.
    }
    if (!mounted) return;
    if (entitlement != null &&
        watches.length >= entitlement.limits.maxWatches) {
      await showWatchLimitSheet(
        context,
        count: watches.length,
        limit: entitlement.limits.maxWatches,
      );
      return;
    }
    await _openSheet();
  }

  Future<void> _openSheet() async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    final WatchSummary? created = await showAddChannelSheet(context);
    _sheetOpen = false;
    if (!mounted || created == null) return;
    context.push(AppRoutes.channelVerify(created.id));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<WatchSummary>> watches = ref.watch(watchListProvider);
    final List<RecordingSummary> recordings =
        ref.watch(watchRecordingsProvider).value ?? const <RecordingSummary>[];
    final DateTime Function() now = ref.watch(homeClockProvider);
    // Loaded up front so Add channel can check the channel limit at once.
    ref.watch(entitlementProvider);
    final List<WatchSummary>? items = watches.value;
    final bool populated = items != null && items.isNotEmpty;

    return SsV2Page(
      safeBottom: false,
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ChannelsTopBar(
                title: l10n.v2NavChannels,
                actions: <Widget>[
                  if (watches.hasValue && populated) const ChannelsBellButton(),
                ],
              ),
              Expanded(
                child: watches.when(
                  skipLoadingOnRefresh: true,
                  skipLoadingOnReload: true,
                  loading: () => const _ChannelsSkeleton(),
                  error: (Object error, StackTrace stackTrace) =>
                      ChannelsCenteredMessage(
                        glyph: SsV2IconGlyph.alert,
                        title: l10n.v2ChannelsErrorTitle,
                        body: l10n.v2ChannelsErrorBody,
                        actionWidth: 200,
                        action: SsV2Button(
                          label: l10n.v2RetryShort,
                          variant: SsV2ButtonVariant.outlined,
                          leading: SsV2Icon(
                            SsV2IconGlyph.refresh,
                            size: 20,
                            color: SsV2Palette.of(context).text,
                          ),
                          onPressed: () => ref.invalidate(watchListProvider),
                        ),
                      ),
                  data: (List<WatchSummary> data) => data.isEmpty
                      ? ChannelsCenteredMessage(
                          glyph: SsV2IconGlyph.channels,
                          title: l10n.v2ChannelsEmptyTitle,
                          body: l10n.v2ChannelsEmptyBody,
                          actionWidth: 240,
                          action: SsV2Button(
                            key: const ValueKey<String>('channels-add-empty'),
                            label: l10n.v2AddChannel,
                            leading: const SsV2Icon(
                              SsV2IconGlyph.plus,
                              size: 20,
                              color: Colors.white,
                            ),
                            onPressed: () => _add(data),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(watchListProvider);
                            ref.invalidate(watchRecordingsProvider);
                            await ref.read(watchListProvider.future);
                          },
                          child: _ChannelList(
                            watches: data,
                            recordings: recordings,
                            now: now,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (populated)
            Positioned(
              right: 16,
              bottom: 16,
              child: _AddChannelFab(onPressed: () => _add(items)),
            ),
        ],
      ),
    );
  }
}

class _ChannelList extends StatelessWidget {
  const _ChannelList({
    required this.watches,
    required this.recordings,
    required this.now,
  });

  final List<WatchSummary> watches;
  final List<RecordingSummary> recordings;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Room under the last card for the floating button.
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: ssV2Gap(<Widget>[
          Text(
            context.l10n.v2ChannelsIntro,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: palette.textMuted,
            ),
          ),
          for (final WatchSummary watch in watches)
            ChannelListCard(
              watch: watch,
              recording: activeRecordingFor(watch, recordings),
              now: now,
            ),
        ], 12),
      ),
    );
  }
}

/// One channel in the list: avatar, handle, status line and chip.
class ChannelListCard extends ConsumerWidget {
  const ChannelListCard({
    required this.watch,
    required this.recording,
    required this.now,
    super.key,
  });

  final WatchSummary watch;
  final RecordingSummary? recording;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final String handle = channelHandle(watch);
    final ChannelState state = channelStateOf(watch, recording: recording);
    final TextStyle subtitleStyle = TextStyle(
      fontSize: 13,
      color: palette.textMuted,
    );

    Widget subtitle(String text) => Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: subtitleStyle,
    );

    final Widget line;
    final (String chip, SsV2ChipTone tone) = switch (state) {
      ChannelState.recording => (l10n.v2ChipRec, SsV2ChipTone.recording),
      ChannelState.unverified => (l10n.v2ChipUnverified, SsV2ChipTone.paused),
      ChannelState.paused => (l10n.v2ChipPaused, SsV2ChipTone.paused),
      ChannelState.liveNotRecording => (
        l10n.v2ChipLiveNotRecording,
        SsV2ChipTone.liveNotRecording,
      ),
      ChannelState.noMinutes => (l10n.v2ChipPaused, SsV2ChipTone.paused),
      ChannelState.waiting => (l10n.v2ChipWaiting, SsV2ChipTone.waiting),
    };
    switch (state) {
      case ChannelState.recording:
        final DateTime? started = recording?.startedAt;
        line = started == null
            ? subtitle(l10n.v2RecordingInCloud)
            : RecordingElapsedBuilder(
                startedAt: started,
                now: now,
                builder: (BuildContext context, int seconds) => subtitle(
                  l10n.v2RowRecording(formatRecordingClock(seconds)),
                ),
              );
      case ChannelState.unverified:
        final ChannelVerification? pending = ref
            .watch(channelVerificationProvider(watch.id))
            .value;
        final String? code = pending == null || pending.isExpiredAt(now())
            ? null
            : pending.code;
        line = subtitle(
          code == null
              ? l10n.v2VerifyOwnershipToRecord
              : l10n.v2RowAddCode(code),
        );
      case ChannelState.paused:
        line = subtitle(l10n.v2PausedByYou);
      case ChannelState.liveNotRecording:
        line = subtitle(
          channelOutOfMinutes(watch)
              ? l10n.v2PausedNoMinutes
              : watch.autoRecord
              ? l10n.v2LiveNotRecording
              : l10n.v2RowLiveAutoOff,
        );
      case ChannelState.noMinutes:
        line = subtitle(l10n.v2PausedNoMinutes);
      case ChannelState.waiting:
        final DateTime? last = watch.lastLiveAt?.toLocal();
        final String? when = last == null
            ? null
            : relativeDay(context, last, now());
        line = subtitle(switch ((watch.autoRecord, when)) {
          (true, final String w) => l10n.v2RowAutoOnLastLive(w),
          (false, final String w) => l10n.v2RowAutoOffLastLive(w),
          (true, null) => l10n.v2RowAutoOnNoLive,
          (false, null) => l10n.v2RowAutoOffNoLive,
        });
    }

    return Material(
      color: palette.surface,
      textStyle: ssV2BaseText(palette),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: palette.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>('channel-${watch.id}'),
        onTap: () => context.push(AppRoutes.channelDetail(watch.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              SsV2Avatar(
                name: handle,
                size: 48,
                liveRing: state == ChannelState.recording,
              ),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    line,
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
      ),
    );
  }
}

class _AddChannelFab extends StatelessWidget {
  const _AddChannelFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.6),
            offset: const Offset(0, 10),
            blurRadius: 24,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Material(
        color: palette.primary,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey<String>('channels-add'),
          onTap: onPressed,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SsV2Icon(
                    SsV2IconGlyph.plus,
                    size: 22,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n.v2AddChannel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelsSkeleton extends StatelessWidget {
  const _ChannelsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.v2LoadingLabel,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: ssV2Gap(<Widget>[
          const SsV2Skeleton(height: 14, widthFactor: 0.8),
          for (int i = 0; i < 3; i++)
            const SsV2Card(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  SsV2Skeleton(width: 48, height: 48, radius: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SsV2Skeleton(height: 16, widthFactor: 0.6),
                        SizedBox(height: 8),
                        SsV2Skeleton(height: 12, widthFactor: 0.8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ], 12),
      ),
    );
  }
}
