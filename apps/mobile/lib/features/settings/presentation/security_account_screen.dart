/// S08 / S15 / S16 — Security, logout and account actions.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../local_recordings/presentation/controllers/local_recording_controller.dart';
import '../../recordings/presentation/active_recording_bar.dart';
import 'controllers/settings_providers.dart';

class SecurityAccountScreen extends ConsumerStatefulWidget {
  const SecurityAccountScreen({required this.session, super.key});

  final AppSessionController session;

  @override
  ConsumerState<SecurityAccountScreen> createState() =>
      _SecurityAccountScreenState();
}

class _SecurityAccountScreenState extends ConsumerState<SecurityAccountScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _logout() async {
    final controller = ref.read(localRecordingControllerProvider);
    final bool localActive =
        controller.hasActiveSession || controller.hasSecondarySession;
    final bool cloudActive = ref
        .read(activeRecordingBarItemsProvider)
        .any((ActiveRecordingBarItem item) => item.engine == Engine.cloud);
    final String message = localActive && cloudActive
        ? context.l10n.logoutLocalAndCloudRecordingWarning
        : localActive
        ? context.l10n.logoutLocalRecordingWarning
        : cloudActive
        ? context.l10n.logoutCloudRecordingWarning
        : context.l10n.logoutConfirmBody;
    final bool? confirmed = await SsConfirmDialog.show(
      context,
      title: context.l10n.logoutConfirmTitle,
      message: message,
      cancelLabel: context.l10n.cancelAction,
      confirmLabel: localActive
          ? context.l10n.logoutStopSaveAction
          : context.l10n.logoutAction,
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (controller.hasSecondarySession) {
        await controller.stopSecond();
      }
      if (controller.hasActiveSession) {
        await controller.stop();
      }
      await ref
          .read(settingsAccountControllerProvider(widget.session))
          .logout();
    } on Object {
      if (mounted) {
        setState(() => _error = context.l10n.logoutFailedBody);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.securityAccountTitle)),
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
          SsCard(
            child: Column(
              children: <Widget>[
                SsListTile(
                  title: context.l10n.profileTitle,
                  subtitle: context.l10n.securityEmailSubtitle,
                  leading: const Icon(Icons.mail_outline_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.profile),
                ),
                const Divider(),
                SsListTile(
                  title: context.l10n.securityResetPasswordTitle,
                  subtitle: context.l10n.securityResetPasswordSubtitle,
                  leading: const Icon(Icons.key_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.forgotPassword),
                ),
                const Divider(),
                SsListTile(
                  title: context.l10n.signedInDevicesTitle,
                  leading: const Icon(Icons.devices_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.signedInDevices),
                ),
              ],
            ),
          ),
          const SizedBox(height: SsSpacing.lg),
          SsSecondaryButton(
            label: _busy
                ? context.l10n.processingLabel
                : context.l10n.logoutAction,
            icon: Icons.logout_rounded,
            onPressed: _busy ? null : _logout,
          ),
          const SizedBox(height: SsSpacing.sm),
          SsTextAction(
            label: context.l10n.deleteAccountAction,
            icon: Icons.delete_forever_outlined,
            onPressed: _busy
                ? null
                : () => context.push(AppRoutes.deleteAccount),
          ),
        ],
      ),
    );
  }
}
