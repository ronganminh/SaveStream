import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/app_status/presentation/a6_app_status_providers.dart';
import '../../features/entitlement/presentation/entitlement_providers.dart';
import '../../features/local_recordings/presentation/recording_platform_bridge.dart';
import '../../features/recordings/presentation/active_recording_bar.dart';
import '../../l10n/l10n.dart';
import '../router/app_routes.dart';

class MainShell extends ConsumerWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final double width = MediaQuery.sizeOf(context).width;
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final bool compactFab = width < 360 || textScale >= 1.4;
    final NavigationDestinationLabelBehavior navigationLabelBehavior =
        textScale >= 1.4
        ? NavigationDestinationLabelBehavior.alwaysHide
        : width < 440
        ? NavigationDestinationLabelBehavior.onlyShowSelected
        : NavigationDestinationLabelBehavior.alwaysShow;
    final String location = GoRouterState.of(context).matchedLocation;
    final List<ActiveRecordingBarItem> activeRecordings = ref.watch(
      activeRecordingBarItemsProvider,
    );
    final bool hideRecordingBar = activeRecordings.any(
      (ActiveRecordingBarItem item) => item.route == location,
    );
    final bool isOnline = ref.watch(appOnlineProvider).value ?? true;
    final A6GlobalGate gate =
        ref.watch(a6GlobalGateProvider).value ?? A6GlobalGate.none;

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

    return Scaffold(
      body: Column(
        children: <Widget>[
          if (!isOnline)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
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
          Expanded(child: RecordingPlatformBridge(child: navigationShell)),
        ],
      ),
      floatingActionButton: compactFab
          ? FloatingActionButton(
              tooltip: l10n.addChannelAction,
              onPressed: () => context.push(AppRoutes.addChannel),
              child: const Icon(Icons.add_rounded),
            )
          : FloatingActionButton.extended(
              tooltip: l10n.addChannelAction,
              onPressed: () => context.push(AppRoutes.addChannel),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addChannelAction),
            ),
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!hideRecordingBar && activeRecordings.isNotEmpty)
              ActiveRecordingBar(items: activeRecordings),
            NavigationBar(
              height: textScale >= 1.4 ? 64 : null,
              labelBehavior: navigationLabelBehavior,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (int index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
              destinations: <NavigationDestination>[
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: l10n.navHome,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.visibility_outlined),
                  selectedIcon: const Icon(Icons.visibility_rounded),
                  label: l10n.navChannels,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.video_library_outlined),
                  selectedIcon: const Icon(Icons.video_library_rounded),
                  label: l10n.navRecordings,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings_rounded),
                  label: l10n.navSettings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
