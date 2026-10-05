/// S14 — Responsible use.
import 'package:flutter/material.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

class ResponsibleUseScreen extends StatelessWidget {
  const ResponsibleUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.responsibleUseTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SsSpacing.lg),
        children: <Widget>[
          SsInlineAlert(
            title: context.l10n.responsibleUseLead,
            message: context.l10n.responsibleUseBody,
          ),
          const SizedBox(height: SsSpacing.lg),
          SsChecklist(
            items: <SsChecklistItem>[
              SsChecklistItem(label: context.l10n.responsibleUseOwnContent),
              SsChecklistItem(label: context.l10n.responsibleUseNoRedistribute),
              SsChecklistItem(label: context.l10n.responsibleUseEnforcement),
            ],
          ),
        ],
      ),
    );
  }
}
