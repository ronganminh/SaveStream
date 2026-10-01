import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/mock/mock_repository_base.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/billing_models.dart';
import 'controllers/billing_providers.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  PaymentOrder? _activeOrder;
  bool _isMutating = false;
  Object? _mutationError;

  Future<void> _buy(CreditPackage package) async {
    await _runMutation(() async {
      _activeOrder = await ref
          .read(billingControllerProvider)
          .createOrder(package.id);
    });
  }

  Future<void> _refreshOrder() async {
    final PaymentOrder? active = _activeOrder;
    if (active == null) {
      return;
    }
    await _runMutation(() async {
      _activeOrder = await ref
          .read(billingControllerProvider)
          .refreshOrder(active.id);
    });
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    setState(() {
      _isMutating = true;
      _mutationError = null;
    });
    try {
      await action();
    } on Object catch (error) {
      _mutationError = error;
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<BillingSnapshot> snapshot = ref.watch(
      billingSnapshotProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.billingTitle)),
      body: SafeArea(
        child: snapshot.when(
          loading: () => const _BillingSkeleton(),
          error: (Object error, StackTrace stackTrace) => Center(
            child: SsErrorState(
              title: _errorTitle(l10n, error),
              message: _errorMessage(l10n, error),
              retryLabel: l10n.retryAction,
              onRetry: () => ref.invalidate(billingSnapshotProvider),
            ),
          ),
          data: (BillingSnapshot data) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(billingSnapshotProvider);
              await ref.read(billingSnapshotProvider.future);
            },
            child: _BillingBody(
              data: data,
              activeOrder: _activeOrder,
              isMutating: _isMutating,
              mutationError: _mutationError,
              onBuy: _buy,
              onRefreshOrder: _refreshOrder,
            ),
          ),
        ),
      ),
    );
  }
}

class _BillingBody extends StatelessWidget {
  const _BillingBody({
    required this.data,
    required this.activeOrder,
    required this.isMutating,
    required this.mutationError,
    required this.onBuy,
    required this.onRefreshOrder,
  });

  final BillingSnapshot data;
  final PaymentOrder? activeOrder;
  final bool isMutating;
  final Object? mutationError;
  final Future<void> Function(CreditPackage package) onBuy;
  final Future<void> Function() onRefreshOrder;

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
        Text(
          l10n.billingChoosePackageTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: SsSpacing.xs),
        Text(l10n.billingChoosePackageBody),
        const SizedBox(height: SsSpacing.lg),
        if (data.packages.isEmpty)
          SsCard(
            child: SsEmptyState(
              icon: Icons.add_card_rounded,
              title: l10n.billingNoPackagesTitle,
              message: l10n.billingNoPackagesBody,
            ),
          )
        else
          ...data.packages.map(
            (CreditPackage package) => Padding(
              padding: const EdgeInsets.only(bottom: SsSpacing.md),
              child: _PackageCard(
                package: package,
                isMutating: isMutating,
                onBuy: () => onBuy(package),
              ),
            ),
          ),
        if (activeOrder != null) ...<Widget>[
          const SizedBox(height: SsSpacing.md),
          _CheckoutStatusCard(
            order: activeOrder!,
            isMutating: isMutating,
            onRefresh: onRefreshOrder,
          ),
        ],
        if (mutationError != null) ...<Widget>[
          const SizedBox(height: SsSpacing.md),
          SsErrorState(
            title: _errorTitle(l10n, mutationError!),
            message: _errorMessage(l10n, mutationError!),
            retryLabel: l10n.retryAction,
            onRetry: () {},
          ),
        ],
        const SizedBox(height: SsSpacing.xl),
        Text(
          l10n.billingRecentOrdersTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: SsSpacing.sm),
        if (data.orders.isEmpty)
          SsCard(
            child: SsEmptyState(
              icon: Icons.receipt_long_outlined,
              title: l10n.billingNoOrdersTitle,
              message: l10n.billingNoOrdersBody,
            ),
          )
        else
          ...data.orders.map(
            (PaymentOrder order) => Padding(
              padding: const EdgeInsets.only(bottom: SsSpacing.sm),
              child: _OrderCard(order: order),
            ),
          ),
      ],
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.isMutating,
    required this.onBuy,
  });

  final CreditPackage package;
  final bool isMutating;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.billingPackageCredits(
                    package.credits.toStringAsFixed(0),
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (package.recommended)
                SsStatusChip(
                  label: l10n.billingRecommendedLabel,
                  tone: SsStatusTone.success,
                ),
            ],
          ),
          const SizedBox(height: SsSpacing.xs),
          Text(
            '${package.currency} ${package.price.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: SsSpacing.md),
          Text(l10n.billingPackageDetailBody),
          const SizedBox(height: SsSpacing.md),
          SsPrimaryButton(
            label: l10n.billingBuyAction,
            icon: Icons.shopping_cart_checkout_rounded,
            isLoading: isMutating,
            onPressed: onBuy,
          ),
        ],
      ),
    );
  }
}

