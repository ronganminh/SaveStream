import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/enums.dart';
import '../../core/mock_data.dart';
import '../../theme/ss_theme.dart';
import '../../widgets/widgets.dart';
import '../recording/start_recording_sheet.dart';

/// H01 — Home · Free. Biến thể khác: H01-loading/offline/limit, H02, H03, H06, Q01 (docs/SCREENS.md).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 11 ? 'Chào buổi sáng' : (h < 18 ? 'Chào buổi chiều' : 'Chào buổi tối');
  }

  @override
  Widget build(BuildContext context) {
    final usage = mockUsageFree;
    final live = mockCreators.where((c) => c.liveStatus == LiveStatus.live).toList();
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: recorder,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: SsSpace.xxl),
          children: [
            SsAppBar(title: '${_greeting()}, Alex', subtitle: 'Hôm nay', plan: Plan.free, showNotifications: true, hasUnread: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SsSpace.screenH),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (recorder.isActive) ...[
                  SsActiveRecordingCard(
                    recording: recorder.active!,
                    onOpen: () => context.push('/recording/${recorder.active!.sessionId}'),
                    onStop: () => recorder.stop(),
                  ),
                  const SizedBox(height: SsSpace.lg),
                ],
                SsQuotaCard(
                  usage: usage,
                  onWatchAd: () => showSsToast(context, 'Reward flow R06–R10 chưa nối', icon: Icons.smart_display_rounded),
                  onUpgrade: () => context.push('/paywall?context=${PaywallContext.quotaExhausted.name}'),
                ),
                const SizedBox(height: SsSpace.xxl),
                Text('Đang LIVE', style: context.tt.titleMedium),
                const SizedBox(height: SsSpace.md),
                if (live.isEmpty)
                  Text('Chưa có creator nào đang LIVE.', style: context.tt.bodyMedium!.copyWith(color: context.cs.onSurfaceVariant))
                else
                  for (final c in live) ...[
                    SsCreatorTile(
                      creator: c,
                      onTap: () => context.push('/watch/creator/${c.id}'),
                      onRecord: recorder.isActive || usage.freeExhausted
                          ? null
                          : () => showStartRecordingSheet(context, c),
                      onToggleNotify: (_) {},
                      onAutoRecord: () => context.push('/paywall?context=${PaywallContext.autoRecord.name}'),
                    ),
                    const SizedBox(height: SsSpace.md),
                  ],
                const SizedBox(height: SsSpace.lg),
                const SsBannerAd(placement: SsAdPlacement.homeMid),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
