/// S11 — Help.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> questions = <String>[
      context.l10n.helpLocalCloudQuestion,
      context.l10n.helpBackgroundQuestion,
      context.l10n.helpFreeMinutesQuestion,
      context.l10n.helpCloudHoursQuestion,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.helpTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SsSpacing.lg),
        children: <Widget>[
          SsCard(
            child: Column(
              children: <Widget>[
                for (
                  int index = 0;
                  index < questions.length;
                  index += 1
                ) ...<Widget>[
                  SsListTile(
                    title: questions[index],
                    leading: const Icon(Icons.help_outline_rounded),
                  ),
                  if (index != questions.length - 1) const Divider(),
                ],
              ],
            ),
          ),
          const SizedBox(height: SsSpacing.lg),
          SsPrimaryButton(
            label: context.l10n.reportIssueTitle,
            icon: Icons.bug_report_outlined,
            onPressed: () => context.push(AppRoutes.reportIssue),
          ),
        ],
      ),
    );
  }
}
