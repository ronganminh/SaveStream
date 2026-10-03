import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/enums.dart';
import '../../core/mock_data.dart';
import '../../theme/ss_theme.dart';
import '../../widgets/widgets.dart';
import '../recording/start_recording_sheet.dart';

/// W01 — Watch List · Free 2/3.
class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final u = mockUsageFree;
    final all = mockCreators;
    final liveN = all.where((c) => c.liveStatus == LiveStatus.live).length;
    final list = switch (_filter) {
      1 => all.where((c) => c.liveStatus == LiveStatus.live).toList(),
      2 => all.where((c) => c.liveStatus == LiveStatus.offline).toList(),
      _ => all,
    };
    final full = u.watchCount >= u.watchLimit;
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.only(bottom: SsSpace.xxl), children: [
        SsAppBar(
          title: 'Theo dõi',
          subtitle: '${u.watchCount}/${u.watchLimit} creator · Free',
          showNotifications: true,
          actions: [
            IconButton(
              tooltip: 'Thêm creator',
              icon: const Icon(Icons.add_rounded),
              // 3/3 → vẫn bấm được, mở paywall "Watch List đầy".
              onPressed: () => full
                  ? context.push('/paywall?context=${PaywallContext.watchlistFull.name}')
                  : context.push('/watch/add'),
            ),
          ],
        ),
        SsFilterChips(
          items: [
            SsFilterChipItem('Tất cả', count: all.length),
            SsFilterChipItem('LIVE', count: liveN),
            SsFilterChipItem('Offline', count: all.length - liveN),
          ],
          selected: _filter,
          onSelected: (i) => setState(() => _filter = i),
        ),
        Padding(
          padding: const EdgeInsets.all(SsSpace.screenH),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!full)
              Padding(
                padding: const EdgeInsets.only(bottom: SsSpace.md),
                child: Text('Còn ${u.watchLimit - u.watchCount} chỗ. Pro theo dõi tối đa 20 creator.',
                    style: context.tt.bodyMedium!.copyWith(color: context.cs.onSurfaceVariant)),
              ),
            for (final c in list) ...[
              SsCreatorTile(
                creator: c,
                onTap: () => context.push('/watch/creator/${c.id}'),
                onRecord: recorder.isActive ? null : () => showStartRecordingSheet(context, c),
                onToggleNotify: (_) {},
                onAutoRecord: () => context.push('/paywall?context=${PaywallContext.autoRecord.name}'),
              ),
              const SizedBox(height: SsSpace.md),
            ],
            if (!full)
              SsButton(
                label: 'Thêm creator · còn ${u.watchLimit - u.watchCount} chỗ',
                icon: Icons.person_add_rounded,
                variant: SsButtonVariant.secondary,
                onPressed: () => context.push('/watch/add'),
              ),
            const SizedBox(height: SsSpace.lg),
            const SsBannerAd(placement: SsAdPlacement.watchListEnd),
          ]),
        ),
      ]),
    );
  }
}
