/// APurchaseSuccess · APurchasePending. No ads on these screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../home/presentation/home_screen.dart' show formatRecordingMinutes;
import '../../store/presentation/a5_purchase_controller.dart';
import '../../store/presentation/a5_store_providers.dart';
import 'credits_v2_parts.dart';

CloudHoursOffer? _offer(WidgetRef ref, String? productId) {
  for (final CloudHoursOffer offer
      in ref.watch(cloudHoursOffersProvider).value ??
          const <CloudHoursOffer>[]) {
    if (offer.productId == productId) return offer;
  }
  return null;
}

class PurchaseSuccessScreen extends ConsumerWidget {
  const PurchaseSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final CloudHoursPurchaseState state = ref.watch(
      cloudHoursPurchaseControllerProvider,
    );
    final CloudHoursOffer? offer = _offer(ref, state.selectedProductId);
    final int minutes = state.minutesAdded > 0
        ? state.minutesAdded
        : (offer?.package.cloudMinutes ?? 0);
    final int hours = minutes ~/ 60;

    void done() {
      ref.read(cloudHoursPurchaseControllerProvider.notifier).acknowledge();
      creditsBack(context, fallback: AppRoutes.usage);
    }

    final List<(String, String, bool)> rows = <(String, String, bool)>[
      if (offer != null)
        (
          l10n.crSuccessPack,
          l10n.crPackLabel(offer.package.name, hours),
          false,
        ),
      if (offer != null) (l10n.crSuccessPrice, offer.localizedPrice, false),
      if (state.orderId != null && state.orderId!.startsWith('GPA.'))
        (l10n.crSuccessOrder, state.orderId!, false),
      if (state.balanceAfter != null)
        (
          l10n.crSuccessBalance,
          formatRecordingMinutes(l10n, state.balanceAfter!),
          true,
        ),
    ];

    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          ref.read(cloudHoursPurchaseControllerProvider.notifier).acknowledge();
        }
      },
      child: SsV2Page(
        child: SsV2StatusBody(
          glyph: SsV2IconGlyph.check,
          tone: SsV2TileTone.success,
          title: l10n.crSuccessTitle(hours),
          body: l10n.crSuccessBody,
          extra: rows.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SsV2Card(
                    child: Table(
                      columnWidths: const <int, TableColumnWidth>{
                        0: IntrinsicColumnWidth(),
                        1: FlexColumnWidth(),
                      },
                      children: <TableRow>[
                        for (int i = 0; i < rows.length; i++)
                          TableRow(
                            children: <Widget>[
                              Padding(
                                padding: EdgeInsets.only(
                                  right: 16,
                                  top: i == 0 ? 0 : 8,
                                ),
                                child: Text(
                                  rows[i].$1,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: palette.textMuted,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                                child: Text(
                                  rows[i].$2,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: rows[i].$3 ? palette.link : null,
                                    fontFeatures: const <FontFeature>[
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
          actions: <Widget>[SsV2Button(label: l10n.crDone, onPressed: done)],
        ),
      ),
    );
  }
}

class PurchasePendingScreen extends ConsumerWidget {
  const PurchasePendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final CloudHoursPurchaseState state = ref.watch(
      cloudHoursPurchaseControllerProvider,
    );
    final CloudHoursOffer? offer = _offer(ref, state.selectedProductId);

    void back() {
      ref.read(cloudHoursPurchaseControllerProvider.notifier).acknowledge();
      creditsBack(context, fallback: AppRoutes.usage);
    }

    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          ref.read(cloudHoursPurchaseControllerProvider.notifier).acknowledge();
        }
      },
      child: SsV2Page(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SsV2Header(onBack: back, title: l10n.crPurchaseTitle),
            Expanded(
              child: SsV2StatusBody(
                glyph: SsV2IconGlyph.clock,
                tone: SsV2TileTone.warning,
                title: l10n.crPendingTitle,
                body: offer == null
                    ? l10n.crPendingBodyGeneric
                    : l10n.crPendingBody(offer.package.name, offer.hours),
                extra: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: SsV2Spinner(),
                ),
                actions: <Widget>[
                  SsV2Button(label: l10n.crBackToCredits, onPressed: back),
                  SsV2Button(
                    label: l10n.crViewInPlay,
                    variant: SsV2ButtonVariant.text,
                    onPressed: () =>
                        openExternalUrl(AppConfig.googlePlayOrderHistoryUrl),
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
