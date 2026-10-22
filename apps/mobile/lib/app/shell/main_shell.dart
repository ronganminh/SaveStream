import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/savestream_widgets.dart';
import '../../core/widgets/v2/ss_v2_widgets.dart';
import '../../features/app_status/presentation/a6_app_status_providers.dart';
import '../../features/entitlement/presentation/entitlement_providers.dart';
import '../../features/recordings/presentation/active_recording_bar.dart';
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
    final bool isOnline = ref.watch(appOnlineProvider).value ?? true;
    final A6GlobalGate gate =
        ref.watch(a6GlobalGateProvider).value ?? A6GlobalGate.none;
    ref.listen<AsyncValue<bool>>(appOnlineProvider, (
      AsyncValue<bool>? previous,
      AsyncValue<bool> next,
    ) {
      if (previous?.value == false && next.value == true) {
        SsSnackbar.show(context, l10n.globalReconnectedToast);
      }
    });
    final bool sessionExpired = session.authStatus == AppAuthStatus.expired;

    if (gate != A6GlobalGate.none) {
      final bool maintenance = gate == A6GlobalGate.maintenance;
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      maintenance
                          ? Icons.construction_rounded
                          : Icons.system_update_rounded,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      maintenance
                          ? l10n.globalMaintenanceTitle
                          : l10n.globalUpdateRequiredTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      maintenance
                          ? l10n.globalMaintenanceBody
                          : l10n.globalUpdateRequiredBody,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final Widget shellBody = Column(
      children: <Widget>[
        if (!isOnline)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: SafeArea(
              bottom: false,
              child: Semantics(
                liveRegion: true,
                label: l10n.homeOfflineTitle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.cloud_off_rounded),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l10n.homeOfflineBody)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(child: navigationShell),
      ],
    );

    return Scaffold(
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
  }
}
