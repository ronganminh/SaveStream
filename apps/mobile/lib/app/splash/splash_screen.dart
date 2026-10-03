import 'package:flutter/material.dart';

import '../../core/widgets/ss_logo_mark.dart';
import '../theme/ss_tokens.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: SsColors.brandMark),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SsLogoMark(size: 96),
                const SizedBox(height: 20),
                Text(
                  'SaveStream',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colors.surface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