class _CheckoutStatusCard extends StatelessWidget {
  const _CheckoutStatusCard({
    required this.order,
    required this.isMutating,
    required this.onRefresh,
  });

  final PaymentOrder order;
  final bool isMutating;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.billingCheckoutStatusTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SsStatusChip(
                label: _statusLabel(l10n, order.status),
                tone: _statusTone(order.status),
              ),
            ],
          ),
          const SizedBox(height: SsSpacing.md),
          Text(_statusBody(l10n, order.status)),
          if (order.status == PaymentOrderStatus.pending) ...<Widget>[
            const SizedBox(height: SsSpacing.md),
            SsSecondaryButton(
              label: l10n.billingCheckStatusAction,
              icon: Icons.refresh_rounded,
              onPressed: isMutating ? null : onRefresh,
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final PaymentOrder order;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final DateTime local = order.createdAt.toLocal();

    return SsCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.billingPackageCredits(
                    order.package.credits.toStringAsFixed(0),
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: SsSpacing.xs),
                Text(
                  '${material.formatMediumDate(local)} · ${order.id}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SsStatusChip(
            label: _statusLabel(l10n, order.status),
            tone: _statusTone(order.status),
          ),
        ],
      ),
    );
  }
}

class _BillingSkeleton extends StatelessWidget {
  const _BillingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(width: 220, height: 30),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 190, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 190, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 190, radius: SsRadii.lg),
      ],
    );
  }
}

String _statusLabel(AppLocalizations l10n, PaymentOrderStatus status) {
  return switch (status) {
    PaymentOrderStatus.pending => l10n.paymentStatusPending,
    PaymentOrderStatus.paid => l10n.paymentStatusPaid,
    PaymentOrderStatus.failed => l10n.paymentStatusFailed,
    PaymentOrderStatus.cancelled => l10n.paymentStatusCancelled,
    PaymentOrderStatus.expired => l10n.paymentStatusExpired,
  };
}

String _statusBody(AppLocalizations l10n, PaymentOrderStatus status) {
  return switch (status) {
    PaymentOrderStatus.pending => l10n.paymentPendingBody,
    PaymentOrderStatus.paid => l10n.paymentPaidBody,
    PaymentOrderStatus.failed => l10n.paymentFailedBody,
    PaymentOrderStatus.cancelled => l10n.paymentCancelledBody,
    PaymentOrderStatus.expired => l10n.paymentExpiredBody,
  };
}

SsStatusTone _statusTone(PaymentOrderStatus status) {
  return switch (status) {
    PaymentOrderStatus.pending => SsStatusTone.warning,
    PaymentOrderStatus.paid => SsStatusTone.success,
    PaymentOrderStatus.failed => SsStatusTone.error,
    PaymentOrderStatus.cancelled => SsStatusTone.neutral,
    PaymentOrderStatus.expired => SsStatusTone.neutral,
  };
}

String _errorTitle(AppLocalizations l10n, Object error) {
  if (error is MockRepositoryException &&
      error.kind == MockFailureKind.offlineLike) {
    return l10n.offlineErrorTitle;
  }
  return l10n.errorTitle;
}

String _errorMessage(AppLocalizations l10n, Object error) {
  if (error is MockRepositoryException &&
      error.kind == MockFailureKind.offlineLike) {
    return l10n.offlineErrorBody;
  }
  return l10n.errorBody;
}
