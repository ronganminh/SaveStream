import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/mock/mock_repository_base.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/user_profile.dart';
import 'controllers/settings_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<UserProfile> profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: SafeArea(
        child: profile.when(
          loading: () => const _ProfileSkeleton(),
          error: (Object error, StackTrace stackTrace) => Center(
            child: SsErrorState(
              title: _errorTitle(l10n, error),
              message: _errorMessage(l10n, error),
              retryLabel: l10n.retryAction,
              onRetry: () => ref.invalidate(profileProvider),
            ),
          ),
          data: (UserProfile data) => ListView(
            padding: const EdgeInsets.all(SsSpacing.lg),
            children: <Widget>[
              SsCard(
                child: Column(
                  children: <Widget>[
                    SsAvatar(
                      label: data.displayName ?? data.email,
                      radius: 36,
                    ),
                    const SizedBox(height: SsSpacing.md),
                    Text(
                      data.displayName ?? l10n.profileFallbackName,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: SsSpacing.xs),
                    Text(
                      data.email,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: SsSpacing.md),
                    SsStatusChip(
                      label: data.emailVerified
                          ? l10n.profileEmailVerified
                          : l10n.profileEmailUnverified,
                      tone: data.emailVerified
                          ? SsStatusTone.success
                          : SsStatusTone.warning,
                      icon: data.emailVerified
                          ? Icons.verified_outlined
                          : Icons.mark_email_unread_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SsSpacing.lg),
              SsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _ProfileRow(
                      label: l10n.emailLabel,
                      value: data.email,
                    ),
                    const Divider(),
                    _ProfileRow(
                      label: l10n.profileVerificationLabel,
                      value: data.emailVerified
                          ? l10n.profileVerifiedValue
                          : l10n.profileUnverifiedValue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SsSpacing.md),
              Text(
                l10n.profileManagedByBackendBody,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label)),
          const SizedBox(width: SsSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(height: 220, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.lg),
        SsSkeleton(height: 140, radius: SsRadii.lg),
      ],
    );
  }
}

String _errorTitle(AppLocalizations l10n, Object error) {
  if (error is MockRepositoryException &&
      error.kind == MockFailureKind.offlineLike) {
    return l10n.offlineErrorTitle;
  }
  return l10n.errorTitle;
}

String _errorMessage(AppLocalizations l10n, Object error) {
  if (error is MockRepositoryException &&
      error.kind == MockFailureKind.offlineLike) {
    return l10n.offlineErrorBody;
  }
  return l10n.errorBody;
}
