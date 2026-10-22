/// ACredits · ARewardEarned · ARewardCooldown · ARewardLimit ·
/// ARewardFailed · APurchaseFailed · ARestore.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/platform_providers.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../home/domain/models/home_credits.dart';
import '../../store/presentation/a5_purchase_controller.dart';
import '../../store/presentation/a5_store_providers.dart';
import '../domain/credit_balance.dart';
import 'credits_providers.dart';
import 'credits_v2_parts.dart';
import 'rewarded_ad_controller.dart';

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    ref.listen<CloudHoursPurchaseState>(
      cloudHoursPurchaseControllerProvider,
      (CloudHoursPurchaseState? previous, CloudHoursPurchaseState next) =>
          _onPurchase(context, ref, previous, next),
    );
    ref.listen<RewardState>(rewardedAdControllerProvider, (
      RewardState? previous,
      RewardState next,
    ) {
      if (previous?.phase == next.phase) return;
      final int minutes =
          ref.read(entitlementProvider).value?.ads?.minutesPerReward ?? 0;
      if (next.phase == RewardPhase.earned) {
        showCreditsToast(context, l10n.crRewardEarned(minutes));
        ref.read(rewardedAdControllerProvider.notifier).acknowledge();
      } else if (next.phase == RewardPhase.slow) {
        showCreditsToast(context, l10n.crRewardSlow);
        ref.read(rewardedAdControllerProvider.notifier).acknowledge();
      }
    });

    final AsyncValue<Entitlement> entitlement = ref.watch(entitlementProvider);
    final CreditBalance? balance = ref.watch(creditBalanceProvider).value;

    return SsV2Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsV2Header(onBack: () => creditsBack(context), title: l10n.crTitle),
          Expanded(
            child: entitlement.when(
              skipLoadingOnRefresh: true,
              skipLoadingOnReload: true,
              loading: () => const Center(child: SsV2Spinner()),
              error: (Object error, StackTrace stackTrace) => _LoadError(
                onRetry: () {
                  ref.invalidate(entitlementProvider);
                  ref.invalidate(creditBalanceProvider);
                },
              ),
              data: (Entitlement value) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(entitlementProvider);
                  ref.invalidate(creditBalanceProvider);
                  ref.invalidate(cloudHoursOffersProvider);
                  await ref.read(entitlementProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: ssV2Gap(<Widget>[
                    CreditsBalanceCard(
                      credits: HomeCredits.from(value, balance),
                    ),
                    if (_RewardCard.visible(ref, value))
                      _RewardCard(entitlement: value),
                    SsV2SectionHeader(title: l10n.crBuyTitle),
                    const _Packs(),
                    Text(
                      l10n.crPaidNote,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: SsV2Palette.of(context).textMuted,
                      ),
                    ),
                    const _FooterLinks(),
                  ], 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _onPurchase(
    BuildContext context,
    WidgetRef ref,
    CloudHoursPurchaseState? previous,
    CloudHoursPurchaseState next,
  ) {
    if (previous?.phase == next.phase) return;
    // A result screen or dialog on top handles it.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final AppLocalizations l10n = context.l10n;
    final CloudHoursPurchaseController controller = ref.read(
      cloudHoursPurchaseControllerProvider.notifier,
    );
    switch (next.phase) {
      case CloudHoursPurchasePhase.credited:
        context.push(AppRoutes.purchaseSuccess);
      case CloudHoursPurchasePhase.pending:
        context.push(AppRoutes.purchasePending);
      case CloudHoursPurchasePhase.cancelled:
        controller.acknowledge();
      case CloudHoursPurchasePhase.failed:
        if (next.isRestore) {
          showCreditsDialog(
            context: context,
            glyph: SsV2IconGlyph.alert,
            tone: SsV2Tone.error,
            title: l10n.crRestoreFailedTitle,
            body: <Widget>[Text(l10n.crRestoreFailedBody)],
            actions: <CreditsDialogAction>[
              CreditsDialogAction(label: l10n.crClose),
              CreditsDialogAction(
                label: l10n.crTryAgain,
                primary: true,
                onPressed: controller.restore,
              ),
            ],
          );
        } else if (next.orderId != null) {
          // Play took the payment; the server will be asked again.
          showCreditsDialog(
            context: context,
            glyph: SsV2IconGlyph.clock,
            tone: SsV2Tone.warning,
            title: l10n.crConfirmDelayedTitle,
            body: <Widget>[Text(l10n.crConfirmDelayedBody)],
            actions: <CreditsDialogAction>[
              CreditsDialogAction(
                label: l10n.crOk,
                primary: true,
                onPressed: controller.acknowledge,
              ),
            ],
          );
        } else {
          final CloudHoursOffer? offer = _offerFor(ref, next.selectedProductId);
          showCreditsDialog(
            context: context,
            glyph: SsV2IconGlyph.alert,
            tone: SsV2Tone.error,
            title: l10n.crFailedTitle,
            body: <Widget>[Text(l10n.crFailedBody)],
            actions: <CreditsDialogAction>[
              CreditsDialogAction(
                label: l10n.crClose,
                onPressed: controller.acknowledge,
              ),
              CreditsDialogAction(
                label: l10n.crTryAgain,
                primary: true,
                onPressed: offer == null
                    ? controller.acknowledge
                    : () => controller.buy(offer),
              ),
            ],
          );
        }
      case CloudHoursPurchasePhase.restored:
        _showRestored(context, ref, next);
      case CloudHoursPurchasePhase.idle:
      case CloudHoursPurchasePhase.processing:
      case CloudHoursPurchasePhase.restoring:
        break;
    }
  }

  static CloudHoursOffer? _offerFor(WidgetRef ref, String? productId) {
    final List<CloudHoursOffer> offers =
        ref.read(cloudHoursOffersProvider).value ?? const <CloudHoursOffer>[];
    for (final CloudHoursOffer offer in offers) {
      if (offer.productId == productId) return offer;
    }
    return null;
  }

  static void _showRestored(
    BuildContext context,
    WidgetRef ref,
    CloudHoursPurchaseState state,
  ) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final CloudHoursPurchaseController controller = ref.read(
      cloudHoursPurchaseControllerProvider.notifier,
    );
    final List<CreditsDialogAction> ok = <CreditsDialogAction>[
      CreditsDialogAction(
        label: l10n.crOk,
        primary: true,
        onPressed: controller.acknowledge,
      ),
    ];
    if (state.restored.isEmpty) {
      showCreditsDialog(
        context: context,
        glyph: SsV2IconGlyph.refresh,
        tone: SsV2Tone.success,
        title: l10n.crRestoreNoneTitle,
        body: <Widget>[Text(l10n.crRestoreNoneBody)],
        actions: ok,
      );
      return;
    }
    final String packs = state.restored
        .map((RestoredPurchase item) {
          final CloudHoursOffer? offer = _offerFor(ref, item.productId);
          return l10n.crPackLabel(
            offer?.package.name ?? item.productId,
            item.minutes ~/ 60,
          );
        })
        .join(', ');
    final String count = l10n.crRestoredCount(state.restored.length);
    final String sentence = state.restored.length == 1
        ? l10n.crRestoredBodyOne(count, packs)
        : l10n.crRestoredBodyMany(count, packs);
    final int at = sentence.indexOf(count);
    showCreditsDialog(
      context: context,
      glyph: SsV2IconGlyph.refresh,
      tone: SsV2Tone.success,
      title: l10n.crRestoredTitle,
      body: <Widget>[
        Text.rich(
          at < 0
              ? TextSpan(text: sentence)
              : TextSpan(
                  children: <InlineSpan>[
                    TextSpan(text: sentence.substring(0, at)),
                    TextSpan(
                      text: count,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    TextSpan(text: sentence.substring(at + count.length)),
                  ],
                ),
        ),
        Text(l10n.crRestoredNote, style: const TextStyle(fontSize: 13)),
      ],
      actions: ok,
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsV2Banner(
            tone: SsV2Tone.error,
            actions: <Widget>[
              SsV2Button(
                label: l10n.crRetry,
                size: SsV2ButtonSize.small,
                variant: SsV2ButtonVariant.outlined,
                expand: false,
                onPressed: onRetry,
              ),
            ],
            child: Text(l10n.crLoadError),
          ),
        ],
      ),
    );
  }
}

