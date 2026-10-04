import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import 'a5_purchase_controller.dart';
import 'a5_store_providers.dart';

class CloudHoursPurchaseScreen extends ConsumerWidget {
  const CloudHoursPurchaseScreen({required this.contextType, super.key});

  final CloudHoursPurchaseContext contextType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CloudHoursOffer>> offers = ref.watch(
      cloudHoursOffersProvider,
    );
    final CloudHoursPurchaseState purchase = ref.watch(
      cloudHoursPurchaseControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.buyCloudHoursAction)),
      body: SafeArea(
        child: offers.when(
          loading: () => const _PurchaseSkeleton(),
          error: (Object error, StackTrace stackTrace) => Center(
            child: SsAsyncErrorState(
              error: error,
              onRetry: () => ref.invalidate(cloudHoursOffersProvider),
            ),
          ),
          data: (List<CloudHoursOffer> items) => ListView(
            padding: const EdgeInsets.all(SsSpacing.lg),
            children: <Widget>[
              Text(
                _title(context.l10n, contextType),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: SsSpacing.sm),
              Text(_subtitle(context.l10n, contextType)),
              const SizedBox(height: SsSpacing.lg),
              for (final CloudHoursOffer offer in items) ...<Widget>[
                SsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        context.l10n.cloudHoursPackValue(offer.hours),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: SsSpacing.xs),
                      Text(offer.localizedPrice),
                      const SizedBox(height: SsSpacing.md),
                      SsPrimaryButton(
                        label: context.l10n.buyCloudHoursAction,
                        isLoading:
                            purchase.phase ==
                                CloudHoursPurchasePhase.processing &&
                            purchase.selectedProductId == offer.productId,
                        onPressed:
                            purchase.phase == CloudHoursPurchasePhase.processing
                            ? null
                            : () => ref
                                  .read(
                                    cloudHoursPurchaseControllerProvider
                                        .notifier,
                                  )
                                  .buy(offer),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SsSpacing.md),
              ],
              SsInlineAlert(
                title: context.l10n.cloudHoursOneTimeTitle,
                message: context.l10n.cloudHoursOneTimeBody,
              ),
              const SizedBox(height: SsSpacing.md),
              SsSecondaryButton(
                label: context.l10n.restorePurchasesAction,
                onPressed: purchase.phase == CloudHoursPurchasePhase.restoring
                    ? null
                    : () => ref
                          .read(cloudHoursPurchaseControllerProvider.notifier)
                          .restore(),
              ),
              if (purchase.phase != CloudHoursPurchasePhase.idle) ...<Widget>[
                const SizedBox(height: SsSpacing.md),
                _PurchaseStatus(state: purchase),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseStatus extends StatelessWidget {
  const _PurchaseStatus({required this.state});

  final CloudHoursPurchaseState state;

  @override
  Widget build(BuildContext context) {
    final String message = switch (state.phase) {
      CloudHoursPurchasePhase.processing => context.l10n.purchaseProcessingBody,
      CloudHoursPurchasePhase.pending => context.l10n.purchasePendingBody,
      CloudHoursPurchasePhase.credited => context.l10n.purchaseSuccessBody,
      CloudHoursPurchasePhase.cancelled => context.l10n.purchaseCancelledBody,
      CloudHoursPurchasePhase.failed => context.l10n.purchaseFailedBody,
      CloudHoursPurchasePhase.restoring => context.l10n.restoreProcessingBody,
      CloudHoursPurchasePhase.restored => context.l10n.restoreSuccessBody,
      CloudHoursPurchasePhase.idle => '',
    };

    return SsInlineAlert(
      title: context.l10n.buyCloudHoursAction,
      message: message,
      tone: state.phase == CloudHoursPurchasePhase.failed
          ? SsInlineAlertTone.warning
          : SsInlineAlertTone.info,
    );
  }
}

String _title(AppLocalizations l10n, CloudHoursPurchaseContext value) {
  return switch (value) {
    CloudHoursPurchaseContext.autoRecord => l10n.purchaseContextAutoRecordTitle,
    CloudHoursPurchaseContext.watchLimit => l10n.purchaseContextWatchLimitTitle,
    CloudHoursPurchaseContext.iosBackground =>
      l10n.purchaseContextIosBackgroundTitle,
    CloudHoursPurchaseContext.freeMinutesExhausted =>
      l10n.purchaseContextFreeMinutesTitle,
    CloudHoursPurchaseContext.removeAds => l10n.purchaseContextRemoveAdsTitle,
  };
}

String _subtitle(AppLocalizations l10n, CloudHoursPurchaseContext value) {
  return switch (value) {
    CloudHoursPurchaseContext.autoRecord => l10n.purchaseContextAutoRecordBody,
    CloudHoursPurchaseContext.watchLimit => l10n.purchaseContextWatchLimitBody,
    CloudHoursPurchaseContext.iosBackground =>
      l10n.purchaseContextIosBackgroundBody,
    CloudHoursPurchaseContext.freeMinutesExhausted =>
      l10n.purchaseContextFreeMinutesBody,
    CloudHoursPurchaseContext.removeAds => l10n.purchaseContextRemoveAdsBody,
  };
}

class _PurchaseSkeleton extends StatelessWidget {
  const _PurchaseSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(height: 72, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.lg),
        SsSkeleton(height: 150, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 150, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 150, radius: SsRadii.lg),
      ],
    );
  }
}
