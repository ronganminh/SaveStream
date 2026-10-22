/// AUsageHistory: minutes recorded per day (last 14 days) and the ledger.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../home/presentation/home_screen.dart' show formatRecordingMinutes;
import '../../recordings/domain/models/recording_summary.dart';
import '../../store/domain/models/store_models.dart';
import '../../store/presentation/a5_store_providers.dart';
import '../domain/credit_ledger.dart';
import 'credits_providers.dart';
import 'credits_v2_parts.dart';

class UsageHistoryScreen extends ConsumerWidget {
  const UsageHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<CreditTransaction>> ledger = ref.watch(
      creditTransactionsProvider,
    );
    return SsV2Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsV2Header(
            onBack: () => creditsBack(context),
            title: l10n.crHistoryTitle,
          ),
          Expanded(
            child: ledger.when(
              skipLoadingOnRefresh: true,
              loading: () => const Center(child: SsV2Spinner()),
              error: (Object error, StackTrace stackTrace) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SsV2Banner(
                    tone: SsV2Tone.error,
                    actions: <Widget>[
                      SsV2Button(
                        label: l10n.crRetry,
                        size: SsV2ButtonSize.small,
                        variant: SsV2ButtonVariant.outlined,
                        expand: false,
                        onPressed: () =>
                            ref.invalidate(creditTransactionsProvider),
                      ),
                    ],
                    child: Text(l10n.crHistoryError),
                  ),
                ),
              ),
              data: (List<CreditTransaction> items) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(creditTransactionsProvider);
                  await ref.read(creditTransactionsProvider.future);
                },
                child: _HistoryBody(items: items),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A ledger entry as Usage history lists it.
class LedgerLine {
  const LedgerLine({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.positive,
  });

  final String title;
  final String subtitle;
  final String amount;
  final bool positive;
}

class _HistoryBody extends ConsumerWidget {
  const _HistoryBody({required this.items});

  final List<CreditTransaction> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final DateTime now = ref.watch(creditsClockProvider)();
    final Map<String, RecordingSummary> recordings =
        ref.watch(ledgerRecordingsProvider).value ??
        const <String, RecordingSummary>{};
    final Map<String, PaymentOrder> orders = <String, PaymentOrder>{
      for (final PaymentOrder order
          in ref.watch(playPurchasesProvider).value ?? const <PaymentOrder>[])
        order.id: order,
    };
    final Map<String, String> packNames = <String, String>{
      for (final StorePackage package
          in ref.watch(storePackagesProvider).value ?? const <StorePackage>[])
        package.id: package.name,
    };

    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime first = today.subtract(
      const Duration(days: usageHistoryDays - 1),
    );
    final List<int> perDay = List<int>.filled(usageHistoryDays, 0);
    final Set<String> charged = <String>{};
    for (final CreditTransaction item in items) {
      if (item.type == CreditTransactionType.charge &&
          item.referenceType == 'recording') {
        if (item.referenceId != null) charged.add(item.referenceId!);
        final DateTime local = item.createdAt.toLocal();
        final int day = DateTime(
          local.year,
          local.month,
          local.day,
        ).difference(first).inDays;
        if (day >= 0 && day < usageHistoryDays) perDay[day] += -item.amount;
      }
    }
    final int total = perDay.fold(0, (int sum, int value) => sum + value);

