import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme/ss_tokens.dart';
import '../../domain/repositories/auth_repository.dart';

class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    required this.isLoading,
    required this.onProvider,
    this.showApple,
    super.key,
  });

  final bool isLoading;
  final ValueChanged<SocialAuthProvider> onProvider;

  /// Apple sign-in is offered on iOS only. Tests may override.
  final bool? showApple;

  @override
  Widget build(BuildContext context) {
    final bool appleVisible = showApple ?? Platform.isIOS;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: SsSpacing.lg),
        OutlinedButton.icon(
          onPressed: isLoading
              ? null
              : () => onProvider(SocialAuthProvider.google),
          icon: const Text('G', style: TextStyle(fontWeight: FontWeight.bold)),
          label: const Text('Continue with Google'),
        ),
        if (appleVisible) ...<Widget>[
          const SizedBox(height: SsSpacing.sm),
          OutlinedButton.icon(
            onPressed: isLoading
                ? null
                : () => onProvider(SocialAuthProvider.apple),
            icon: const Icon(Icons.apple_rounded),
            label: const Text('Continue with Apple'),
          ),
        ],
        const SizedBox(height: SsSpacing.md),
        Center(
          child: Text(
            'or continue with email',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: SsSpacing.md),
      ],
    );
  }
}
