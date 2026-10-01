import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../router/app_routes.dart';

class MainShell extends StatelessWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool compactFab =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) >= 1.4;

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
      bottomNavigationBar: NavigationBar(
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
            icon: const Icon(Icons.rss_feed_rounded),
            selectedIcon: const Icon(Icons.rss_feed_rounded),
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
    );
  }
}
