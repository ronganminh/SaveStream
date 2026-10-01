import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/mock/mock_repository_base.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../credits/presentation/controllers/credits_providers.dart';
import '../../home/presentation/controllers/home_dashboard_controller.dart';
import '../domain/models/billing_models.dart';
import 'controllers/billing_providers.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen>
    with WidgetsBindingObserver {
  PaymentOrder? _activeOrder;
  bool _isMutating = false;
  Object? _mutationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_activeOrder?.status.isAwaitingConfirmation ?? false)) {
      unawaited(_refreshOrder());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _buy(CreditPackage package) async {
    await _runMutation(() async {
      final PaymentOrder? order = await ref
          .read(billingControllerProvider)
          .createOrder(package.id);
      _activeOrder = order;
      if (order == null) return;
      await _openCheckout(order);
    });
  }

  Future<void> _continueCheckout() async {
    final PaymentOrder? order = _activeOrder;
    if (order == null) return;
    await _runMutation(() => _openCheckout(order));
  }

  Future<void> _openCheckout(PaymentOrder order) async {
    final CheckoutSession? checkout = await ref
        .read(billingControllerProvider)
        .createCheckout(
          orderId: order.id,
          returnUri: AppRoutes.billingReturnUri(order.id),
        );
    if (checkout == null) return;

    _activeOrder = checkout.paymentOrder;
    final bool opened = await launchUrl(
      checkout.checkoutUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw StateError('Unable to launch checkout URL.');
    }
  }

  Future<void> _refreshOrder() async {
    final PaymentOrder? active = _activeOrder;
    if (active == null) return;

    await _runMutation(() async {
      _activeOrder = await ref
          .read(billingControllerProvider)
          .refreshOrder(active.id);
      _invalidateCreditViewsIfPaid(_activeOrder);
    });
  }

  void _invalidateCreditViewsIfPaid(PaymentOrder? order) {
    if (order?.status != PaymentOrderStatus.paid) return;
    ref.invalidate(creditsOverviewProvider);
    ref.invalidate(homeDashboardProvider);
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    if (_isMutating) return;
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
              if (_activeOrder?.status.isAwaitingConfirmation ?? false) {
                await _refreshOrder();
              }
            },
            child: _BillingBody(
              data: data,
              activeOrder: _activeOrder,
              isMutating: _isMutating,
              mutationError: _mutationError,
              onBuy: _buy,
              onContinueCheckout: _continueCheckout,
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
    required this.onContinueCheckout,
    required this.onRefreshOrder,
  });

  final BillingSnapshot data;
  final PaymentOrder? activeOrder;
  final bool isMutating;
  final Object? mutationError;
  final Future<void> Function(CreditPackage package) onBuy;
  final Future<void> Function() onContinueCheckout;
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
            onContinueCheckout: onContinueCheckout,
            onRefresh: onRefreshOrder,
          ),
        ],
        if (mutationError != null) ...<Widget>[
          const SizedBox(height: SsSpacing.md),
          SsErrorState(
            title: _errorTitle(l10n, mutationError!),
            message: _errorMessage(l10n, mutationError!),
            retryLabel: l10n.retryAction,
            onRetry: activeOrder?.status == PaymentOrderStatus.created
                ? onContinueCheckout
                : onRefreshOrder,
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
          ...data.orders
              .take(20)
              .map(
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
          Text(package.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SsSpacing.xs),
          Text(
            l10n.billingPackageCredits(package.credits.toString()),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: SsSpacing.xs),
          Text(
            _formatMoney(context, package.price),
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
    required this.onContinueCheckout,
    required this.onRefresh,
  });

  final PaymentOrder order;
  final bool isMutating;
  final Future<void> Function() onContinueCheckout;
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
                label: paymentStatusLabel(l10n, order.status),
                tone: paymentStatusTone(order.status),
              ),
            ],
          ),
          const SizedBox(height: SsSpacing.sm),
          Text(
            '${order.credits} · ${_formatMoney(context, order.amount)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: SsSpacing.md),
          Text(paymentStatusBody(l10n, order.status)),
          if (order.status == PaymentOrderStatus.created) ...<Widget>[
            const SizedBox(height: SsSpacing.md),
            SsSecondaryButton(
              label: l10n.billingContinueCheckoutAction,
              icon: Icons.open_in_new_rounded,
              onPressed: isMutating ? null : onContinueCheckout,
            ),
          ] else if (order.status == PaymentOrderStatus.pending) ...<Widget>[
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
                  l10n.billingPackageCredits(order.credits.toString()),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: SsSpacing.xs),
                Text(_formatMoney(context, order.amount)),
                const SizedBox(height: SsSpacing.xs),
                Text(
                  '${material.formatMediumDate(local)} · ${order.id}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SsStatusChip(
            label: paymentStatusLabel(l10n, order.status),
            tone: paymentStatusTone(order.status),
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

String paymentStatusLabel(AppLocalizations l10n, PaymentOrderStatus status) {
  return switch (status) {
    PaymentOrderStatus.created => l10n.paymentStatusCreated,
    PaymentOrderStatus.pending => l10n.paymentStatusPending,
    PaymentOrderStatus.paid => l10n.paymentStatusPaid,
    PaymentOrderStatus.failed => l10n.paymentStatusFailed,
    PaymentOrderStatus.cancelled => l10n.paymentStatusCancelled,
    PaymentOrderStatus.expired => l10n.paymentStatusExpired,
    PaymentOrderStatus.partiallyRefunded => l10n.paymentStatusPartiallyRefunded,
    PaymentOrderStatus.refunded => l10n.paymentStatusRefunded,
  };
}

String paymentStatusBody(AppLocalizations l10n, PaymentOrderStatus status) {
  return switch (status) {
    PaymentOrderStatus.created => l10n.paymentCreatedBody,
    PaymentOrderStatus.pending => l10n.paymentPendingBody,
    PaymentOrderStatus.paid => l10n.paymentPaidBody,
    PaymentOrderStatus.failed => l10n.paymentFailedBody,
    PaymentOrderStatus.cancelled => l10n.paymentCancelledBody,
    PaymentOrderStatus.expired => l10n.paymentExpiredBody,
    PaymentOrderStatus.partiallyRefunded => l10n.paymentPartiallyRefundedBody,
    PaymentOrderStatus.refunded => l10n.paymentRefundedBody,
  };
}

SsStatusTone paymentStatusTone(PaymentOrderStatus status) {
  return switch (status) {
    PaymentOrderStatus.created => SsStatusTone.neutral,
    PaymentOrderStatus.pending => SsStatusTone.warning,
    PaymentOrderStatus.paid => SsStatusTone.success,
    PaymentOrderStatus.failed => SsStatusTone.error,
    PaymentOrderStatus.cancelled ||
    PaymentOrderStatus.expired ||
    PaymentOrderStatus.refunded => SsStatusTone.neutral,
    PaymentOrderStatus.partiallyRefunded => SsStatusTone.warning,
  };
}

String _formatMoney(BuildContext context, Money money) {
  final NumberFormat format = NumberFormat.simpleCurrency(
    name: money.currency,
    locale: Localizations.localeOf(context).toLanguageTag(),
  );
  final int decimalDigits = format.decimalDigits ?? 2;
  final num scale = pow(10, decimalDigits);
  return format.format(money.amountMinor / scale);
}

String _errorTitle(AppLocalizations l10n, Object error) {
  if (_isOfflineLike(error)) return l10n.offlineErrorTitle;
  return l10n.errorTitle;
}

String _errorMessage(AppLocalizations l10n, Object error) {
  if (_isOfflineLike(error)) return l10n.offlineErrorBody;
  return l10n.errorBody;
}

bool _isOfflineLike(Object error) {
  return (error is MockRepositoryException &&
          error.kind == MockFailureKind.offlineLike) ||
      (error is ApiException &&
          (error.kind == ApiExceptionKind.network ||
              error.kind == ApiExceptionKind.timeout));
}
