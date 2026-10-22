import 'package:flutter/material.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';

/// Confirms a manual cloud recording. Returns [Engine.cloud] when confirmed.
Future<Engine?> showProManualRecordSheet({
  required BuildContext context,
  required String creatorName,
  required Entitlement entitlement,
}) {
  return showModalBottomSheet<Engine>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return ProManualRecordSheet(
        creatorName: creatorName,
        entitlement: entitlement,
      );
    },
  );
}

class ProManualRecordSheet extends StatelessWidget {
  const ProManualRecordSheet({
    required this.creatorName,
    required this.entitlement,
    super.key,
  });

  final String creatorName;
  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final bool cloudEnabled = entitlement.cloudMinutesAvailable > 0;
    final String cloudRemaining = formatMinutesAsHoursMinutes(
      entitlement.cloudMinutesAvailable,
      hoursLabel: context.l10n.timeHoursUnit,
      minutesLabel: context.l10n.timeMinutesUnit,
    );

    return SsBottomSheet(
      title: context.l10n.proManualRecordTitle(creatorName),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_outlined),
            title: Text(context.l10n.proManualRecordCloudTitle),
            subtitle: Text(
              cloudEnabled
                  ? context.l10n.proManualRecordCloudBody(cloudRemaining)
                  : context.l10n.proManualRecordCloudEmptyBody,
            ),
          ),
          const SizedBox(height: SsSpacing.lg),
          SsPrimaryButton(
            label: context.l10n.proManualRecordCloudAction,
            icon: Icons.cloud_outlined,
            onPressed: cloudEnabled
                ? () => Navigator.of(context).pop(Engine.cloud)
                : null,
          ),
        ],
      ),
    );
  }
}