/// "Watch an ad, get 5 minutes" with today's use and the button's states.
class _RewardCard extends ConsumerWidget {
  const _RewardCard({required this.entitlement});

  final Entitlement entitlement;

  /// Hidden without an `ads` block, without a rewarded unit in this build,
  /// and when the server has rewarded ads switched off.
  static bool visible(WidgetRef ref, Entitlement entitlement) {
    final AdsEntitlement? ads = entitlement.ads;
    if (ads == null || ads.rewardsCapPerDay <= 0) return false;
    if (!ref.watch(adsServiceProvider).rewardedConfigured) return false;
    final RewardPhase phase = ref.watch(rewardedAdControllerProvider).phase;
    if (phase == RewardPhase.unavailable) return false;
    // Server-side off (not just used up or waiting for a verified email).
    return ads.rewardedAvailable ||
        ads.rewardsLeftToday == 0 ||
        !entitlement.emailVerified;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final AdsEntitlement ads = entitlement.ads!;
    final RewardState reward = ref.watch(rewardedAdControllerProvider);
    final RewardedAdController controller = ref.read(
      rewardedAdControllerProvider.notifier,
    );
    final int cap = ads.rewardsCapPerDay;
    final int used = ads.rewardsUsedToday;
    final bool limit =
        ads.rewardsLeftToday == 0 || reward.phase == RewardPhase.limit;
    final bool emailNeeded =
        !entitlement.emailVerified ||
        reward.phase == RewardPhase.emailUnverified;

    final Widget action;
    if (limit) {
      action = Row(
        children: <Widget>[
          SsV2Icon(SsV2IconGlyph.check, size: 18, color: palette.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.crRewardLimit(cap),
              style: TextStyle(fontSize: 14, color: palette.textMuted),
            ),
          ),
        ],
      );
    } else if (emailNeeded) {
      action = SsV2Banner(tone: SsV2Tone.info, child: Text(l10n.crRewardEmail));
    } else if (reward.phase == RewardPhase.failed) {
      action = _RewardFailed(onRetry: controller.watchAd);
    } else if (reward.phase == RewardPhase.cooldown &&
        reward.cooldownUntil != null) {
      action = CreditsCountdown(
        until: reward.cooldownUntil!,
        now: ref.watch(creditsClockProvider),
        onDone: controller.cooldownElapsed,
        builder: (BuildContext context, String remaining) => CreditsTintButton(
          label: l10n.crRewardCooldown(remaining),
          glyph: SsV2IconGlyph.clock,
          onPressed: null,
        ),
      );
    } else {
      action = CreditsTintButton(
        key: const ValueKey<String>('credits-watch-ad'),
        label: switch (reward.phase) {
          RewardPhase.loading => l10n.crRewardLoading,
          RewardPhase.verifying => l10n.crRewardVerifying,
          _ => l10n.crRewardAction(ads.minutesPerReward),
        },
        glyph: SsV2IconGlyph.play,
        busy: reward.busy,
        onPressed: controller.watchAd,
      );
    }

