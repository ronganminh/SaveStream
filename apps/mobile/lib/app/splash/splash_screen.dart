/// ASplash — logo, tagline and spinner while the session is restored.
import 'package:flutter/material.dart';

import '../../core/widgets/v2/ss_v2_widgets.dart';
import '../../l10n/l10n.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    return SsV2Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const SsV2LogoMark(size: 88),
                const SizedBox(height: 18),
                Text(
                  l10n.appTitle,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.v2SplashTagline,
                  style: TextStyle(fontSize: 15, color: palette.textMuted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Column(
              children: <Widget>[
                Semantics(
                  label: l10n.v2LoadingLabel,
                  child: const SsV2Spinner(),
                ),
                const SizedBox(height: 16),
                SsV2Disclaimer(text: l10n.v2NotAffiliated),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
