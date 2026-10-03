import 'package:flutter/material.dart';

enum SsTab { home, watch, recordings, settings }

class SsBottomNav extends StatelessWidget {
  const SsBottomNav({super.key, required this.active, required this.onSelect});
  final SsTab active;
  final ValueChanged<SsTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: active.index,
      onDestinationSelected: (i) => onSelect(SsTab.values[i]),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Trang chủ'),
        NavigationDestination(icon: Icon(Icons.visibility_outlined), selectedIcon: Icon(Icons.visibility_rounded), label: 'Theo dõi'),
        NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library_rounded), label: 'Bản ghi'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Cài đặt'),
      ],
    );
  }
}
