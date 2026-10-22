/// ARecordings · ARecordingsEmpty · ARecordingsLoading · ARecordingsProcessing
/// · ARecordingsFailed · ARecordingsExpiring — the v2 Recordings tab.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../channels/presentation/channel_v2_parts.dart';
import '../../home/presentation/controllers/home_dashboard_controller.dart';
import '../domain/models/recording_summary.dart';
import 'controllers/recording_library_controller.dart';
import 'recording_v2_parts.dart';

enum RecordingsFilter { all, recording, processing, failed, expiring }

class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  final TextEditingController _query = TextEditingController();
  RecordingsFilter _filter = RecordingsFilter.all;
  bool _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _query.clear();
    });
  }

  bool _matches(RecordingSummary item, DateTime now) {
    final bool inFilter = switch (_filter) {
      RecordingsFilter.all => true,
      RecordingsFilter.recording =>
        recordingGroupOf(item) == RecordingGroup.live,
      RecordingsFilter.processing =>
        recordingGroupOf(item) == RecordingGroup.processing,
      RecordingsFilter.failed =>
        recordingGroupOf(item) == RecordingGroup.failed,
      RecordingsFilter.expiring =>
        recordingGroupOf(item) == RecordingGroup.ready &&
            isExpiringSoon(item, now),
    };
    if (!inFilter) return false;
    final String query = _query.text.trim().toLowerCase().replaceFirst('@', '');
    if (query.isEmpty) return true;
    return item.creatorUsername.toLowerCase().contains(query) ||
        item.creatorDisplayName.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final AsyncValue<List<RecordingSummary>> library = ref.watch(
      recordingLibraryProvider,
    );
    final DateTime Function() clock = ref.watch(homeClockProvider);

    return SsV2Page(
      safeBottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_searching)
            _SearchBar(
              controller: _query,
              onChanged: (_) => setState(() {}),
              onClose: _closeSearch,
            )
          else
            ChannelsTopBar(
              title: l10n.v2NavRecordings,
              actions: <Widget>[
                SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    key: const ValueKey<String>('recordings-search'),
                    tooltip: l10n.v2RecSearch,
                    onPressed: () => setState(() => _searching = true),
                    icon: SsV2Icon(SsV2IconGlyph.search, color: palette.text),
                  ),
                ),
              ],
            ),
          _FilterChips(
            selected: _filter,
            onSelected: (RecordingsFilter filter) =>
                setState(() => _filter = filter),
          ),
          Expanded(
            child: library.when(
              skipLoadingOnRefresh: true,
              skipLoadingOnReload: true,
              loading: () => const _LibrarySkeleton(),
              error: (Object error, StackTrace stackTrace) =>
                  ChannelsCenteredMessage(
                    glyph: SsV2IconGlyph.alert,
                    title: l10n.v2RecErrorTitle,
                    body: l10n.v2RecErrorBody,
                    actionWidth: 200,
                    action: SsV2Button(
                      label: l10n.v2RetryShort,
                      variant: SsV2ButtonVariant.outlined,
                      leading: SsV2Icon(
                        SsV2IconGlyph.refresh,
                        size: 20,
                        color: palette.text,
                      ),
                      onPressed: () => ref.invalidate(recordingLibraryProvider),
                    ),
                  ),
              data: (List<RecordingSummary> items) {
                if (items.isEmpty) {
                  return ChannelsCenteredMessage(
                    glyph: SsV2IconGlyph.recordings,
                    title: l10n.v2RecEmptyTitle,
                    body: l10n.v2RecEmptyBody,
                    actionWidth: 220,
                    action: SsV2Button(
                      label: l10n.v2RecGoToChannels,
                      variant: SsV2ButtonVariant.outlined,
                      onPressed: () => context.go(AppRoutes.channels),
                    ),
                  );
                }
                final DateTime now = clock();
                // Thumbnail placeholders take the artboard colors in order
                // down the library, so a recording keeps its color in every
                // filter.
                final Map<String, int> shades = <String, int>{};
                for (final RecordingSummary item in items) {
                  if (recordingGroupOf(item) == RecordingGroup.ready) {
                    shades[item.id] = shades.length;
                  }
                }
                final List<RecordingSummary> shown = items
                    .where((RecordingSummary item) => _matches(item, now))
                    .toList(growable: false);
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(recordingLibraryProvider);
                    await ref.read(recordingLibraryProvider.future);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: _LibraryBody(
                      filter: _filter,
                      items: shown,
                      query: _query.text.trim(),
                      now: now,
                      clock: clock,
                      shades: shades,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                key: const ValueKey<String>('recordings-search-field'),
                controller: controller,
                autofocus: true,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: TextStyle(fontSize: 16, color: palette.text),
                decoration: InputDecoration(
                  hintText: l10n.v2RecSearchHint,
                  isDense: true,
                  filled: true,
                  fillColor: palette.surface,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SsV2Icon(
                      SsV2IconGlyph.search,
                      size: 20,
                      color: palette.textMuted,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: palette.border),
                  ),
                ),
              ),
            ),
            SizedBox.square(
              dimension: 48,
              child: IconButton(
                tooltip: l10n.v2RecSearchClose,
                onPressed: onClose,
                icon: SsV2Icon(SsV2IconGlyph.close, color: palette.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final RecordingsFilter selected;
  final ValueChanged<RecordingsFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    String label(RecordingsFilter filter) => switch (filter) {
      RecordingsFilter.all => l10n.v2RecFilterAll,
      RecordingsFilter.recording => l10n.v2RecFilterRecording,
      RecordingsFilter.processing => l10n.v2RecFilterProcessing,
      RecordingsFilter.failed => l10n.v2RecFilterFailed,
      RecordingsFilter.expiring => l10n.v2RecFilterExpiring,
    };
    return Semantics(
      label: l10n.v2RecFilters,
      container: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: Row(
          children: _hGap(<Widget>[
            for (final RecordingsFilter filter in RecordingsFilter.values)
              _FilterChip(
                key: ValueKey<String>('recordings-filter-${filter.name}'),
                label: label(filter),
                selected: filter == selected,
                palette: palette,
                onTap: () => onSelected(filter),
              ),
          ], 8),
        ),
      ),
    );
  }
}

List<Widget> _hGap(List<Widget> children, double gap) => <Widget>[
  for (int i = 0; i < children.length; i++) ...<Widget>[
    if (i > 0) SizedBox(width: gap),
    children[i],
  ],
];

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final SsV2Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? palette.link : palette.text;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.tint : palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? palette.primary : palette.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (selected) ...<Widget>[
                  SsV2Icon(SsV2IconGlyph.check, size: 16, color: foreground),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: foreground,
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

class _LibraryBody extends StatelessWidget {
  const _LibraryBody({
    required this.filter,
    required this.items,
    required this.query,
    required this.now,
    required this.clock,
    required this.shades,
  });

  final RecordingsFilter filter;
  final List<RecordingSummary> items;
  final String query;
  final DateTime now;
  final DateTime Function() clock;
  final Map<String, int> shades;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final Widget? lead = switch (filter) {
      RecordingsFilter.processing => Text(
        l10n.v2RecProcessingIntro,
        style: TextStyle(fontSize: 14, height: 1.5, color: palette.textMuted),
      ),
      RecordingsFilter.failed => SsV2Banner(
        tone: SsV2Tone.success,
        title: l10n.v2RecFailedBannerTitle,
        child: Text(l10n.v2RecFailedBannerBody),
      ),
      RecordingsFilter.expiring => SsV2Banner(
        tone: SsV2Tone.warning,
        child: Text(l10n.v2RecExpiringBanner),
      ),
      RecordingsFilter.all || RecordingsFilter.recording => null,
    };
    final Widget content;
    if (items.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text(
          query.isNotEmpty
              ? l10n.v2RecSearchEmpty(query)
              : switch (filter) {
                  RecordingsFilter.recording => l10n.v2RecNoneRecording,
                  RecordingsFilter.processing => l10n.v2RecNoneProcessing,
                  RecordingsFilter.failed => l10n.v2RecNoneFailed,
                  RecordingsFilter.expiring => l10n.v2RecNoneExpiring,
                  RecordingsFilter.all => l10n.v2RecSearchEmpty(query),
                },
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.5, color: palette.textMuted),
        ),
      );
    } else if (filter == RecordingsFilter.failed) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: ssV2Gap(<Widget>[
          for (final RecordingSummary item in items)
            _FailedRow(recording: item),
        ], 12),
      );
    } else {
      content = _Grid(
        children: <Widget>[
          for (final RecordingSummary item in items)
            _RecordingCard(
              key: ValueKey<String>('recording-card-${item.id}'),
              recording: item,
              now: now,
              clock: clock,
              shade: shades[item.id],
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (lead != null) ...<Widget>[
          lead,
          SizedBox(height: filter == RecordingsFilter.processing ? 14 : 12),
        ],
        content,
      ],
    );
  }
}

