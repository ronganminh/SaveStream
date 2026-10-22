/// APurchases: balance, Google Play purchases and where receipts live.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/app_config_provider.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../home/presentation/home_screen.dart' show formatRecordingMinutes;
import '../../store/domain/models/store_models.dart';
import '../../store/presentation/a5_store_providers.dart';
import '../domain/credit_ledger.dart';
import 'credits_providers.dart';
import 'credits_v2_parts.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  late final TapGestureRecognizer _manage = TapGestureRecognizer()
    ..onTap = () => openExternalUrl(AppConfig.googlePlayOrderHistoryUrl);
  late final TapGestureRecognizer _refund = TapGestureRecognizer()
    ..onTap = () =>
        openExternalUrl(ref.read(appConfigProvider).refundPolicyUrl);

  @override
  void dispose() {
    _manage.dispose();
    _refund.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final int? minutes = ref
        .watch(entitlementProvider)
        .value
        ?.cloudMinutesAvailable;
    final AsyncValue<List<PaymentOrder>> orders = ref.watch(
      playPurchasesProvider,
    );
    final Map<String, StorePackage> packages = <String, StorePackage>{
      for (final StorePackage package
          in ref.watch(storePackagesProvider).value ?? const <StorePackage>[])
        package.id: package,
    };
    final TextStyle muted = TextStyle(
      fontSize: 13,
      height: 1.5,
      color: palette.textMuted,
    );
    final TextStyle link = TextStyle(
      color: palette.link,
      decoration: TextDecoration.underline,
      decorationColor: palette.link,
    );

    return SsV2Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsV2Header(
            onBack: () => creditsBack(context, fallback: AppRoutes.settings),
            title: l10n.crPurchasesTitle,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(playPurchasesProvider);
                ref.invalidate(entitlementProvider);
                await ref.read(playPurchasesProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: ssV2Gap(<Widget>[
                  SsV2Card(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                l10n.crBalanceLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                minutes == null
                                    ? '—'
                                    : formatRecordingMinutes(l10n, minutes),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SsV2Button(
                          label: l10n.crBuy,
                          size: SsV2ButtonSize.small,
                          expand: false,
                          onPressed: () => context.push(AppRoutes.usage),
                        ),
                      ],
                    ),
                  ),
                  SsV2SectionHeader(title: l10n.crPlayPurchases),
                  orders.when(
                    skipLoadingOnRefresh: true,
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: SsV2Spinner()),
                    ),
                    error: (Object error, StackTrace stackTrace) => SsV2Banner(
                      tone: SsV2Tone.error,
                      actions: <Widget>[
                        SsV2Button(
                          label: l10n.crRetry,
                          size: SsV2ButtonSize.small,
                          variant: SsV2ButtonVariant.outlined,
                          expand: false,
                          onPressed: () =>
                              ref.invalidate(playPurchasesProvider),
                        ),
                      ],
                      child: Text(l10n.crPurchasesError),
                    ),
                    data: (List<PaymentOrder> items) => items.isEmpty
                        ? Text(
                            l10n.crPurchasesEmpty,
                            style: TextStyle(
                              fontSize: 14,
                              color: palette.textMuted,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              for (final PaymentOrder order in items)
                                _orderRow(context, order, packages, palette),
                            ],
                          ),
                  ),
                  SsV2Button(
                    label: l10n.crUsageHistory,
                    variant: SsV2ButtonVariant.outlined,
                    leading: SsV2Icon(
                      SsV2IconGlyph.chart,
                      size: 20,
                      color: palette.text,
                    ),
                    onPressed: () => context.push(AppRoutes.creditsHistory),
                  ),
                  Text.rich(
                    TextSpan(
                      style: muted,
                      children: <InlineSpan>[
                        TextSpan(text: '${l10n.crPlayFootnote} '),
                        TextSpan(
                          text: l10n.crManageInPlay,
                          style: link,
                          recognizer: _manage,
                        ),
                        const TextSpan(text: ' · '),
                        TextSpan(
                          text: l10n.crRefundPolicy,
                          style: link,
                          recognizer: _refund,
                        ),
                      ],
                    ),
                  ),
                ], 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderRow(
    BuildContext context,
    PaymentOrder order,
    Map<String, StorePackage> packages,
    SsV2Palette palette,
  ) {
    final AppLocalizations l10n = context.l10n;
    final int hours = order.credits ~/ 60;
    final String? name = packages[order.packageId]?.name;
    final (String status, Color color) = switch (order.status) {
      PaymentOrderStatus.paid => (l10n.crOrderAdded, palette.success),
      PaymentOrderStatus.pending ||
      PaymentOrderStatus.created => (l10n.crOrderPending, palette.warning),
      PaymentOrderStatus.refunded || PaymentOrderStatus.partiallyRefunded => (
        l10n.crOrderRefunded,
        palette.textMuted,
      ),
      PaymentOrderStatus.failed ||
      PaymentOrderStatus.cancelled ||
      PaymentOrderStatus.expired => (l10n.crOrderFailed, palette.textMuted),
    };
    return CreditsListRow(
      title: name == null
          ? formatRecordingMinutes(l10n, order.credits)
          : l10n.crPackLabel(name, hours),
      subtitle: creditsLongDate(context, order.createdAt),
      trailing: status,
      trailingColor: color,
    );
  }
}
