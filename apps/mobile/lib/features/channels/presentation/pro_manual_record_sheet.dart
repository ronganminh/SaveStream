import 'package:flutter/material.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';

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

class ProManualRecordSheet extends StatefulWidget {
  const ProManualRecordSheet({
    required this.creatorName,
    required this.entitlement,
    super.key,
  });

  final String creatorName;
  final Entitlement entitlement;

  @override
  State<ProManualRecordSheet> createState() => _ProManualRecordSheetState();
}

class _ProManualRecordSheetState extends State<ProManualRecordSheet> {
  late Engine _selection;

  bool get _localEnabled => widget.entitlement.local.enabled;

  bool get _cloudEnabled => widget.entitlement.cloudMinutesAvailable > 0;

  @override
  void initState() {
    super.initState();
    _selection = _localEnabled ? Engine.local : Engine.cloud;
  }

  @override
  Widget build(BuildContext context) {
    final Entitlement entitlement = widget.entitlement;
    final String cloudRemaining = formatMinutesAsHoursMinutes(
      entitlement.cloudMinutesAvailable,
      hoursLabel: context.l10n.timeHoursUnit,
      minutesLabel: context.l10n.timeMinutesUnit,
    );

    return SsBottomSheet(
      title: context.l10n.proManualRecordTitle(widget.creatorName),
      child: RadioGroup<Engine>(
        groupValue: _selection,
        onChanged: (Engine? value) {
          if (value == null) return;
          if (value == Engine.local && !_localEnabled) return;
          if (value == Engine.cloud && !_cloudEnabled) return;
          setState(() => _selection = value);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            RadioListTile<Engine>(
              value: Engine.local,
              enabled: _localEnabled,
              secondary: const Icon(Icons.smartphone_rounded),
              title: Text(context.l10n.proManualRecordLocalTitle),
              subtitle: Text(
                _localEnabled
                    ? entitlement.local.unlimited
                          ? context.l10n.proManualRecordLocalUnlimitedBody
                          : context.l10n.proManualRecordLocalMeteredBody
                    : context.l10n.proManualRecordLocalDisabledBody,
              ),
            ),
            const Divider(),
            RadioListTile<Engine>(
              value: Engine.cloud,
              enabled: _cloudEnabled,
              secondary: const Icon(Icons.cloud_outlined),
              title: Text(context.l10n.proManualRecordCloudTitle),
              subtitle: Text(
                _cloudEnabled
                    ? context.l10n.proManualRecordCloudBody(cloudRemaining)
                    : context.l10n.proManualRecordCloudEmptyBody,
              ),
            ),
            const SizedBox(height: SsSpacing.lg),
            SsPrimaryButton(
              label: _selection == Engine.local
                  ? context.l10n.proManualRecordLocalAction
                  : context.l10n.proManualRecordCloudAction,
              icon: _selection == Engine.local
                  ? Icons.smartphone_rounded
                  : Icons.cloud_outlined,
              onPressed:
                  (_selection == Engine.local && _localEnabled) ||
                      (_selection == Engine.cloud && _cloudEnabled)
                  ? () => Navigator.of(context).pop(_selection)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
