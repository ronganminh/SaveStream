import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_settings_controller.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.settings, super.key});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SsSpacing.lg),
          children: <Widget>[
            SsCard(
              child: Column(
                children: <Widget>[
                  SsListTile(
                    title: l10n.profileTitle,
                    leading: const Icon(Icons.person_outline_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.profile),
                  ),
                  const Divider(),
                  SsListTile(
                    title: l10n.creditsTitle,
                    subtitle: l10n.settingsCreditsSubtitle,
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.credits),
                  ),
                  const Divider(),
                  SsListTile(
                    title: l10n.billingTitle,
                    subtitle: l10n.settingsBillingSubtitle,
                    leading: const Icon(Icons.credit_card_outlined),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.billing),
                  ),
                  const Divider(),
                  SsListTile(
                    title: l10n.languageTitle,
                    subtitle: settings.locale.languageCode == 'vi'
                        ? l10n.languageVietnamese
                        : l10n.languageEnglish,
                    leading: const Icon(Icons.language_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.language),
                  ),
                  const Divider(),
                  SsListTile(
                    title: l10n.themeLabel,
                    leading: const Icon(Icons.contrast_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.theme),
                  ),
                  const Divider(),
                  SsListTile(
                    title: l10n.designSystemTitle,
                    leading: const Icon(Icons.palette_outlined),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.componentGallery),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
