/// ALegal — the published policies (opened in the browser) and the
/// open-source licences (Flutter's licence page).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/app_config_provider.dart';
import '../../../core/external_links.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import 'account_parts.dart';
import 'account_providers.dart';

class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final AppConfig config = ref.watch(appConfigProvider);
    final List<(String, String, Uri)> documents = <(String, String, Uri)>[
      ('terms', l10n.termsOfUseTitle, config.termsOfUseUrl),
      ('privacy', l10n.privacyPolicyTitle, config.privacyPolicyUrl),
      ('acceptable-use', l10n.acAcceptableUse, config.acceptableUseUrl),
      ('copyright', l10n.acCopyrightPolicy, config.copyrightPolicyUrl),
      ('refund', l10n.acRefundPolicy, config.refundPolicyUrl),
    ];

    return SsV2Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsV2Header(
            onBack: () => accountBack(context),
            title: l10n.acLegalTitle,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: ssV2Gap(<Widget>[
                AccountSection(
                  children: <Widget>[
                    for (final (String id, String title, Uri url) in documents)
                      AccountRow(
                        key: ValueKey<String>('legal-$id'),
                        glyph: SsV2IconGlyph.document,
                        title: title,
                        subtitle: '${url.host}${url.path}',
                        trailing: SsV2Icon(
                          SsV2IconGlyph.globe,
                          size: 20,
                          color: palette.textMuted,
                        ),
                        onTap: () => openExternalUrl(url),
                      ),
                  ],
                ),
                AccountRow(
                  key: const ValueKey<String>('legal-licences'),
                  glyph: SsV2IconGlyph.document,
                  tone: AccountRowTone.neutral,
                  title: l10n.acOpenSourceLicences,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: l10n.appTitle,
                    applicationVersion: ref.read(appVersionProvider).value,
                    useRootNavigator: true,
                  ),
                ),
                SsV2Disclaimer(text: l10n.v2NotAffiliated),
              ], 14),
            ),
          ),
        ],
      ),
    );
  }
}
