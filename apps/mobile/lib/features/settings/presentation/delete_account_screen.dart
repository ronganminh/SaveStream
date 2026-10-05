/// S17 / S18 — Two-step account deletion.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/session/app_session_controller.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../local_recordings/presentation/controllers/local_recording_controller.dart';
import 'controllers/settings_providers.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({required this.session, super.key});

  final AppSessionController session;

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final TextEditingController _passwordController = TextEditingController();
  int _step = 1;
  bool _understood = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _continueToConfirmation() {
    final controller = ref.read(localRecordingControllerProvider);
    if (controller.hasActiveSession || controller.hasSecondarySession) {
      setState(() => _error = context.l10n.deleteAccountRecordingBlocked);
      return;
    }
    setState(() {
      _error = null;
      _step = 2;
    });
  }

  Future<void> _delete() async {
    final controller = ref.read(localRecordingControllerProvider);
    if (controller.hasActiveSession || controller.hasSecondarySession) {
      setState(() => _error = context.l10n.deleteAccountRecordingBlocked);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(settingsAccountControllerProvider(widget.session))
          .deleteAccount();
    } on Object {
      if (mounted) setState(() => _error = context.l10n.deleteAccountFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Entitlement> entitlement = ref.watch(entitlementProvider);
    final int cloudMinutes = entitlement.value?.cloudMinutesAvailable ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.deleteAccountTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SsSpacing.lg),
        children: <Widget>[
          if (_error != null) ...<Widget>[
            SsInlineAlert(
              title: context.l10n.errorTitle,
              message: _error!,
              tone: SsInlineAlertTone.error,
            ),
            const SizedBox(height: SsSpacing.md),
          ],
          if (_step == 1) ...<Widget>[
            SsInlineAlert(
              title: context.l10n.deleteAccountConsequencesTitle,
              message: context.l10n.deleteAccountConsequencesBody,
              tone: SsInlineAlertTone.warning,
            ),
            const SizedBox(height: SsSpacing.md),
            SsChecklist(
              items: <SsChecklistItem>[
                SsChecklistItem(label: context.l10n.deleteAccountCloudDataItem),
                SsChecklistItem(
                  label: context.l10n.deleteAccountCloudHoursItem(
                    cloudMinutes ~/ 60,
                  ),
                ),
                SsChecklistItem(
                  label: context.l10n.deleteAccountLocalFilesItem,
                ),
              ],
            ),
            const SizedBox(height: SsSpacing.lg),
            SsPrimaryButton(
              label: context.l10n.continueAction,
              onPressed: _continueToConfirmation,
            ),
          ] else ...<Widget>[
            Text(
              context.l10n.deleteAccountPermanentTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: SsSpacing.sm),
            Text(context.l10n.deleteAccountPermanentBody),
            const SizedBox(height: SsSpacing.md),
            TextField(
              controller: _passwordController,
              obscureText: true,
              autofillHints: const <String>[AutofillHints.password],
              decoration: InputDecoration(
                labelText: context.l10n.deleteAccountPasswordLabel,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: SsSpacing.md),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _understood,
              onChanged: (bool? value) =>
                  setState(() => _understood = value ?? false),
              title: Text(context.l10n.deleteAccountUnderstandCheck),
            ),
            const SizedBox(height: SsSpacing.lg),
            SsPrimaryButton(
              label: _busy
                  ? context.l10n.processingLabel
                  : context.l10n.deleteAccountPermanentAction,
              onPressed:
                  !_understood || _passwordController.text.isEmpty || _busy
                  ? null
                  : _delete,
            ),
          ],
        ],
      ),
    );
  }
}
