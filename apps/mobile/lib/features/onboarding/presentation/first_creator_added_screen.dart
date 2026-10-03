/// A13 — First creator added.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_settings_controller.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

class FirstCreatorAddedScreen extends StatelessWidget {
  const FirstCreatorAddedScreen({
    required this.settings,
    required this.creatorName,
    required this.creatorHandle,
    super.key,
  });

  final AppSettingsController settings;
  final String creatorName;
  final String creatorHandle;

  Future<void> _finish(BuildContext context, String route) async {
    await settings.markIntroCompleted();
    if (context.mounted) {
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SsSpacing.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: SsSpacing.xl),
                  Text(
                    l10n.firstCreatorAddedTitle(creatorName),
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SsSpacing.sm),
                  Text(
                    l10n.firstCreatorAddedBody(creatorName),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SsSpacing.xl),
                  SsCard(
                    child: SsListTile(
                      title: creatorName,
                      subtitle: l10n.firstCreatorFollowingValue(
                        creatorHandle,
                        1,
                        3,
                      ),
                      leading: SsAvatar(label: creatorName),
                      trailing: SsStatusChip(label: l10n.offlineStatus),
                    ),
                  ),
                  const SizedBox(height: SsSpacing.xxl),
                  SsPrimaryButton(
                    label: l10n.goHomeAction,
                    onPressed: () => _finish(context, AppRoutes.home),
                  ),
                  const SizedBox(height: SsSpacing.sm),
                  SsSecondaryButton(
                    label: l10n.addAnotherCreatorAction,
                    onPressed: () => _finish(context, AppRoutes.addChannel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
