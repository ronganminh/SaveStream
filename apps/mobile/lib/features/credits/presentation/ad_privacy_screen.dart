/// AAdPrivacy: personalized ads switch and the UMP privacy options form.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/config/app_config_provider.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/contracts/ads_service.dart';
import '../../../platform/platform_providers.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import 'credits_providers.dart';
import 'credits_v2_parts.dart';

class AdPrivacyScreen extends ConsumerStatefulWidget {
  const AdPrivacyScreen({super.key});

  @override
  ConsumerState<AdPrivacyScreen> createState() => _AdPrivacyScreenState();
}

class _AdPrivacyScreenState extends ConsumerState<AdPrivacyScreen> {
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () =>
        openExternalUrl(ref.read(appConfigProvider).privacyPolicyUrl);
  bool _opening = false;

  @override
  void dispose() {
    _privacy.dispose();
    super.dispose();
  }

  Future<void> _reviewConsent() async {
    final AppLocalizations l10n = context.l10n;
    final AdsService ads = ref.read(adsServiceProvider);
    setState(() => _opening = true);
    try {
      // Refreshes the consent info first so the requirement is current.
      await ads.ensureConsent();
      if (await ads.privacyOptionsRequired()) {
        await ads.showPrivacyOptions();
      } else if (mounted) {
        showCreditsToast(context, l10n.crConsentNotRequired);
      }
    } on Object {
      if (mounted) showCreditsToast(context, l10n.crConsentNotRequired);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final bool personalized = ref.watch(personalizedAdsProvider).value ?? false;
    final bool purchased =
        ref.watch(entitlementProvider).value?.hasPurchased ?? false;
    final TextStyle muted = TextStyle(
      fontSize: 13,
      height: 1.5,
      color: palette.textMuted,
    );

    return SsV2Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsV2Header(
            onBack: () => creditsBack(context, fallback: AppRoutes.settings),
            title: l10n.crAdPrivacyTitle,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: ssV2Gap(<Widget>[
                Text(
                  l10n.crAdPrivacyIntro,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: palette.textMuted,
                  ),
                ),
                SsV2Card(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: SsV2SwitchRow(
                    key: const ValueKey<String>('ad-privacy-personalized'),
                    title: l10n.crPersonalizedAds,
                    subtitle: l10n.crPersonalizedAdsBody,
                    value: personalized,
                    onChanged: (bool value) =>
                        ref.read(personalizedAdsProvider.notifier).set(value),
                  ),
                ),
                SsV2Button(
                  label: l10n.crReviewConsent,
                  variant: SsV2ButtonVariant.outlined,
                  isLoading: _opening,
                  leading: SsV2Icon(
                    SsV2IconGlyph.shield,
                    size: 20,
                    color: palette.text,
                  ),
                  onPressed: _reviewConsent,
                ),
                Text(l10n.crConsentNote, style: muted),
                if (purchased)
                  SsV2Banner(
                    tone: SsV2Tone.success,
                    child: Text(l10n.crAdsRemoved),
                  ),
                Text.rich(
                  TextSpan(
                    style: muted,
                    children: <InlineSpan>[
                      TextSpan(text: l10n.crLearnMorePrefix),
                      TextSpan(
                        text: l10n.crPrivacyPolicy,
                        recognizer: _privacy,
                        style: TextStyle(
                          color: palette.link,
                          decoration: TextDecoration.underline,
                          decorationColor: palette.link,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ], 14),
            ),
          ),
        ],
      ),
    );
  }
}
