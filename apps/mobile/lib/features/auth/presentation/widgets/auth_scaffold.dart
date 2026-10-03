import 'package:flutter/material.dart';

import '../../../../app/theme/ss_tokens.dart';
import '../../../../core/widgets/savestream_widgets.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.showBackButton = false,
    this.onBack,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: showBackButton
          ? AppBar(leading: BackButton(onPressed: onBack))
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                SsSpacing.xl,
                SsSpacing.lg,
                SsSpacing.xl,
                SsSpacing.xxl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 440,
                    minHeight: constraints.maxHeight - SsSpacing.xxxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: SsLogoMark(size: 48),
                      ),
                      const SizedBox(height: SsSpacing.xxl),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: SsSpacing.sm),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: SsSpacing.xl),
                      child,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
