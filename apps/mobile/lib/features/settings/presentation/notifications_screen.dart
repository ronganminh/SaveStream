/// ANotifications · ANotificationsEmpty — the v2 notifications inbox.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../home/presentation/controllers/home_dashboard_controller.dart';
import '../domain/models/app_notification.dart';
import 'controllers/notification_feed_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    // The feed is shared with the bell; fetch fresh items when the inbox
    // opens, keeping what is already loaded on screen meanwhile.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(notificationFeedProvider);
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _open(AppNotification item) async {
    final String? route = notificationRoute(item);
    if (route != null) context.push(route);
    if (item.read) return;
    try {
      await ref.read(notificationFeedProvider.notifier).markRead(item.id);
    } on Object {
      if (!mounted) return;
      SsSnackbar.show(context, context.l10n.notificationMarkReadFailed);
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await ref.read(notificationFeedProvider.notifier).markAllRead();
    } on Object {
      if (mounted) {
        SsSnackbar.show(context, context.l10n.v2NotifMarkAllFailed);
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final AsyncValue<NotificationFeedState> feed = ref.watch(
      notificationFeedProvider,
    );
    final DateTime now = ref.watch(homeClockProvider)();
    final bool hasUnread =
        feed.value?.items.any((AppNotification item) => !item.read) ?? false;

    return SsV2Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsV2Header(
            title: l10n.v2NotifTitle,
            onBack: _back,
            actions: <Widget>[
              if (hasUnread)
                TextButton(
                  key: const ValueKey<String>('notifications-mark-all'),
                  onPressed: _markingAll ? null : _markAllRead,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.link,
                    padding: const EdgeInsets.all(12),
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontFamily: SsTypography.uiFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(l10n.v2NotifMarkAllRead),
                ),
            ],
          ),
          Expanded(
            child: feed.when(
              skipLoadingOnRefresh: true,
              skipLoadingOnReload: true,
              loading: () => const _InboxSkeleton(),
              error: (Object error, StackTrace stackTrace) => _CenteredMessage(
                glyph: SsV2IconGlyph.alert,
                title: l10n.v2NotifErrorTitle,
                body: l10n.v2NotifErrorBody,
                action: SizedBox(
                  width: 200,
                  child: SsV2Button(
                    label: l10n.v2RetryShort,
                    variant: SsV2ButtonVariant.outlined,
                    leading: SsV2Icon(
                      SsV2IconGlyph.refresh,
                      size: 20,
                      color: palette.text,
                    ),
                    onPressed: () => ref.invalidate(notificationFeedProvider),
                  ),
                ),
              ),
              data: (NotificationFeedState data) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(notificationFeedProvider);
                  await ref.read(notificationFeedProvider.future);
                },
                child: data.items.isEmpty
                    ? _CenteredMessage(
                        glyph: SsV2IconGlyph.bell,
                        title: l10n.v2NotifEmptyTitle,
                        body: l10n.v2NotifEmptyBody,
                      )
                    : _InboxList(
                        data: data,
                        now: now,
                        onOpen: _open,
                        onLoadMore: () => ref
                            .read(notificationFeedProvider.notifier)
                            .loadMore(),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where tapping a notification goes, or null when it has nowhere to go
/// (it is only marked read).
String? notificationRoute(AppNotification item) {
  final String? id = item.resourceId?.trim();
  final bool hasId = id != null && id.isNotEmpty;
  switch (item.effectiveKind) {
    // Balance notices open the minutes screen even when they name the
    // recording that ran out.
    case 'credits_low':
    case 'free_minutes_low':
    case 'cloud_minutes_exhausted':
    case 'purchase_completed':
      return AppRoutes.usage;
  }
  if (!hasId) return null;
  return switch (item.resourceType) {
    'watch' => AppRoutes.channelDetail(id),
    'recording' => AppRoutes.recordingDetail(id),
    _ => null,
  };
}

const Set<String> _balanceKinds = <String>{
  'credits_low',
  'free_minutes_low',
  'cloud_minutes_exhausted',
  'purchase_completed',
};

enum _Tone { error, success, warning, brand }

/// Icon and tile tone of each notification kind, as drawn.
(SsV2IconGlyph, _Tone) _visualOf(String kind) {
  return switch (kind) {
    'creator_live' ||
    'recording_started' => (SsV2IconGlyph.channels, _Tone.error),
    'recording_ready' ||
    'purchase_completed' => (SsV2IconGlyph.check, _Tone.success),
    'recording_failed' ||
    'recording_missed' => (SsV2IconGlyph.alert, _Tone.error),
    'credits_low' || 'free_minutes_low' => (SsV2IconGlyph.clock, _Tone.warning),
    'cloud_minutes_exhausted' => (SsV2IconGlyph.card, _Tone.error),
    'recording_expiring' => (SsV2IconGlyph.download, _Tone.warning),
    'channel_verification_needed' => (SsV2IconGlyph.shield, _Tone.warning),
    _ => (SsV2IconGlyph.bell, _Tone.brand),
  };
}

/// Localized title of the kinds the app knows; the server's title otherwise
/// (admin announcements, kinds added later).
String notificationTitle(AppLocalizations l10n, AppNotification item) {
  return switch (item.effectiveKind) {
    'creator_live' => l10n.v2NotifKindLive,
    'recording_started' => l10n.v2NotifKindStarted,
    'recording_ready' => l10n.v2NotifKindReady,
    'recording_failed' => l10n.v2NotifKindEnded,
    'recording_missed' => l10n.v2NotifKindMissed,
    'credits_low' || 'free_minutes_low' => l10n.v2NotifKindLow,
    'cloud_minutes_exhausted' => l10n.v2NotifKindOut,
    'recording_expiring' => l10n.v2NotifKindExpiring,
    'purchase_completed' => l10n.v2NotifKindPurchase,
    'channel_verification_needed' => l10n.v2NotifKindVerify,
    _ => item.title,
  };
}

/// "20:01" today, "Yesterday", then "Oct 19" (with the year when it is not
/// this year).
String notificationTime(BuildContext context, DateTime value, DateTime now) {
  final String locale = Localizations.localeOf(context).toLanguageTag();
  final DateTime local = value.toLocal();
  final DateTime day = DateTime(local.year, local.month, local.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  final int diff = today.difference(day).inDays;
  if (diff <= 0) return DateFormat.Hm(locale).format(local);
  if (diff == 1) return context.l10n.v2NotifYesterday;
  if (local.year == now.year) return DateFormat.MMMd(locale).format(local);
  return DateFormat.yMMMd(locale).format(local);
}

class _InboxList extends StatelessWidget {
  const _InboxList({
    required this.data,
    required this.now,
    required this.onOpen,
    required this.onLoadMore,
  });

  final NotificationFeedState data;
  final DateTime now;
  final ValueChanged<AppNotification> onOpen;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final bool footer = data.hasMore || data.loadMoreError != null;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewPaddingOf(context).bottom + 16,
      ),
      itemCount: data.items.length + (footer ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index < data.items.length) {
          final AppNotification item = data.items[index];
          return _NotificationRow(
            key: ValueKey<String>('notification-${item.id}'),
            item: item,
            now: now,
            onTap: () => onOpen(item),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            children: <Widget>[
              if (data.loadMoreError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.v2NotifLoadMoreFailed,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: palette.errorText),
                  ),
                ),
              if (data.hasMore)
                SsV2Button(
                  label: l10n.loadMoreAction,
                  variant: SsV2ButtonVariant.text,
                  isLoading: data.isLoadingMore,
                  onPressed: onLoadMore,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The kind's icon tile; for a notification about one of the user's
/// channels, that channel's picture with the icon as a small badge.
class _NotificationLeading extends StatelessWidget {
  const _NotificationLeading({
    required this.avatarUrl,
    required this.name,
    required this.glyph,
    required this.tileBg,
    required this.tileFg,
  });

  final String? avatarUrl;
  final String name;
  final SsV2IconGlyph glyph;
  final Color tileBg;
  final Color tileFg;

  @override
  Widget build(BuildContext context) {
    final String? url = avatarUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SsV2Icon(glyph, size: 20, color: tileFg),
      );
    }
    final SsV2Palette palette = SsV2Palette.of(context);
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          SsV2Avatar(name: name, size: 40, fontSize: 14, imageUrl: url),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tileBg,
                shape: BoxShape.circle,
                border: Border.all(color: palette.surface, width: 2),
              ),
              child: SsV2Icon(glyph, size: 11, color: tileFg),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.now,
    required this.onTap,
    super.key,
  });

  final AppNotification item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final (SsV2IconGlyph glyph, _Tone tone) = _visualOf(item.effectiveKind);
    final (Color tileBg, Color tileFg) = switch (tone) {
      _Tone.error => (palette.errorBackground, palette.errorText),
      _Tone.success => (palette.successBackground, palette.success),
      _Tone.warning => (palette.warningBackground, palette.warning),
      _Tone.brand => (palette.tint, palette.link),
    };
    final String title = notificationTitle(l10n, item);
    final String time = notificationTime(context, item.createdAt, now);
    return Semantics(
      button: true,
      label: <String>[
        if (!item.read) l10n.v2NotifUnread,
        title,
        item.body,
        time,
      ].join('. '),
      excludeSemantics: true,
      child: Material(
        color: item.read ? Colors.transparent : palette.tintSoft,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.divider)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _NotificationLeading(
                  // Balance notices keep their icon even when they name the
                  // recording that used the minutes.
                  avatarUrl: _balanceKinds.contains(item.effectiveKind)
                      ? null
                      : item.avatarUrl,
                  name: item.title,
                  glyph: glyph,
                  tileBg: tileBg,
                  tileFg: tileFg,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.body,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    key: item.read
                        ? null
                        : ValueKey<String>('notification-unread-${item.id}'),
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: item.read ? null : palette.primary,
                      shape: BoxShape.circle,
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

/// Centered empty/error body: 88px tinted tile, 22/800 title, muted body and
/// an optional action. Scrollable so pull-to-refresh works on it.
class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.glyph,
    required this.title,
    required this.body,
    this.action,
  });

  final SsV2IconGlyph glyph;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 48
                  ? constraints.maxHeight - 48
                  : 0,
            ),
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
                  if (action != null) ...<Widget>[
                    const SizedBox(height: 20),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        for (int i = 0; i < 6; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.divider)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SsV2Skeleton(width: 40, height: 40, radius: 12),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SsV2Skeleton(widthFactor: 0.5, height: 16),
                      SizedBox(height: 8),
                      SsV2Skeleton(widthFactor: 0.9),
                      SizedBox(height: 8),
                      SsV2Skeleton(width: 48, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
