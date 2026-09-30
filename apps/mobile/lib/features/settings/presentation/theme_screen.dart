import 'package:flutter/material.dart';

import '../../../app/app_settings_controller.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({required this.settings, super.key});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.themeLabel)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SsSpacing.lg),
          children: <Widget>[
            Text(
              l10n.themeDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SsSpacing.lg),
            SsCard(
              child: Column(
                children: <Widget>[
                  _ThemeOption(
                    icon: Icons.settings_suggest_outlined,
                    label: l10n.themeSystem,
                    selected: settings.themeMode == ThemeMode.system,
                    onTap: () => settings.setThemeMode(ThemeMode.system),
                  ),
                  const Divider(),
                  _ThemeOption(
                    icon: Icons.light_mode_outlined,
                    label: l10n.themeLight,
                    selected: settings.themeMode == ThemeMode.light,
                    onTap: () => settings.setThemeMode(ThemeMode.light),
                  ),
                  const Divider(),
                  _ThemeOption(
                    icon: Icons.dark_mode_outlined,
                    label: l10n.themeDark,
                    selected: settings.themeMode == ThemeMode.dark,
                    onTap: () => settings.setThemeMode(ThemeMode.dark),
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

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
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
