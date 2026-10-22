/// ASuspended · ATerminated — sign-in was refused with ACCOUNT_SUSPENDED or
/// ACCOUNT_TERMINATED (the server's details carry the reason and case
/// reference). Shown signed out; "Sign out" returns to Sign in.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/app_config_provider.dart';
import '../../../core/external_links.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import 'account_parts.dart';

class AccountSuspendedScreen extends ConsumerWidget {
  const AccountSuspendedScreen({
    this.reason = '',
    this.reference = '',
    super.key,
  });

  final String reason;
  final String reference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppConfig config = ref.watch(appConfigProvider);
    return SsV2Page(
      child: SsV2StatusBody(
        glyph: SsV2IconGlyph.shield,
        tone: SsV2TileTone.warning,
        title: l10n.sysSuspendedTitle,
        body: reference.isEmpty
            ? l10n.sysSuspendedBody
            : l10n.sysSuspendedBodyRef(reference),
        extra: Column(
          children: ssV2Gap(<Widget>[
            if (reason.isNotEmpty)
              AccountFootnote(
                key: const ValueKey<String>('suspended-reason'),
                text: l10n.sysStatusReason(reason),
              ),
            AccountFootnote(text: l10n.sysAppeals(AppConfig.supportEmail)),
          ], 8),
        ),
        actions: <Widget>[
          SsV2Button(
            key: const ValueKey<String>('suspended-aup'),
            label: l10n.sysReadAup,
            variant: SsV2ButtonVariant.outlined,
            onPressed: () => openExternalUrl(config.acceptableUseUrl),
          ),
          SsV2Button(
            key: const ValueKey<String>('suspended-appeal'),
            label: l10n.sysAppealByEmail,
            onPressed: () => openMail(
              AppConfig.supportEmail,
              subject: reference.isEmpty
                  ? l10n.sysAppealSubject
                  : '${l10n.sysAppealSubject} $reference',
            ),
          ),
          SsV2Button(
            key: const ValueKey<String>('suspended-sign-out'),
            label: l10n.acSignOut,
            variant: SsV2ButtonVariant.text,
            onPressed: () => context.go(AppRoutes.signIn),
          ),
        ],
      ),
    );
  }
}

class AccountClosedScreen extends ConsumerWidget {
  const AccountClosedScreen({this.reason = '', super.key});

  final String reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppConfig config = ref.watch(appConfigProvider);
    return SsV2Page(
      child: SsV2StatusBody(
        glyph: SsV2IconGlyph.close,
        tone: SsV2TileTone.error,
        title: l10n.sysTerminatedTitle,
        body: l10n.sysTerminatedBody,
        extra: Column(
          children: ssV2Gap(<Widget>[
            if (reason.isNotEmpty)
              AccountFootnote(text: l10n.sysStatusReason(reason)),
            AccountFootnote(text: l10n.sysMistake(AppConfig.supportEmail)),
          ], 8),
        ),
        actions: <Widget>[
          SsV2Button(
            key: const ValueKey<String>('closed-terms'),
            label: l10n.sysReadTerms,
            variant: SsV2ButtonVariant.outlined,
            onPressed: () => openExternalUrl(config.termsOfUseUrl),
          ),
          SsV2Button(
            key: const ValueKey<String>('closed-sign-out'),
            label: l10n.acSignOut,
            variant: SsV2ButtonVariant.text,
            onPressed: () => context.go(AppRoutes.signIn),
          ),
        ],
      ),
    );
  }
}
