/// ADeleteAccount · ADeleteDone — the existing account deletion
/// (DELETE /v1/me, unchanged) behind a "type DELETE" confirmation, then the
/// confirmation screen shown while signed out.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../core/config/app_config_provider.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../home/presentation/home_screen.dart' show formatRecordingMinutes;
import '../../settings/presentation/controllers/settings_providers.dart';
import 'account_parts.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({required this.session, super.key});

  final AppSessionController session;

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final TextEditingController _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  bool _confirmed(AppLocalizations l10n) =>
      _confirm.text.trim().toUpperCase() == l10n.acDeleteConfirmWord;

  Future<void> _delete() async {
    final AppLocalizations l10n = context.l10n;
    final GoRouter router = GoRouter.of(context);
    final String email = ref.read(profileProvider).value?.email ?? '';
    final SettingsAccountController account = ref.read(
      settingsAccountControllerProvider(widget.session),
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await account.deleteAccount();
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l10n.deleteAccountFailed;
        });
      }
      return;
    }
    // Signed out, then the confirmation (a signed-out route).
    account.finishDeletion();
    router.go(AppRoutes.accountDeletedLocation(email));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final Entitlement? entitlement = ref.watch(entitlementProvider).value;
    // Kept loaded: the confirmation names the email.
    ref.watch(profileProvider);
    final Uri webUrl = ref.watch(appConfigProvider).accountDeletionUrl;
    final String time = formatRecordingMinutes(
      l10n,
      entitlement?.cloudMinutesAvailable ?? 0,
    );
    final TextStyle item = TextStyle(
      fontSize: 15,
      height: 1.45,
      color: palette.text,
    );
    final List<String> items = <String>[
      l10n.acDeleteItemChannels,
      l10n.acDeleteItemRecordings,
      l10n.acDeleteItemTime(time),
      l10n.acDeleteItemProfile,
    ];

    return SsV2Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsV2Header(
            onBack: _busy ? null : () => accountBack(context),
            title: l10n.acDeleteAccount,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: ssV2Gap(<Widget>[
                SsV2Banner(
                  tone: SsV2Tone.error,
                  child: Text(
                    l10n.acDeleteWarning,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  l10n.acDeleteListTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: ssV2Gap(<Widget>[
                    for (final String text in items)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(width: 20, child: Text('•', style: item)),
                          Expanded(child: Text(text, style: item)),
                        ],
                      ),
                  ], 8),
                ),
                Text(
                  l10n.acDeletePlayNote,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: palette.textMuted,
                  ),
                ),
                SsV2TextField(
                  fieldKey: const ValueKey<String>('delete-confirm-field'),
                  label: l10n.acDeleteConfirmLabel(l10n.acDeleteConfirmWord),
                  controller: _confirm,
                  autocorrect: false,
                  enabled: !_busy,
                  onChanged: (_) => setState(() {}),
                ),
                if (_error != null)
                  SsV2Banner(tone: SsV2Tone.error, child: Text(_error!)),
                SsV2Button(
                  key: const ValueKey<String>('delete-account-confirm'),
                  label: l10n.acDeleteButton,
                  variant: SsV2ButtonVariant.danger,
                  isLoading: _busy,
                  onPressed: _confirmed(l10n) ? _delete : null,
                ),
                SsV2Button(
                  key: const ValueKey<String>('delete-account-cancel'),
                  label: l10n.v2Cancel,
                  variant: SsV2ButtonVariant.text,
                  onPressed: _busy ? null : () => accountBack(context),
                ),
                Text(
                  l10n.acDeleteWebNote('${webUrl.host}${webUrl.path}'),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: palette.textMuted,
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

/// ADeleteDone — shown signed out after DELETE /v1/me was accepted.
class AccountDeletedScreen extends StatelessWidget {
  const AccountDeletedScreen({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SsV2Page(
      child: SsV2StatusBody(
        glyph: SsV2IconGlyph.check,
        tone: SsV2TileTone.neutral,
        title: l10n.acDeletedTitle,
        body: email.isEmpty
            ? l10n.acDeletedBodyGeneric
            : l10n.acDeletedBody(email),
        actions: <Widget>[
          SsV2Button(
            key: const ValueKey<String>('account-deleted-close'),
            label: l10n.v2Close,
            onPressed: () => context.go(AppRoutes.signIn),
          ),
        ],
      ),
    );
  }
}