    return SsV2Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: ssV2Gap(<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CreditsIconTile(
                glyph: SsV2IconGlyph.ad,
                background: palette.tint,
                foreground: palette.link,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.crRewardTitle(ads.minutesPerReward),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.crRewardCaption(cap, used),
                      style: TextStyle(fontSize: 13, color: palette.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ExcludeSemantics(
            child: Row(
              children: <Widget>[
                for (int i = 0; i < cap; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < used ? palette.primary : palette.divider,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          action,
        ], 12),
      ),
    );
  }
}

class _RewardFailed extends StatelessWidget {
  const _RewardFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.errorBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: SsV2Icon(
                SsV2IconGlyph.alert,
                size: 20,
                color: palette.errorText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.crRewardFailed,
                    style: const TextStyle(fontSize: 14, height: 1.45),
                  ),
                  const SizedBox(height: 10),
                  SsV2Button(
                    label: l10n.crTryAgain,
                    variant: SsV2ButtonVariant.outlined,
                    size: SsV2ButtonSize.small,
                    leading: SsV2Icon(
                      SsV2IconGlyph.refresh,
                      size: 18,
                      color: palette.text,
                    ),
                    onPressed: onRetry,
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

/// The packs from the server, priced by Google Play.
class _Packs extends ConsumerWidget {
  const _Packs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final AsyncValue<List<CloudHoursOffer>> offers = ref.watch(
      cloudHoursOffersProvider,
    );
    final CloudHoursPurchaseState purchase = ref.watch(
      cloudHoursPurchaseControllerProvider,
    );
    return offers.when(
      skipLoadingOnRefresh: true,
      loading: () => Column(
        children: ssV2Gap(<Widget>[
          for (int i = 0; i < 3; i++)
            const SsV2Skeleton(height: 72, radius: 18),
        ], 12),
      ),
      error: (Object error, StackTrace stackTrace) => SsV2Banner(
        tone: SsV2Tone.error,
        actions: <Widget>[
          SsV2Button(
            label: l10n.crRetry,
            size: SsV2ButtonSize.small,
            variant: SsV2ButtonVariant.outlined,
            expand: false,
            onPressed: () => ref.invalidate(cloudHoursOffersProvider),
          ),
        ],
        child: Text(l10n.crPacksError),
      ),
      data: (List<CloudHoursOffer> items) {
        if (items.isEmpty) {
          return Text(
            l10n.crPacksEmpty,
            style: TextStyle(fontSize: 14, color: palette.textMuted),
          );
        }
        final bool busy =
            purchase.phase == CloudHoursPurchasePhase.processing ||
            purchase.phase == CloudHoursPurchasePhase.restoring;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: ssV2Gap(<Widget>[
            for (int i = 0; i < items.length; i++)
              _PackTile(
                offer: items[i],
                popular: items[i].package.featured,
                processing:
                    purchase.phase == CloudHoursPurchasePhase.processing &&
                    purchase.selectedProductId == items[i].productId,
                onTap: busy
                    ? null
                    : () => ref
                          .read(cloudHoursPurchaseControllerProvider.notifier)
                          .buy(items[i]),
              ),
          ], 12),
        );
      },
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({
    required this.offer,
    required this.popular,
    required this.processing,
    required this.onTap,
  });

  final CloudHoursOffer offer;
  final bool popular;
  final bool processing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    return Semantics(
      button: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: popular
              ? <BoxShadow>[BoxShadow(color: palette.tint, spreadRadius: 4)]
              : null,
        ),
        child: Material(
          color: palette.surface,
          textStyle: ssV2BaseText(palette),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: popular
                ? BorderSide(color: palette.primary, width: 2)
                : BorderSide(color: palette.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey<String>('credits-pack-${offer.productId}'),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: popular ? 15 : 16,
                  vertical: popular ? 13 : 14,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  offer.package.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (popular) ...<Widget>[
                                const SizedBox(width: 8),
                                SsV2StatusChip(
                                  label: l10n.crMostPopular,
                                  tone: SsV2ChipTone.brand,
                                  fontSize: 11,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.crPackHours(offer.hours),
                            style: TextStyle(
                              fontSize: 13,
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (processing)
                      SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: palette.primary,
                        ),
                      )
                    else
                      Text(
                        offer.localizedPrice,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterLinks extends ConsumerWidget {
  const _FooterLinks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final CloudHoursPurchaseState purchase = ref.watch(
      cloudHoursPurchaseControllerProvider,
    );
    final bool restoring = purchase.phase == CloudHoursPurchasePhase.restoring;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        CreditsTextLink(
          label: restoring ? l10n.crRestoring : l10n.crRestore,
          onPressed:
              restoring || purchase.phase == CloudHoursPurchasePhase.processing
              ? null
              : ref.read(cloudHoursPurchaseControllerProvider.notifier).restore,
        ),
        CreditsTextLink(
          label: l10n.crUsageHistory,
          onPressed: () => context.push(AppRoutes.creditsHistory),
        ),
      ],
    );
  }
}
