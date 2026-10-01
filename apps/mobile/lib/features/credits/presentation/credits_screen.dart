import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/credit_models.dart';
import 'controllers/credits_providers.dart';

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<CreditsOverview> overview = ref.watch(
      creditsOverviewProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.creditsTitle)),
      body: SafeArea(
        child: SsAsyncRefreshFrame(
          isRefreshing: overview.isRefreshing,
          child: overview.when(
            loading: () => const _CreditsSkeleton(),
            error: (Object error, StackTrace stackTrace) => Center(
              child: SsAsyncErrorState(
                error: error,
                onRetry: () => ref.invalidate(creditsOverviewProvider),
              ),
            ),
          data: (CreditsOverview data) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(creditsOverviewProvider);
              await ref.read(creditsOverviewProvider.future);
            },
            child: _CreditsBody(data: data),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreditsBody extends StatelessWidget {
  const _CreditsBody({required this.data});

  final CreditsOverview data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        SsSpacing.lg,
        SsSpacing.md,
        SsSpacing.lg,
        SsSpacing.xxl,
      ),
      children: <Widget>[
        _BalanceCard(data: data),
        if (data.isLowCredit) ...<Widget>[
          const SizedBox(height: SsSpacing.md),
          SsCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: SsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.creditsLowBalanceTitle,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: SsSpacing.xs),
                      Text(l10n.creditsLowBalanceBody),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: SsSpacing.lg),
        SsPrimaryButton(
          label: l10n.buyCreditsAction,
          icon: Icons.add_card_rounded,
          onPressed: () => context.push(AppRoutes.billing),
        ),
        const SizedBox(height: SsSpacing.xl),
        _ReservationCard(data: data),
        const SizedBox(height: SsSpacing.md),
        _PricingCard(pricing: data.pricing),
        const SizedBox(height: SsSpacing.xl),
        Text(
          l10n.creditsRecentTransactionsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: SsSpacing.sm),
        if (data.transactions.isEmpty)
          SsCard(
            child: SsEmptyState(
              icon: Icons.receipt_long_outlined,
              title: l10n.creditsNoTransactionsTitle,
              message: l10n.creditsNoTransactionsBody,
            ),
          )
        else
          ...data.transactions
              .take(20)
              .map(
                (CreditTransaction transaction) => Padding(
                  padding: const EdgeInsets.only(bottom: SsSpacing.sm),
                  child: _TransactionCard(transaction: transaction),
                ),
              ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.data});

  final CreditsOverview data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.creditsAvailableBalanceLabel,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: SsSpacing.xs),
          Text(
            data.balance.available.toString(),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: SsSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _BalanceMetric(
                  label: l10n.creditsPostedBalanceLabel,
                  value: data.balance.posted.toString(),
                ),
              ),
              const SizedBox(width: SsSpacing.md),
              Expanded(
                child: _BalanceMetric(
                  label: l10n.creditsReservedBalanceLabel,
                  value: data.balance.reserved.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: SsSpacing.md),
          Text(
            l10n.creditsReservedExplanation,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _BalanceMetric extends StatelessWidget {
  const _BalanceMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(SsSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(SsRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SsSpacing.xs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.data});

  final CreditsOverview data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.creditsReservationsTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsSpacing.md),
          _MetricRow(
            label: l10n.creditsActiveReservationsLabel,
            value: data.activeReservationCount.toString(),
          ),
          _MetricRow(
            label: l10n.creditsReservedBalanceLabel,
            value: data.balance.reserved.toString(),
          ),
          if (data.reservations.isNotEmpty) ...<Widget>[
            const SizedBox(height: SsSpacing.sm),
            Text(
              l10n.creditsLatestReservation(
                data.reservations.first.recordingId,
                data.reservations.first.status.apiValue,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.pricing});

  final PricingSnapshot? pricing;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PricingSnapshot? value = pricing;
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.creditsPricingTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsSpacing.sm),
          if (value == null)
            Text(l10n.creditsPricingUnavailableBody)
          else ...<Widget>[
            _MetricRow(
              label: l10n.creditsPricingVersionLabel,
              value: value.version,
            ),
            _MetricRow(
              label: l10n.creditsPricingRulesLabel,
              value: value.rules.length.toString(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SsSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});

  final CreditTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String title = transaction.recordingId != null
        ? l10n.creditsRecordingChargeLabel
        : transaction.isCredit
        ? l10n.creditsAddedLabel
        : l10n.creditsTransactionLabel;
    final String amount =
        '${transaction.isCredit ? '+' : ''}${transaction.amount}';

    return SsCard(
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: transaction.isCredit
                ? colors.primaryContainer
                : colors.surfaceContainerHighest,
            child: Icon(
              transaction.isCredit ? Icons.add_rounded : Icons.remove_rounded,
              color: transaction.isCredit
                  ? colors.onPrimaryContainer
                  : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: SsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: SsSpacing.xs),
                Text(
                  _formatTimestamp(context, transaction.occurredAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (transaction.referenceId != null)
                  Text(
                    transaction.referenceId!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Text(
                  l10n.creditsBalanceAfter(transaction.balanceAfter),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: transaction.isCredit ? colors.primary : colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditsSkeleton extends StatelessWidget {
  const _CreditsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(height: 220, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 52, radius: SsRadii.md),
        SizedBox(height: SsSpacing.xl),
        SsSkeleton(height: 150, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 120, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.xl),
        SsSkeleton(height: 92, radius: SsRadii.lg),
      ],
    );
  }
}

String _formatTimestamp(BuildContext context, DateTime value) {
  final MaterialLocalizations material = MaterialLocalizations.of(context);
  final DateTime local = value.toLocal();
  return '${material.formatMediumDate(local)} · ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
