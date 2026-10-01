import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../credits/presentation/controllers/credits_providers.dart';
import '../../home/presentation/controllers/home_dashboard_controller.dart';
import '../domain/models/billing_models.dart';
import 'billing_screen.dart';
import 'controllers/billing_providers.dart';

class BillingReturnScreen extends ConsumerWidget {
  const BillingReturnScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<PaymentOrder?> order = ref.watch(
      paymentOrderStatusProvider(orderId),
    );

    ref.listen<AsyncValue<PaymentOrder?>>(paymentOrderStatusProvider(orderId), (
      AsyncValue<PaymentOrder?>? previous,
      AsyncValue<PaymentOrder?> next,
    ) {
      next.whenData((PaymentOrder? value) {
        if (value?.status == PaymentOrderStatus.paid) {
          ref.invalidate(creditsOverviewProvider);
          ref.invalidate(homeDashboardProvider);
          ref.invalidate(billingSnapshotProvider);
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.billingReturnTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SsSpacing.lg),
          child: order.when(
            loading: () => const _BillingReturnSkeleton(),
            error: (Object error, StackTrace stackTrace) => SsAsyncErrorState(
              error: error,
              onRetry: () =>
                  ref.invalidate(paymentOrderStatusProvider(orderId)),
            ),
            data: (PaymentOrder? value) {
              if (value == null) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SsEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.billingOrderNotFoundTitle,
                      message: l10n.billingOrderNotFoundBody,
                    ),
                    const SizedBox(height: SsSpacing.md),
                    SsPrimaryButton(
                      label: l10n.backToBillingAction,
                      onPressed: () => context.go(AppRoutes.billing),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SsCard(
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
                              label: paymentStatusLabel(l10n, value.status),
                              tone: paymentStatusTone(value.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: SsSpacing.md),
                        Text(paymentStatusBody(l10n, value.status)),
                        if (value.status.isAwaitingConfirmation) ...<Widget>[
                          const SizedBox(height: SsSpacing.md),
                          const LinearProgressIndicator(),
                          const SizedBox(height: SsSpacing.sm),
                          Text(l10n.billingPollingStatusBody),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: SsSpacing.lg),
                  SsPrimaryButton(
                    label: l10n.backToBillingAction,
                    onPressed: () => context.go(AppRoutes.billing),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BillingReturnSkeleton extends StatelessWidget {
  const _BillingReturnSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const <Widget>[
        SsSkeleton(height: 170, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.lg),
        SsSkeleton(height: 52, radius: SsRadii.md),
      ],
    );
  }
}