/// Two columns, 12px apart, rows 14px apart (the artboard grid).
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 14,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

void _open(BuildContext context, RecordingSummary recording) {
  // A recording in progress lives on its channel (timer, Stop recording).
  final String? watchId = recording.watchId;
  if (recordingGroupOf(recording) == RecordingGroup.live && watchId != null) {
    context.push(AppRoutes.channelDetail(watchId));
    return;
  }
  context.push(AppRoutes.recordingDetail(recording.id));
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({
    required this.recording,
    required this.now,
    required this.clock,
    this.shade,
    super.key,
  });

  final RecordingSummary recording;
  final DateTime now;
  final DateTime Function() clock;

  /// Index into [recordingGradients] for the placeholder.
  final int? shade;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final String handle = recordingHandle(recording);
    final DateTime? started = recording.startedAt;
    final String day = started == null ? '' : recordingDay(context, started);
    final RecordingGroup group = recordingGroupOf(recording);
    const TextStyle titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );
    final TextStyle subStyle = TextStyle(
      fontSize: 12,
      color: palette.textMuted,
    );

    final Widget tile;
    String title = handle;
    Widget subtitle = Text(day, style: subStyle);
    bool ellipsize = true;
    switch (group) {
      case RecordingGroup.live:
        final bool capturing = isCapturing(recording);
        tile = _Thumb(
          recording: recording,
          topLeft: RecordingThumbChip(
            label: capturing ? l10n.v2RecChipRec : l10n.v2RecChipStarting,
            dot: capturing,
            background: capturing ? palette.error : palette.neutralBackground,
            foreground: capturing ? Colors.white : palette.neutralText,
          ),
          colors: recordingGradients.last,
        );
        if (capturing) {
          title = l10n.v2RecLiveNow(handle);
          subtitle = started == null
              ? Text(
                  l10n.v2RowRecording(
                    formatRecordingClock(recording.durationSeconds),
                  ),
                  style: subStyle,
                )
              : RecordingElapsedBuilder(
                  startedAt: started,
                  now: clock,
                  builder: (BuildContext context, int seconds) => Text(
                    l10n.v2RowRecording(formatRecordingClock(seconds)),
                    style: subStyle,
                  ),
                );
        } else {
          subtitle = Text(l10n.v2RecStartingSub, style: subStyle);
        }
      case RecordingGroup.processing:
        ellipsize = false;
        final double? progress = recording.progress;
        tile = Container(
          height: 200,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.tintSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.divider),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ssV2Gap(<Widget>[
              RecordingRingSpinner(track: palette.tint, arc: palette.primary),
              Text(
                progress == null
                    ? l10n.v2RecProcessing
                    : l10n.v2RecProcessingPercent((progress * 100).round()),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.link,
                ),
              ),
              if (progress != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1).toDouble(),
                      backgroundColor: palette.divider,
                      color: palette.primary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ], 10),
          ),
        );
      case RecordingGroup.failed:
        ellipsize = false;
        tile = Container(
          height: 200,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.errorBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ssV2Gap(<Widget>[
              SsV2Icon(SsV2IconGlyph.alert, size: 32, color: palette.errorText),
              Text(
                l10n.v2RecCouldntSave,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.errorText,
                ),
              ),
              Text(
                '${failureReason(l10n, recording)} · '
                '${l10n.v2RecMinutesCharged(recording.minutesCharged)}',
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: palette.liveText,
                ),
              ),
            ], 8),
          ),
        );
      case RecordingGroup.ready:
        final bool expired = isExpired(recording, now);
        tile = _Thumb(
          recording: recording,
          topLeft: expired
              ? RecordingThumbChip(
                  label: l10n.v2RecChipExpired,
                  background: palette.neutralBackground,
                  foreground: palette.neutralText,
                )
              : isExpiringSoon(recording, now)
              ? RecordingThumbChip(
                  label: l10n.v2RecDaysLeft(
                    daysUntil(recording.expiresAt!, now),
                  ),
                  background: palette.warningBackground,
                  foreground: palette.warning,
                )
              : null,
          duration: recording.durationSeconds,
          colors: shade == null
              ? null
              : recordingGradients[shade! % recordingGradients.length],
        );
    }

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context, recording),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            tile,
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: ellipsize ? 1 : null,
              overflow: ellipsize ? TextOverflow.ellipsis : null,
              style: titleStyle,
            ),
            const SizedBox(height: 6),
            subtitle,
          ],
        ),
      ),
    );
  }
}

