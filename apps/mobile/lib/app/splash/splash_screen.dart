/// A01 — Splash. Logo only; session restoration happens before runApp.
import 'package:flutter/material.dart';

import '../../core/widgets/ss_logo_mark.dart';
import '../theme/ss_tokens.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(color: SsColors.brandPrimary),
        child: SafeArea(child: Center(child: SsLogoMark(size: 96))),
      ),
    );
  }
}
