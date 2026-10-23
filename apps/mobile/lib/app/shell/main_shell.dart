import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config_provider.dart';
import '../../core/widgets/savestream_widgets.dart';
import '../../core/widgets/v2/ss_v2_widgets.dart';
import '../../features/app_status/presentation/system_screens.dart';
import '../../features/app_status/presentation/system_status_providers.dart';
import '../../features/entitlement/presentation/entitlement_providers.dart';
import '../../features/recordings/presentation/active_recording_bar.dart';
import '../../features/store/presentation/a5_purchase_controller.dart';
import '../../l10n/l10n.dart';
import '../router/app_routes.dart';
import '../session/app_session_controller.dart';

class MainShell extends ConsumerWidget {
  const MainShell({
    required this.navigationShell,
    required this.session,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final AppSessionController session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String location = GoRouterState.of(context).matchedLocation;
    final List<ActiveRecordingBarItem> activeRecordings = ref.watch(
      activeRecordingBarItemsProvider,
    );
    // Home already shows each recording in its "Live now" card, the
    // Channels list and channel screens show it on the channel itself, and
    // the Recordings library shows it as a REC card.
    final bool hideRecordingBar =
        location == AppRoutes.home ||
        location == AppRoutes.recordings ||
        location == AppRoutes.channels ||
        location.startsWith('${AppRoutes.channels}/') ||
        activeRecordings.any(
          (ActiveRecordingBarItem item) => item.route == location,
        );
    // Signed in: finish any Google Play purchase that was paid but not
    // credited (or not consumed) on an earlier run.
    ref.watch(purchaseRecoveryProvider);
    final bool isOnline = ref.watch(appOnlineProvider).value ?? true;
    final SystemStatus status =
        ref.watch(systemStatusProvider).value ?? SystemStatus.open;
    ref.listen<AsyncValue<bool>>(appOnlineProvider, (
      AsyncValue<bool>? previous,
      AsyncValue<bool> next,
    ) {
      if (previous?.value == false && next.value == true) {
        SsSnackbar.show(context, l10n.globalReconnectedToast);
        ref.invalidate(systemStatusProvider);
      }
    });
    final bool sessionExpired = session.authStatus == AppAuthStatus.expired;

    void retryStatus() => ref.invalidate(systemStatusProvider);

    // Full-screen system states (v2 artboards), most blocking first. They
    // cover the shell, which stays mounted so the tabs keep their place.
    final Widget? systemScreen = switch (status.gate) {
      SystemGate.updateRequired => ForceUpdateScreen(
        installedVersion: status.installedVersion,
        requiredVersion: status.requiredVersion,
      ),
      SystemGate.maintenance => MaintenanceScreen(
        eta: status.maintenanceEta,
        statusPageUrl: ref.watch(appConfigProvider).statusPageUrl,
        onRetry: retryStatus,
      ),
      SystemGate.serverError => ServerErrorScreen(
        requestId: status.requestId,
        onRetry: retryStatus,
      ),
      SystemGate.none when !isOnline => OfflineScreen(
        onRetry: () {
          ref.invalidate(appOnlineProvider);
          retryStatus();
        },
      ),
      SystemGate.none => null,
    };

    final Widget shellBody = navigationShell;

    final Widget shell = Scaffold(
      body: Stack(
        children: <Widget>[
          shellBody,
          if (sessionExpired)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(
                  context,
                ).colorScheme.scrim.withValues(alpha: 0.72),
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: SsCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Icon(
                                Icons.lock_clock_rounded,
                                size: 48,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.sessionExpiredTitle,
                                style: Theme.of(context).textTheme.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.sessionExpiredBody,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              SsPrimaryButton(
                                label: l10n.signInAgainAction,
                                onPressed: () => context.push(AppRoutes.signIn),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!hideRecordingBar && activeRecordings.isNotEmpty)
              ActiveRecordingBar(items: activeRecordings),
            SsV2BottomNav(
              selectedIndex: navigationShell.currentIndex,
              onSelected: (int index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
              items: <SsV2NavItem>[
                SsV2NavItem(
                  id: 'home',
                  label: l10n.v2NavHome,
                  glyph: SsV2IconGlyph.home,
                ),
                SsV2NavItem(
                  id: 'channels',
                  label: l10n.v2NavChannels,
                  glyph: SsV2IconGlyph.channels,
                ),
                SsV2NavItem(
                  id: 'recordings',
                  label: l10n.v2NavRecordings,
                  glyph: SsV2IconGlyph.recordings,
                ),
                SsV2NavItem(
                  id: 'account',
                  label: l10n.v2NavAccount,
                  glyph: SsV2IconGlyph.person,
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final bool covered = systemScreen != null;
    // One tree shape either way, so the shell is never remounted.
    return Stack(
      children: <Widget>[
        ExcludeSemantics(
          excluding: covered,
          child: IgnorePointer(ignoring: covered, child: shell),
        ),
        if (covered) Positioned.fill(child: systemScreen),
      ],
    );
  }
}
