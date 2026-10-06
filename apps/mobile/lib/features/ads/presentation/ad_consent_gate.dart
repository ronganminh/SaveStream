import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/contracts/ads_service.dart';
import '../../../platform/platform_providers.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';

class AdConsentGate extends ConsumerStatefulWidget {
  const AdConsentGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AdConsentGate> createState() => _AdConsentGateState();
}

class _AdConsentGateState extends ConsumerState<AdConsentGate> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Entitlement> entitlement = ref.watch(entitlementProvider);
    final AdConsentState consent = ref.watch(adsServiceProvider).consentState;
    final bool pro = entitlement.value?.plan == Plan.pro;
    final bool shouldExplain =
        !pro && consent == AdConsentState.required && !_acknowledged;

    return Stack(
      children: <Widget>[
        widget.child,
        if (shouldExplain)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(
                context,
              ).colorScheme.scrim.withValues(alpha: 0.72),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(SsSpacing.lg),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: SsCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Icon(Icons.ads_click_rounded, size: 48),
                            const SizedBox(height: SsSpacing.md),
                            Text(
                              context.l10n.adConsentTitle,
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: SsSpacing.sm),
                            Text(
                              context.l10n.adConsentBody,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: SsSpacing.md),
                            SsInlineAlert(
                              title: context.l10n.adConsentPrivacyTitle,
                              message: context.l10n.adConsentPrivacyBody,
                            ),
                            const SizedBox(height: SsSpacing.lg),
                            SsPrimaryButton(
                              label: context.l10n.adConsentContinueAction,
                              onPressed: () =>
                                  setState(() => _acknowledged = true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
