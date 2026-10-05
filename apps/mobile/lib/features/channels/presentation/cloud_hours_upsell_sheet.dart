/// W14 — Cloud hours upsell for auto-record.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

Future<void> showCloudHoursUpsellSheet(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => SsBottomSheet(
      title: l10n.cloudHoursUpsellTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.cloudHoursUpsellBody),
          const SizedBox(height: SsSpacing.lg),
          for (final String benefit in <String>[
            l10n.cloudHoursBenefitAuto,
            l10n.cloudHoursBenefitPhone,
            l10n.cloudHoursBenefitCreators,
            l10n.cloudHoursBenefitNoAds,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: SsSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.check_rounded, size: 18),
                  const SizedBox(width: SsSpacing.sm),
                  Expanded(child: Text(benefit)),
                ],
              ),
            ),
          const SizedBox(height: SsSpacing.md),
          SsPrimaryButton(
            label: l10n.buyCloudHoursAction,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              context.push(AppRoutes.cloudHoursLocation('autoRecord'));
            },
          ),
        ],
      ),
    ),
  );
}
