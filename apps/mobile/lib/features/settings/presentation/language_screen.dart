import 'package:flutter/material.dart';

import '../../../app/app_settings_controller.dart';
import '../../../l10n/l10n.dart';
import 'settings_choice_list.dart';

/// Language (Account → App): follow the system, English or Vietnamese.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({required this.settings, super.key});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (BuildContext context, Widget? child) {
        final AppLocalizations l10n = context.l10n;
        final bool system = settings.useSystemLocale;
        final String code = settings.locale.languageCode;
        return SettingsChoiceScreen(
          title: l10n.languageTitle,
          description: l10n.languageDescription,
          choices: <SettingsChoice>[
            SettingsChoice(
              label: l10n.languageSystem,
              selected: system,
              onTap: settings.setSystemLocale,
            ),
            SettingsChoice(
              label: l10n.languageEnglish,
              selected: !system && code == 'en',
              onTap: () => settings.setLocale(const Locale('en')),
            ),
            SettingsChoice(
              label: l10n.languageVietnamese,
              selected: !system && code == 'vi',
              onTap: () => settings.setLocale(const Locale('vi')),
            ),
          ],
        );
      },
    );
  }
}
