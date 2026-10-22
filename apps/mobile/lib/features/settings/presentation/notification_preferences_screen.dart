/// ANotifPrefs — per-event Push / Email switches and the OS permission banner.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/contracts/push_service.dart';
import '../domain/models/notification_preferences.dart';
import 'controllers/notification_preferences_providers.dart';
import 'controllers/push_permission_provider.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  // Back from the system settings: read the permission again.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => ref.read(pushPermissionProvider.notifier).refresh(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.settings);
    }
  }

  Future<void> _save(NotificationPreferences next) async {
    final bool saved = await ref
        .read(notificationPreferencesProvider.notifier)
        .save(next);
    if (saved || !mounted) return;
    SsSnackbar.show(context, context.l10n.notificationPreferencesSaveFailed);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final AsyncValue<NotificationPreferences> preferences = ref.watch(
      notificationPreferencesProvider,
    );
    final PushPermissionStatus? permission = ref
        .watch(pushPermissionProvider)
        .value;

    return SsV2Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsV2Header(title: l10n.v2NotifTitle, onBack: _back),
          Expanded(
            child: preferences.when(
              skipLoadingOnRefresh: true,
              skipLoadingOnReload: true,
              loading: () => const Center(child: SsV2Spinner()),
              error: (Object error, StackTrace stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        l10n.v2NotifPrefsErrorTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 200,
                        child: SsV2Button(
                          label: l10n.v2RetryShort,
                          variant: SsV2ButtonVariant.outlined,
                          leading: SsV2Icon(
                            SsV2IconGlyph.refresh,
                            size: 20,
                            color: palette.text,
                          ),
                          onPressed: () =>
                              ref.invalidate(notificationPreferencesProvider),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (NotificationPreferences value) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: ssV2Gap(<Widget>[
                  if (permission == PushPermissionStatus.denied)
                    SsV2Banner(
                      key: const ValueKey<String>('notif-prefs-os-off'),
                      tone: SsV2Tone.warning,
                      glyph: SsV2IconGlyph.bell,
                      actions: <Widget>[
                        SsV2Button(
                          key: const ValueKey<String>(
                            'notif-prefs-open-settings',
                          ),
                          label: l10n.v2NotifPrefsOpenSettings,
                          variant: SsV2ButtonVariant.outlined,
                          size: SsV2ButtonSize.small,
                          onPressed: () => ref
                              .read(pushPermissionProvider.notifier)
                              .openSystemSettings(),
                        ),
                      ],
                      child: Text(l10n.v2NotifPrefsOsOff),
                    )
                  else if (permission == PushPermissionStatus.notDetermined)
                    SsV2Banner(
                      key: const ValueKey<String>('notif-prefs-ask'),
                      tone: SsV2Tone.brand,
                      glyph: SsV2IconGlyph.bell,
                      actions: <Widget>[
                        SsV2Button(
                          label: l10n.v2NotifPrefsAllow,
                          variant: SsV2ButtonVariant.outlined,
                          size: SsV2ButtonSize.small,
                          onPressed: () => ref
                              .read(pushPermissionProvider.notifier)
                              .request(),
                        ),
                      ],
                      child: Text(l10n.v2NotifPrefsAsk),
                    ),
                  _PreferencesTable(value: value, onChanged: _save),
                  Text(
                    <String>[
                      l10n.v2NotifPrefsNote,
                      if (!value.emailSupported) l10n.v2NotifPrefsEmailOff,
                    ].join(' '),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: palette.textMuted,
                    ),
                  ),
                ], 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A Push or Email cell: a switch bound to a server preference, a locked
/// "always on" switch, or a dash when the event has no such channel.
sealed class _Cell {
  const _Cell();
}

final class _Toggle extends _Cell {
  const _Toggle(this.value, this.update);

  final bool value;
  final NotificationPreferences Function(bool value) update;
}

final class _AlwaysOn extends _Cell {
  const _AlwaysOn();
}

final class _None extends _Cell {
  const _None();
}

class _Row {
  const _Row({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.push,
    required this.email,
    this.single = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final _Cell push;
  final _Cell email;

  /// One server switch for every channel: drawn once across both columns.
  final bool single;
}

class _PreferencesTable extends StatelessWidget {
  const _PreferencesTable({required this.value, required this.onChanged});

  final NotificationPreferences value;
  final ValueChanged<NotificationPreferences> onChanged;

  List<_Row> _rows(AppLocalizations l10n) {
    final NotificationPreferences p = value;
    return <_Row>[
      _Row(
        id: 'live',
        title: l10n.v2NotifPrefLive,
        subtitle: l10n.v2NotifPrefLiveSub,
        push: _Toggle(p.creatorLive, (v) => p.copyWith(creatorLive: v)),
        email: _Toggle(
          p.emailCreatorLive,
          (v) => p.copyWith(emailCreatorLive: v),
        ),
      ),
      _Row(
        id: 'started',
        title: l10n.v2NotifPrefStarted,
        subtitle: l10n.v2NotifPrefStartedSub,
        push: _Toggle(
          p.recordingStarted,
          (v) => p.copyWith(recordingStarted: v),
        ),
        email: const _None(),
      ),
      _Row(
        id: 'ready',
        title: l10n.v2NotifPrefReady,
        subtitle: l10n.v2NotifPrefReadySub,
        push: _Toggle(p.recordingReady, (v) => p.copyWith(recordingReady: v)),
        email: _Toggle(
          p.emailRecordingReady,
          (v) => p.copyWith(emailRecordingReady: v),
        ),
      ),
      _Row(
        id: 'failed',
        title: l10n.v2NotifPrefFailed,
        subtitle: l10n.v2NotifPrefFailedSub,
        push: _Toggle(p.recordingFailed, (v) => p.copyWith(recordingFailed: v)),
        email: _Toggle(
          p.emailRecordingFailed,
          (v) => p.copyWith(emailRecordingFailed: v),
        ),
      ),
      _Row(
        id: 'low',
        title: l10n.v2NotifPrefLow,
        subtitle: l10n.v2NotifPrefLowSub,
        push: const _AlwaysOn(),
        email: _Toggle(
          p.emailCreditsLow,
          (v) => p.copyWith(emailCreditsLow: v),
        ),
      ),
      _Row(
        id: 'out',
        title: l10n.v2NotifPrefOut,
        subtitle: l10n.v2NotifPrefOutSub,
        push: const _AlwaysOn(),
        email: _Toggle(
          p.emailCreditsExhausted,
          (v) => p.copyWith(emailCreditsExhausted: v),
        ),
      ),
      _Row(
        id: 'expiring',
        title: l10n.v2NotifPrefExpiring,
        subtitle: l10n.v2NotifPrefExpiringSub,
        push: _Toggle(
          p.recordingExpiring,
          (v) => p.copyWith(recordingExpiring: v),
        ),
        email: _Toggle(
          p.emailRecordingExpiring,
          (v) => p.copyWith(emailRecordingExpiring: v),
        ),
      ),
      _Row(
        id: 'news',
        title: l10n.v2NotifPrefNews,
        subtitle: l10n.v2NotifPrefNewsSub,
        push: _Toggle(p.marketing, (v) => p.copyWith(marketing: v)),
        email: const _None(),
        single: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final List<_Row> rows = _rows(l10n);
    final TextStyle headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: palette.textMuted,
    );
    return SsV2Card(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(l10n.v2NotifPrefsEvent, style: headerStyle),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      l10n.v2NotifPrefsPush,
                      textAlign: TextAlign.center,
                      style: headerStyle,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      l10n.v2NotifPrefsEmail,
                      textAlign: TextAlign.center,
                      style: headerStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0) Container(height: 1, color: palette.divider),
            _PreferenceRow(
              row: rows[i],
              emailEnabled: value.emailSupported,
              onChanged: onChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.row,
    required this.emailEnabled,
    required this.onChanged,
  });

  final _Row row;
  final bool emailEnabled;
  final ValueChanged<NotificationPreferences> onChanged;

  Widget _cell(
    BuildContext context,
    _Cell cell, {
    required String channel,
    required bool enabled,
  }) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    return switch (cell) {
      _Toggle(:final bool value, :final update) => SsV2Switch(
        key: ValueKey<String>('notif-pref-${row.id}-$channel'),
        value: value,
        semanticLabel: row.single
            ? row.title
            : l10n.v2NotifPrefSwitch(
                channel == 'push'
                    ? l10n.v2NotifPrefsPush
                    : l10n.v2NotifPrefsEmail,
                row.title,
              ),
        onChanged: enabled ? (bool next) => onChanged(update(next)) : null,
      ),
      _AlwaysOn() => Semantics(
        label: l10n.v2NotifPrefAlwaysOn(row.title),
        child: ExcludeSemantics(
          child: SsV2Switch(
            key: ValueKey<String>('notif-pref-${row.id}-$channel'),
            value: true,
            semanticLabel: row.title,
            onChanged: null,
          ),
        ),
      ),
      _None() => Semantics(
        label: l10n.v2NotifPrefNoEmail(row.title),
        child: ExcludeSemantics(
          child: Text(
            '—',
            style: TextStyle(fontSize: 15, color: palette.disabled),
          ),
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  row.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.subtitle,
                  style: TextStyle(fontSize: 12, color: palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (row.single)
            SizedBox(
              width: 132,
              child: Center(
                child: _cell(context, row.push, channel: 'all', enabled: true),
              ),
            )
          else ...<Widget>[
            SizedBox(
              width: 64,
              child: Center(
                child: _cell(context, row.push, channel: 'push', enabled: true),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 64,
              child: Center(
                child: _cell(
                  context,
                  row.email,
                  channel: 'email',
                  enabled: emailEnabled,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
