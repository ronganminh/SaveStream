/// S13 — Terms and privacy hub.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

class LegalPrivacyScreen extends StatelessWidget {
  const LegalPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.legalHubTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SsSpacing.lg),
        children: <Widget>[
          SsCard(
            child: Column(
              children: <Widget>[
                SsListTile(
                  title: context.l10n.termsOfUseTitle,
                  leading: const Icon(Icons.description_outlined),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.terms),
                ),
                const Divider(),
                SsListTile(
                  title: context.l10n.privacyPolicyTitle,
                  leading: const Icon(Icons.privacy_tip_outlined),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.privacy),
                ),
                const Divider(),
                SsListTile(
                  title: context.l10n.responsibleUseTitle,
                  leading: const Icon(Icons.handshake_outlined),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.responsibleUse),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
