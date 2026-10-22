import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/platform_providers.dart';
import '../../entitlement/domain/models/entitlement.dart';
import 'credits_providers.dart';

/// The small banner for accounts that never bought a pack
/// (`entitlement.ads.show_banners`). Placed at the end of list screens only
/// (Home), never on the player, purchase/payment or verification screens.
/// Takes no space when there is nothing to show.
class AdBannerSlot extends ConsumerWidget {
  const AdBannerSlot({required this.ads, super.key});

  /// The screen's entitlement `ads` block (null: no ads).
  final AdsEntitlement? ads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AdsEntitlement? ads = this.ads;
    if (ads == null || !ads.showBanners) return const SizedBox.shrink();
    final adsService = ref.watch(adsServiceProvider);
    if (!adsService.bannerConfigured) return const SizedBox.shrink();
    final bool personalized = ref.watch(personalizedAdsProvider).value ?? false;
    return Semantics(
      container: true,
      label: context.l10n.crAdLabel,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: SsV2Palette.of(context).textMuted),
          child: adsService.buildBanner(personalized: personalized),
        ),
      ),
    );
  }
}
