import 'package:flutter/material.dart';

import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../account/presentation/account_parts.dart';

class SettingsChoice {
  const SettingsChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
}

/// A v2 page with one card of single-choice rows (Language, Theme).
class SettingsChoiceScreen extends StatelessWidget {
  const SettingsChoiceScreen({
    required this.title,
    required this.description,
    required this.choices,
    super.key,
  });

  final String title;
  final String description;
  final List<SettingsChoice> choices;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < choices.length; i++) {
      if (i > 0) rows.add(Container(height: 1, color: palette.divider));
      final SettingsChoice choice = choices[i];
      rows.add(
        Semantics(
          inMutuallyExclusiveGroup: true,
          checked: choice.selected,
          button: true,
          child: InkWell(
            onTap: choice.onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        choice.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (choice.selected)
                      SsV2Icon(
                        SsV2IconGlyph.check,
                        size: 22,
                        color: palette.link,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return SsV2Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsV2Header(onBack: () => accountBack(context), title: title),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: <Widget>[
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: palette.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: palette.divider),
                  ),
                  child: Column(children: rows),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