/// 200px thumbnail with optional top-left chip and duration badge.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.recording,
    this.topLeft,
    this.duration,
    this.colors,
  });

  final RecordingSummary recording;
  final Widget? topLeft;
  final int? duration;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: context.l10n.v2RecordingThumbnail,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              RecordingThumbnailFill(recording: recording, colors: colors),
              if (topLeft != null) Positioned(left: 8, top: 8, child: topLeft!),
              if (duration != null)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: RecordingDurationBadge(seconds: duration!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A failed recording on the Failed filter: why it failed and what to do.
class _FailedRow extends StatelessWidget {
  const _FailedRow({required this.recording});

  final RecordingSummary recording;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final DateTime? started = recording.startedAt;
    final String? advice = failureAdvice(l10n, recording);
    const TextStyle bold = TextStyle(fontWeight: FontWeight.w700);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(AppRoutes.recordingDetail(recording.id)),
        child: SsV2Card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.errorBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SsV2Icon(
                  SsV2IconGlyph.alert,
                  size: 20,
                  color: palette.errorText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: ssV2Gap(<Widget>[
                    Text(
                      recordingHandle(recording),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (started != null)
                      Text(
                        recordingDayTime(context, started),
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textMuted,
                        ),
                      ),
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(text: l10n.v2RecWhy, style: bold),
                          TextSpan(text: ' ${failureReason(l10n, recording)}'),
                        ],
                      ),
                      style: const TextStyle(fontSize: 14, height: 1.45),
                    ),
                    if (advice != null)
                      Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: l10n.v2RecWhatToDo,
                              style: bold.copyWith(color: palette.text),
                            ),
                            TextSpan(text: ' $advice'),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: palette.textMuted,
                        ),
                      ),
                  ], 4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibrarySkeleton extends StatelessWidget {
  const _LibrarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: _Grid(
          children: <Widget>[
            for (int i = 0; i < 4; i++)
              const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SsV2Skeleton(height: 200, radius: 16),
                  SizedBox(height: 8),
                  SsV2Skeleton(height: 14, widthFactor: 0.8),
                  SizedBox(height: 8),
                  SsV2Skeleton(height: 12, widthFactor: 0.5),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
