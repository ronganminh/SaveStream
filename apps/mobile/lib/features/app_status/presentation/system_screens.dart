/// AOffline · AServerError · AMaintenance · AForceUpdate — full-screen
/// system states over the signed-in app (see MainShell).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/external_links.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';

Widget _retryIcon(Color color) =>
    SsV2Icon(SsV2IconGlyph.refresh, size: 20, color: color);

Widget _footnote(BuildContext context, String text, {Key? key}) {
  final SsV2Palette palette = SsV2Palette.of(context);
  return Text(
    text,
    key: key,
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: 13, color: palette.textMuted),
  );
}

/// AOffline — no connection; recording continues in the cloud.
class OfflineScreen extends StatelessWidget {
  const OfflineScreen({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    return SsV2Page(
      child: Semantics(
        liveRegion: true,
        child: SsV2StatusBody(
          glyph: SsV2IconGlyph.wifiOff,
          tone: SsV2TileTone.neutral,
          title: l10n.sysOfflineTitle,
          body: l10n.sysOfflineBody,
          actions: <Widget>[
            SsV2Button(
              key: const ValueKey<String>('system-offline-retry'),
              label: l10n.sysTryAgain,
              leading: _retryIcon(palette.onPrimary),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// AServerError — the server failed; recordings keep going.
class ServerErrorScreen extends StatelessWidget {
  const ServerErrorScreen({required this.onRetry, this.requestId, super.key});

  final VoidCallback onRetry;
  final String? requestId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final String? id = requestId?.trim().isEmpty ?? true ? null : requestId;
    return SsV2Page(
      child: SsV2StatusBody(
        glyph: SsV2IconGlyph.alert,
        tone: SsV2TileTone.error,
        title: l10n.sysServerTitle,
        body: l10n.sysServerBody,
        extra: id == null ? null : _footnote(context, l10n.sysErrorId(id)),
        actions: <Widget>[
          SsV2Button(
            key: const ValueKey<String>('system-server-retry'),
            label: l10n.sysRetry,
            leading: _retryIcon(palette.onPrimary),
            onPressed: onRetry,
          ),
          SsV2Button(
            key: const ValueKey<String>('system-server-support'),
            label: l10n.sysContactSupport,
            variant: SsV2ButtonVariant.text,
            onPressed: () => openMail(
              AppConfig.supportEmail,
              subject: id == null ? null : l10n.sysErrorId(id),
            ),
          ),
        ],
      ),
    );
  }
}

/// AMaintenance — /v1/app/status says maintenance (with an optional ETA).
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({
    required this.onRetry,
    required this.statusPageUrl,
    this.eta,
    super.key,
  });

  final VoidCallback onRetry;
  final Uri statusPageUrl;
  final DateTime? eta;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final DateTime? when = eta?.toUtc();
    String body = l10n.sysMaintenanceBody;
    InlineSpan? span;
    if (when != null) {
      final String locale = Localizations.localeOf(context).toString();
      final DateTime now = DateTime.now().toUtc();
      final bool today =
          now.year == when.year &&
          now.month == when.month &&
          now.day == when.day;
      final String time =
          (today ? DateFormat.Hm(locale) : DateFormat.MMMd(locale).add_Hm())
              .format(when);
      final String bold = l10n.sysMaintenanceEta(time);
      body = l10n.sysMaintenanceBodyEta(bold);
      final int at = body.indexOf(bold);
      span = TextSpan(
        children: <InlineSpan>[
          TextSpan(text: body.substring(0, at)),
          TextSpan(
            text: bold,
            style: TextStyle(fontWeight: FontWeight.w700, color: palette.text),
          ),
          TextSpan(text: body.substring(at + bold.length)),
        ],
      );
    }
    return SsV2Page(
      child: SsV2StatusBody(
        glyph: SsV2IconGlyph.wrench,
        tone: SsV2TileTone.warning,
        title: l10n.sysMaintenanceTitle,
        body: body,
        bodySpan: span,
        actions: <Widget>[
          SsV2Button(
            key: const ValueKey<String>('system-maintenance-status'),
            label: l10n.sysCheckStatus,
            variant: SsV2ButtonVariant.outlined,
            leading: SsV2Icon(
              SsV2IconGlyph.globe,
              size: 20,
              color: palette.text,
            ),
            onPressed: () => openExternalUrl(statusPageUrl),
          ),
          SsV2Button(
            key: const ValueKey<String>('system-maintenance-retry'),
            label: l10n.sysTryAgain,
            variant: SsV2ButtonVariant.text,
            leading: _retryIcon(palette.link),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// AForceUpdate — this version is below the minimum supported one.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({
    required this.installedVersion,
    required this.requiredVersion,
    super.key,
  });

  final String installedVersion;
  final String requiredVersion;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SsV2Page(
      child: SsV2StatusBody(
        glyph: SsV2IconGlyph.install,
        tone: SsV2TileTone.brand,
        title: l10n.sysUpdateTitle,
        body: l10n.sysUpdateBody,
        extra: _footnote(
          context,
          l10n.sysUpdateVersions(installedVersion, requiredVersion),
        ),
        actions: <Widget>[
          SsV2Button(
            key: const ValueKey<String>('system-update'),
            label: l10n.sysUpdateAction,
            onPressed: openPlayStoreListing,
          ),
        ],
      ),
    );
  }
}
