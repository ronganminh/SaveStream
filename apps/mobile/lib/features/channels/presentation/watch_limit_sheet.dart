/// W13 — Free watch-limit sheet.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

Future<void> showWatchLimitSheet(
  BuildContext context, {
  required int count,
  required int limit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => SsBottomSheet(
      title: context.l10n.watchLimitTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(context.l10n.watchLimitBody),
          if (count > limit) ...<Widget>[
            const SizedBox(height: SsSpacing.md),
            SsInlineAlert(
              title: context.l10n.watchCapacityFull,
              message: context.l10n.watchCapacityLegacyExceeded(count),
              tone: SsInlineAlertTone.warning,
            ),
          ],
          const SizedBox(height: SsSpacing.lg),
          SsPrimaryButton(
            label: context.l10n.buyCloudHoursAction,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              context.push(AppRoutes.cloudHoursLocation('watchLimit'));
            },
          ),
          const SizedBox(height: SsSpacing.sm),
          SsSecondaryButton(
            label: context.l10n.manageWatchingAction,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    ),
  );
}
