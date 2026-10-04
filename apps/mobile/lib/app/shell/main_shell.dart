import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final bool compactNavigation = width < 440 || textScale >= 1.4;
    final String location = GoRouterState.of(context).matchedLocation;
    final List<ActiveRecordingBarItem> activeRecordings = ref.watch(
      activeRecordingBarItemsProvider,
    );
    final bool hideRecordingBar = activeRecordings.any(
      (ActiveRecordingBarItem item) => item.route == location,
    );

    return Scaffold(
      body: navigationShell,
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!hideRecordingBar && activeRecordings.isNotEmpty)
            ActiveRecordingBar(items: activeRecordings),
          NavigationBar(
            labelBehavior: compactNavigation
                ? NavigationDestinationLabelBehavior.onlyShowSelected
                : NavigationDestinationLabelBehavior.alwaysShow,
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
    );
  }
}
