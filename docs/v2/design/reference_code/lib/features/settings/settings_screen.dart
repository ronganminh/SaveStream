import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums.dart';
import '../../theme/ss_theme.dart';
import '../../widgets/widgets.dart';

/// S01 — Settings · Free. Restore purchases ở nhóm Tài khoản.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void go(String p) => context.push('/settings/$p');
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.only(bottom: SsSpace.xxxl), children: [
        const SsAppBar(title: 'Cài đặt', plan: Plan.free),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SsSpace.screenH),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SsInlineAlert(
              tone: SsAlertTone.upgrade,
              title: 'Nâng cấp Pro',
              body: 'Auto-record cloud, 20 creator, không quảng cáo.',
              actions: [
                SsButton(
                  label: 'Xem gói Pro',
                  variant: SsButtonVariant.upgrade,
                  size: SsButtonSize.md44,
                  expand: false,
                  onPressed: () => context.push('/paywall?context=${PaywallContext.removeAds.name}'),
                ),
              ],
            ),
            SsSettingsGroup(header: 'Gói', children: [
              SsSettingsRow(leading: Icons.workspace_premium_rounded, title: 'Gói & mức dùng', value: 'Free', onTap: () => go('plan')),
            ]),
            SsSettingsGroup(header: 'Record', children: [
              SsSettingsRow(leading: Icons.sd_storage_rounded, title: 'Bộ nhớ', onTap: () => go('storage')),
              SsSettingsRow(leading: Icons.battery_saver_rounded, title: 'Record nền', onTap: () => go('background')),
              SsSettingsRow(leading: Icons.notifications_rounded, title: 'Thông báo', onTap: () => go('notifications')),
            ]),
            SsSettingsGroup(header: 'Ứng dụng', children: [
              SsSettingsRow(leading: Icons.dark_mode_rounded, title: 'Giao diện', value: 'Theo hệ thống', onTap: () => go('appearance')),
              SsSettingsRow(leading: Icons.translate_rounded, title: 'Ngôn ngữ', value: 'Tiếng Việt', onTap: () => go('language')),
            ]),
            SsSettingsGroup(header: 'Tài khoản', children: [
              SsSettingsRow(leading: Icons.person_rounded, title: 'Tài khoản', subtitle: 'alex@example.com', onTap: () => go('account')),
              SsSettingsRow(leading: Icons.restore_rounded, title: 'Khôi phục giao dịch', trailing: SsRowTrailing.none, onTap: () {}),
            ]),
            SsSettingsGroup(header: 'Hỗ trợ', children: [
              SsSettingsRow(leading: Icons.help_rounded, title: 'Trợ giúp', onTap: () => go('help')),
              SsSettingsRow(leading: Icons.gavel_rounded, title: 'Pháp lý', onTap: () => go('legal')),
              SsSettingsRow(leading: Icons.verified_user_rounded, title: 'Sử dụng có trách nhiệm', onTap: () => go('responsible-use')),
            ]),
          ]),
        ),
      ]),
    );
  }
}