    final List<LedgerLine> lines = <LedgerLine>[];
    for (final CreditTransaction item in items) {
      final LedgerLine? line = _line(
        context,
        item,
        recordings: recordings,
        orders: orders,
        packNames: packNames,
        charged: charged,
      );
      if (line != null) lines.add(line);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: <Widget>[
        SsV2Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: ssV2Gap(<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.crHistoryWindow(usageHistoryDays),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    formatRecordingMinutes(l10n, total),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Semantics(
                label: l10n.crHistoryChartLabel(
                  usageHistoryDays,
                  formatRecordingMinutes(l10n, total),
                ),
                child: ExcludeSemantics(child: _Bars(perDay: perDay)),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      creditsShortDate(context, first),
                      style: TextStyle(fontSize: 12, color: palette.textMuted),
                    ),
                  ),
                  Text(
                    creditsShortDate(context, today),
                    style: TextStyle(fontSize: 12, color: palette.textMuted),
                  ),
                ],
              ),
            ], 12),
          ),
        ),
        const SizedBox(height: 14),
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n.crHistoryEmpty(usageHistoryDays),
              style: TextStyle(fontSize: 14, color: palette.textMuted),
            ),
          ),
        for (final LedgerLine line in lines)
          CreditsListRow(
            title: line.title,
            subtitle: line.subtitle,
            trailing: line.amount,
            trailingColor: line.positive ? palette.success : null,
          ),
      ],
    );
  }

  LedgerLine? _line(
    BuildContext context,
    CreditTransaction item, {
    required Map<String, RecordingSummary> recordings,
    required Map<String, PaymentOrder> orders,
    required Map<String, String> packNames,
    required Set<String> charged,
  }) {
    final AppLocalizations l10n = context.l10n;
    final String date = creditsShortDate(context, item.createdAt);
    final String amount = formatLedgerAmount(l10n, item.amount);
    final bool positive = item.amount > 0;
    final RecordingSummary? recording = item.referenceId == null
        ? null
        : recordings[item.referenceId!];

    switch (item.type) {
      case CreditTransactionType.charge:
        final String details =
            recording != null && recording.durationSeconds > 0
            ? '$date · ${_duration(l10n, recording.durationSeconds)}'
            : date;
        return LedgerLine(
          title: recording != null && recording.creatorUsername.isNotEmpty
              ? l10n.crLedgerRecordingChannel(recording.creatorUsername)
              : l10n.crLedgerRecording,
          subtitle: l10n.crLedgerBilled(details),
          amount: amount,
          positive: false,
        );
      case CreditTransactionType.release:
        // Hold bookkeeping: shown only when the recording was never charged
        // (it failed and the held minutes went back).
        if (item.referenceId != null && charged.contains(item.referenceId)) {
          return null;
        }
        return LedgerLine(
          title: l10n.crLedgerRefunded,
          subtitle: l10n.crLedgerNotCharged(date),
          amount: formatLedgerAmount(l10n, 0),
          positive: false,
        );
      case CreditTransactionType.grant:
      case CreditTransactionType.adjustment:
      case CreditTransactionType.refund:
        final String title;
        String subtitle = date;
        switch (item.referenceType) {
          case 'reward':
            title = l10n.crLedgerReward;
          case 'signup_bonus':
            title = l10n.crLedgerTrial;
            subtitle = l10n.crLedgerAfterVerify(date);
          case 'promotion':
            title = l10n.crLedgerPromo;
          case 'payment_order':
            final PaymentOrder? order = item.referenceId == null
                ? null
                : orders[item.referenceId!];
            final String? name = order == null
                ? null
                : packNames[order.packageId];
            title = name != null
                ? l10n.crLedgerPack(name)
                : l10n.crLedgerPurchase;
          case 'refund':
          case 'store_refund':
          case 'store_refund_debt':
          case 'refund_compensation':
            title = l10n.crLedgerRefund;
          default:
            title = l10n.crLedgerAdjustment;
        }
        return LedgerLine(
          title: title,
          subtitle: subtitle,
          amount: amount,
          positive: positive,
        );
    }
  }

  static String _duration(AppLocalizations l10n, int seconds) {
    final int minutes = seconds ~/ 60;
    final int rest = seconds % 60;
    if (minutes >= 60) return formatRecordingMinutes(l10n, minutes);
    return rest == 0
        ? l10n.v2DurationMinutes(minutes)
        : l10n.crDurationMinutesSeconds(minutes, rest);
  }
}

/// "+5 min", "−99 min", "+150 h" (whole hours), "0 min".
String formatLedgerAmount(AppLocalizations l10n, int amount) {
  final String sign = amount > 0 ? '+' : (amount < 0 ? '−' : '');
  final int value = amount.abs();
  if (value >= 60 && value % 60 == 0)
    return l10n.crAmountHours(sign, value ~/ 60);
  return l10n.crAmountMinutes(sign, value);
}

class _Bars extends StatelessWidget {
  const _Bars({required this.perDay});

  final List<int> perDay;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final int peak = perDay.fold(0, math.max);
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < perDay.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: FractionallySizedBox(
                heightFactor: peak == 0 ? 0 : perDay[i] / peak,
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: perDay[i] > 0 ? palette.primary : palette.divider,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
