import 'package:flutter/material.dart';

import '../../../app/app_settings_controller.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({required this.settings, super.key});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SsSpacing.lg),
          children: <Widget>[
            Text(
              l10n.languageDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SsSpacing.lg),
            SsCard(
              child: Column(
                children: <Widget>[
                  _LanguageOption(
                    label: l10n.languageEnglish,
                    selected: settings.locale.languageCode == 'en',
                    onTap: () => settings.setLocale(const Locale('en')),
                  ),
                  const Divider(),
                  _LanguageOption(
                    label: l10n.languageVietnamese,
                    selected: settings.locale.languageCode == 'vi',
                    onTap: () => settings.setLocale(const Locale('vi')),
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

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: selected
          ? Icon(
              Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.circle_outlined),
      onTap: onTap,
    );
  }
}
