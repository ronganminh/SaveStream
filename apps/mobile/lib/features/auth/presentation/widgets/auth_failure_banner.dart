import 'package:flutter/material.dart';

import '../../../../app/theme/ss_tokens.dart';
import '../../../../core/widgets/savestream_widgets.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthFailureBanner extends StatelessWidget {
  const AuthFailureBanner({
    required this.failure,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final AuthFailureCode failure;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String message = switch (failure) {
      AuthFailureCode.invalidCredentials => l10n.invalidCredentialsMessage,
      AuthFailureCode.emailNotVerified => l10n.emailNotVerifiedMessage,
      AuthFailureCode.rateLimited => l10n.rateLimitedMessage,
      AuthFailureCode.server => l10n.authServerErrorMessage,
      AuthFailureCode.offlineLike => l10n.offlineErrorBody,
    };

    return SsCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: colors.error),
          const SizedBox(width: SsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(message),
                if (actionLabel != null) ...<Widget>[
                  const SizedBox(height: SsSpacing.sm),
                  TextButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
