import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums.dart';
import '../../core/format.dart';
import '../../core/mock_data.dart';
import '../../theme/ss_theme.dart';
import '../../widgets/widgets.dart';

/// L05 — Chi tiết bản ghi + L13 delete dialog. Biến thể L06/L07/L09–L11 xem docs/SCREENS.md.
class RecordingDetailScreen extends StatelessWidget {
  const RecordingDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final r = mockRecordings.firstWhere((e) => e.id == id, orElse: () => mockRecordings.first);
    final cs = context.cs, ss = context.ss;
    final playable = r.status == RecordingStatus.completed || r.status == RecordingStatus.partial || r.status == RecordingStatus.recovered;

    return Scaffold(
      body: SafeArea(
        child: ListView(children: [
          SsAppBar(
            title: r.creator.name,
            variant: SsAppBarVariant.compact,
            actions: [
              IconButton(tooltip: 'Chia sẻ', icon: const Icon(Icons.ios_share_rounded), onPressed: () {}),
            ],
          ),
          AspectRatio(
            aspectRatio: 9 / 12,
            child: Material(
              color: ss.player,
              child: InkWell(
                onTap: playable ? () => context.push('/player/${r.id}') : null,
                child: Center(
                  child: playable
                      ? Icon(Icons.play_circle_rounded, size: 72, color: ss.onPlayer)
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          SsStatusPill(status: r.status),
                          const SizedBox(height: SsSpace.sm),
                          Text('Bản ghi đang được xử lý', style: context.tt.bodyMedium!.copyWith(color: ss.onPlayerMuted)),
                        ]),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(SsSpace.screenH),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(r.title, style: context.tt.titleLarge),
              const SizedBox(height: SsSpace.xs),
              Text('${fmtTime(r.startedAt)} · ${fmtDuration(r.duration)}${r.sizeBytes != null ? ' · ${fmtBytes(r.sizeBytes!)}' : ''}',
                  style: context.ssType.mono.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: SsSpace.md),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (r.copies != CopyLocation.cloudOnly) const SsLocationChip(engine: Engine.local, label: 'Trên máy này'),
                if (r.copies != CopyLocation.localOnly) const SsLocationChip(engine: Engine.cloud, label: 'Cloud · lưu 14 ngày'),
                if (r.status != RecordingStatus.completed) SsStatusPill(status: r.status),
              ]),
              if (r.status == RecordingStatus.partial) ...[
                const SizedBox(height: SsSpace.lg),
                const SsInlineAlert(
                    tone: SsAlertTone.warning, title: 'Bản ghi không đầy đủ', body: 'Một phần livestream bị thiếu do mất kết nối.'),
              ],
              const SizedBox(height: SsSpace.xxl),
              SsButton(
                label: 'Xoá bản ghi',
                icon: Icons.delete_rounded,
                variant: SsButtonVariant.secondary,
                onPressed: () async {
                  final what = await showSsDeleteDialog(context, r);
                  if (what != null && context.mounted) {
                    showSsToast(context, 'Đã xoá', actionLabel: 'Hoàn tác', onAction: () {});
                    context.pop();
                  }
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
