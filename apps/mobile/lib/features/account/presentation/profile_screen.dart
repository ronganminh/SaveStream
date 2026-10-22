/// AProfile — display name (PATCH /v1/me), the sign-in email and how this
/// device signs in (password → the reset flow; Google → nothing to change).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_settings_controller.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../credits/presentation/credits_v2_parts.dart' show showCreditsToast;
import '../../settings/domain/models/user_profile.dart';
import '../../settings/presentation/controllers/settings_providers.dart';
import 'account_parts.dart';

/// The server's display_name limit.
const int _maxDisplayName = 160;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({required this.settings, super.key});

  final AppSettingsController settings;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  UserProfile? _loaded;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _fill(UserProfile profile) {
    if (_loaded != null) return;
    _loaded = profile;
    _name.text = profile.displayName ?? '';
    _email.text = profile.email;
  }

  bool get _changed =>
      _loaded != null && _name.text.trim() != (_loaded!.displayName ?? '');

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final UserProfile updated = await ref
          .read(profileRepositoryProvider)
          .updateDisplayName(_name.text);
      _loaded = updated;
      ref.invalidate(profileProvider);
      if (mounted) showCreditsToast(context, l10n.acProfileSaved);
    } on Object {
      if (mounted) showCreditsToast(context, l10n.acProfileSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<UserProfile> profile = ref.watch(profileProvider);
    final UserProfile? data = profile.value ?? _loaded;
    if (data != null) _fill(data);

    return SsV2Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsV2Header(
            onBack: () => accountBack(context),
            title: l10n.profileTitle,
          ),
          Expanded(
            child: data == null
                ? (profile.hasError
                      ? _ProfileError(
                          onRetry: () => ref.invalidate(profileProvider),
                        )
                      : const Center(child: SsV2Spinner()))
                : SsV2FillScroll(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    gap: 18,
                    children: <Widget>[
                      Center(
                        child: SsV2Avatar(
                          name: data.displayName ?? data.email,
                          size: 88,
                          fontSize: 31,
                          brand: true,
                        ),
                      ),
                      SsV2TextField(
                        fieldKey: const ValueKey<String>('profile-name'),
                        label: l10n.acDisplayName,
                        controller: _name,
                        maxLength: _maxDisplayName,
                        textInputAction: TextInputAction.done,
                        autofillHints: const <String>[AutofillHints.name],
                        onChanged: (_) => setState(() {}),
                      ),
                      // The server can't change the sign-in email yet.
                      SsV2TextField(
                        fieldKey: const ValueKey<String>('profile-email'),
                        label: l10n.emailLabel,
                        controller: _email,
                        readOnly: true,
                        helperText: l10n.acEmailReadOnlyNote,
                      ),
                      _SignInMethodCard(
                        method: widget.settings.signInMethod,
                        email: data.email,
                      ),
                      const Spacer(),
                      SsV2Button(
                        key: const ValueKey<String>('profile-save'),
                        label: l10n.acSaveChanges,
                        isLoading: _saving,
                        // Nothing changed: back, as there is nothing to save.
                        onPressed: _changed
                            ? _save
                            : () => accountBack(context),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SignInMethodCard extends StatelessWidget {
  const _SignInMethodCard({required this.method, required this.email});

  final SignInMethod? method;
  final String email;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final bool google = method == SignInMethod.google;
    return SsV2Card(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  google ? l10n.acSignInMethod : l10n.acPassword,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  google ? l10n.acSignedInWithGoogle : l10n.acSignedInWithEmail,
                  style: TextStyle(fontSize: 13, color: palette.textMuted),
                ),
              ],
            ),
          ),
          if (!google) ...<Widget>[
            const SizedBox(width: 12),
            SsV2Button(
              key: const ValueKey<String>('profile-change-password'),
              label: l10n.acChange,
              variant: SsV2ButtonVariant.outlined,
              size: SsV2ButtonSize.small,
              expand: false,
              // The existing reset flow: a link to this email.
              onPressed: () =>
                  context.push(AppRoutes.forgotPasswordLocation(email: email)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsV2Banner(
            tone: SsV2Tone.error,
            child: Text(l10n.acProfileLoadFailed),
          ),
          const SizedBox(height: 16),
          SsV2Button(
            label: l10n.sysTryAgain,
            variant: SsV2ButtonVariant.outlined,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
