import 'package:flutter/material.dart';

import '../core/format.dart';
import '../theme/ss_theme.dart';
import 'ss_inline_alert.dart';

/// G01
class SsOfflineBanner extends StatelessWidget {
  const SsOfflineBanner({super.key, this.lastUpdated});
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: cs.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: SsSpace.lg, vertical: SsSpace.sm),
        child: Row(children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: SsSpace.sm),
          Expanded(
            child: Text(
              lastUpdated == null ? 'Không có kết nối mạng' : 'Không có kết nối · Cập nhật lúc ${fmtTime(lastUpdated!)}',
              style: context.tt.bodySmall!.copyWith(color: cs.onSurface),
            ),
          ),
        ]),
      ),
    );
  }
}

/// G04, G06, M06, S18
class SsFullScreenState extends StatelessWidget {
  const SsFullScreenState({super.key, required this.icon, required this.title, required this.body, this.primary, this.secondary});
  final IconData icon;
  final String title, body;
  final Widget? primary, secondary;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SsSpace.xxl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Spacer(),
            Icon(icon, size: 56, color: cs.primary),
            const SizedBox(height: SsSpace.xl),
            Text(title, style: context.tt.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: SsSpace.sm),
            Text(body, style: context.tt.bodyLarge!.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
            const Spacer(),
            if (primary != null) primary!,
            if (secondary != null) ...[const SizedBox(height: SsSpace.sm), secondary!],
          ]),
        ),
      ),
    );
  }
}

class SsNotificationTile extends StatelessWidget {
  const SsNotificationTile({super.key, required this.tone, required this.title, required this.body, required this.time, this.icon, this.unread = false, this.onTap});
  final SsAlertTone tone;
  final IconData? icon;
  final String title, body, time;
  final bool unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final t = ssToneColors(context, tone);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread ? cs.primaryContainer.withValues(alpha: .5) : null,
        padding: const EdgeInsets.symmetric(horizontal: SsSpace.screenH, vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 20, backgroundColor: t.bg, child: Icon(icon ?? t.icon, color: t.fg, size: 20)),
          const SizedBox(width: SsSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.tt.titleSmall!.copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w600)),
              Text(body, style: context.tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(time, style: context.tt.labelSmall!.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
          if (unread) Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
        ]),
      ),
    );
  }
}

enum SsAdPlacement { homeMid, watchListEnd, libraryBetweenGroups }

/// Chỉ render khi Plan.free + consent sẵn sàng (C01–C03). Thay child bằng AdWidget của google_mobile_ads.
class SsBannerAd extends StatelessWidget {
  const SsBannerAd({super.key, required this.placement});
  final SsAdPlacement placement;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(SsRadius.md), border: Border.all(color: cs.outline)),
      child: Text('Quảng cáo', style: context.tt.labelSmall!.copyWith(color: cs.onSurfaceVariant)),
    );
  }
}

enum SsDownloadState { idle, downloading, done, failed }

class SsDownloadProgress extends StatelessWidget {
  const SsDownloadProgress({super.key, required this.bytesDone, required this.bytesTotal, this.onCancel});
  final int bytesDone, bytesTotal;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final p = bytesTotal == 0 ? 0.0 : bytesDone / bytesTotal;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Đang tải về · ${(p * 100).round()}%', style: context.tt.labelMedium),
          const SizedBox(height: SsSpace.xs),
          LinearProgressIndicator(value: p, color: context.ss.cloud, backgroundColor: cs.surfaceContainerHighest),
          const SizedBox(height: SsSpace.xs),
          Text('${fmtBytes(bytesDone)} / ${fmtBytes(bytesTotal)}', style: context.ssType.mono.copyWith(fontSize: 12, color: cs.onSurfaceVariant)),
        ]),
      ),
      if (onCancel != null) IconButton(tooltip: 'Huỷ tải', onPressed: onCancel, icon: const Icon(Icons.close_rounded)),
    ]);
  }
}
