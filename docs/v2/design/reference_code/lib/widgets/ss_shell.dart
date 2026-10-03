import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_state.dart';
import 'ss_bottom_nav.dart';
import 'ss_misc.dart';
import 'ss_recording_bar.dart';

/// StatefulShellRoute builder: SsOfflineBanner (G01) + tab + SsRecordingBar + SsBottomNav.
class SsShell extends StatelessWidget {
  const SsShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        ValueListenableBuilder(
          valueListenable: isOnline,
          builder: (_, online, __) => online ? const SizedBox.shrink() : const SafeArea(bottom: false, child: SsOfflineBanner()),
        ),
        Expanded(child: shell),
      ]),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        ListenableBuilder(
          listenable: recorder,
          builder: (context, _) => recorder.isActive
              ? SsRecordingBar(
                  recordings: [recorder.active!],
                  onTap: () => context.push('/recording/${recorder.active!.sessionId}'),
                )
              : const SizedBox.shrink(),
        ),
        SsBottomNav(
          active: SsTab.values[shell.currentIndex],
          onSelect: (t) => shell.goBranch(t.index, initialLocation: t.index == shell.currentIndex),
        ),
      ]),
    );
  }
}
