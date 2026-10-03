import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/enums.dart';
import '../../core/format.dart';
import '../../theme/ss_theme.dart';
import '../../widgets/widgets.dart';

/// R02 / R03 — Active Local Recording (root navigator, che bottom nav). Không banner ad.
class ActiveRecordingScreen extends StatelessWidget {
  const ActiveRecordingScreen({super.key, required this.sessionId});
  final String sessionId;

  Future<void> _confirmStop(BuildContext context) async {
    final ok = await showSsDialog<bool>(context,
        title: 'Dừng recording?',
        body: 'Phần đã record sẽ được lưu vào Bản ghi.',
        icon: Icons.stop_circle_rounded,
        destructive: true,
        actions: [
          SsButton(label: 'Dừng & lưu', variant: SsButtonVariant.destructive, onPressed: () => Navigator.pop(context, true)),
          SsButton(label: 'Tiếp tục record', variant: SsButtonVariant.tertiary, onPressed: () => Navigator.pop(context, false)),
        ]);
    if (ok == true) {
      await recorder.stop();
      if (context.mounted) {
        showSsToast(context, 'Đã lưu vào Bản ghi', icon: Icons.check_circle_rounded);
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ss = context.ss;
    final timerScale = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5);
    return Theme(
      data: Theme.of(context).copyWith(scaffoldBackgroundColor: ss.player),
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: recorder,
            builder: (context, _) {
              final r = recorder.active;
              if (r == null || r.sessionId != sessionId) {
                return Center(child: Text('Recording đã kết thúc', style: context.tt.bodyLarge!.copyWith(color: ss.onPlayer)));
              }
              final starting = r.status == RecordingStatus.starting;
              return Padding(
                padding: const EdgeInsets.all(SsSpace.screenH),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    IconButton(
                        tooltip: 'Thu nhỏ',
                        onPressed: () => context.pop(),
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: ss.onPlayer)),
                    const Spacer(),
                    SsLocationChip(engine: r.engine),
                  ]),
                  const Spacer(),
                  SsCreatorAvatar(initials: r.creator.initials, size: SsAvatarSize.s56, isLive: true),
                  const SizedBox(height: SsSpace.md),
                  Text(r.creator.name, textAlign: TextAlign.center, style: context.tt.titleLarge!.copyWith(color: ss.onPlayer)),
                  const SizedBox(height: SsSpace.lg),
                  Center(child: SsStatusPill(status: r.status)),
                  const SizedBox(height: SsSpace.md),
                  Semantics(
                    label: 'Thời gian đã record',
                    value: fmtDuration(r.elapsed),
                    child: Text(
                      starting ? 'Đang kết nối tới LIVE…' : fmtDuration(r.elapsed),
                      textAlign: TextAlign.center,
                      textScaler: timerScale,
                      style: starting
                          ? context.tt.bodyLarge!.copyWith(color: ss.onPlayerMuted)
                          : context.ssType.timer.copyWith(color: ss.onPlayer),
                    ),
                  ),
                  if (!starting)
                    Text(fmtBytes(r.bytes), textAlign: TextAlign.center, style: context.ssType.mono.copyWith(color: ss.onPlayerMuted)),
                  const Spacer(),
                  SsButton(
                    label: 'Dừng recording',
                    icon: Icons.stop_rounded,
                    variant: SsButtonVariant.destructive,
                    loading: r.status == RecordingStatus.finalizing,
                    onPressed: () => _confirmStop(context),
                  ),
                ]),
              );
            },
          ),
        ),
      ),
    );
  }
}
