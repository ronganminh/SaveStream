import 'package:flutter/material.dart';

import '../../../app/app_settings_controller.dart';
import '../../../l10n/l10n.dart';
import 'settings_choice_list.dart';

/// Theme (Account → App): System, Light or Dark, stored on the device.
class ThemeScreen extends StatelessWidget {
  const ThemeScreen({required this.settings, super.key});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (BuildContext context, Widget? child) {
        final AppLocalizations l10n = context.l10n;
        return SettingsChoiceScreen(
          title: l10n.themeLabel,
          description: l10n.themeDescription,
          choices: <SettingsChoice>[
            SettingsChoice(
              label: l10n.themeSystem,
              selected: settings.themeMode == ThemeMode.system,
              onTap: () => settings.setThemeMode(ThemeMode.system),
            ),
            SettingsChoice(
              label: l10n.themeLight,
              selected: settings.themeMode == ThemeMode.light,
              onTap: () => settings.setThemeMode(ThemeMode.light),
            ),
            SettingsChoice(
              label: l10n.themeDark,
              selected: settings.themeMode == ThemeMode.dark,
              onTap: () => settings.setThemeMode(ThemeMode.dark),
            ),
          ],
        );
      },
    );
  }
}
