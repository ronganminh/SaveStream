/// AHelp — help articles (opened on savestream.online/help in the browser),
/// filtered locally by the search field, and the support email.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/app_config_provider.dart';
import '../../../core/external_links.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import 'account_parts.dart';

/// An article of the web help center (apps/web/src/content/help/<slug>.md).
class HelpArticle {
  const HelpArticle({
    required this.slug,
    required this.glyph,
    required this.title,
    required this.summary,
  });

  final String slug;
  final SsV2IconGlyph glyph;
  final String title;
  final String summary;
}

List<HelpArticle> helpArticles(AppLocalizations l10n) => <HelpArticle>[
  HelpArticle(
    slug: 'add-a-channel',
    glyph: SsV2IconGlyph.channels,
    title: l10n.acHelpChannelTitle,
    summary: l10n.acHelpChannelBody,
  ),
  HelpArticle(
    slug: 'automatic-recording',
    glyph: SsV2IconGlyph.cloud,
    title: l10n.acHelpCloudTitle,
    summary: l10n.acHelpCloudBody,
  ),
  HelpArticle(
    slug: 'credits-and-pricing',
    glyph: SsV2IconGlyph.clock,
    title: l10n.acHelpBillingTitle,
    summary: l10n.acHelpBillingBody,
  ),
  HelpArticle(
    slug: 'storage-and-downloads',
    glyph: SsV2IconGlyph.download,
    title: l10n.acHelpSavingTitle,
    summary: l10n.acHelpSavingBody,
  ),
  HelpArticle(
    slug: 'recording-failed',
    glyph: SsV2IconGlyph.alert,
    title: l10n.acHelpFailedTitle,
    summary: l10n.acHelpFailedBody,
  ),
];

/// Articles whose title or summary contains every word of [query].
List<HelpArticle> filterHelpArticles(List<HelpArticle> all, String query) {
  final List<String> words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return all;
  return all.where((HelpArticle article) {
    final String text = '${article.title} ${article.summary}'.toLowerCase();
    return words.every(text.contains);
  }).toList();
}

class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final AppConfig config = ref.watch(appConfigProvider);
    final List<HelpArticle> articles = filterHelpArticles(
      helpArticles(l10n),
      _search.text,
    );

    return SsV2Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsV2Header(
            onBack: () => accountBack(context),
            title: l10n.acHelpTitle,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: ssV2Gap(<Widget>[
                SsV2TextField(
                  fieldKey: const ValueKey<String>('help-search'),
                  label: l10n.acSearchHelp,
                  hintText: l10n.acSearchHelpHint,
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  suffix: SizedBox.square(
                    dimension: 48,
                    child: Center(
                      child: SsV2Icon(
                        SsV2IconGlyph.search,
                        size: 22,
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                ),
                if (articles.isEmpty)
                  Text(
                    l10n.acHelpNoResults(_search.text.trim()),
                    key: const ValueKey<String>('help-no-results'),
                    style: TextStyle(fontSize: 15, color: palette.textMuted),
                  )
                else
                  AccountSection(
                    children: <Widget>[
                      for (final HelpArticle article in articles)
                        AccountRow(
                          key: ValueKey<String>('help-${article.slug}'),
                          glyph: article.glyph,
                          title: article.title,
                          subtitle: article.summary,
                          onTap: () => openExternalUrl(
                            config.helpArticleUrl(article.slug),
                          ),
                        ),
                    ],
                  ),
                SsV2Card(
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    key: const ValueKey<String>('help-email'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => openMail(AppConfig.supportEmail),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: palette.tint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SsV2Icon(
                              SsV2IconGlyph.mail,
                              size: 20,
                              color: palette.link,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  l10n.acStillNeedHelp,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppConfig.supportEmail,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: palette.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Text(
                  l10n.acHelpFooter,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: palette.textMuted,
                  ),
                ),
              ], 14),
            ),
          ),
        ],
      ),
    );
  }
}
