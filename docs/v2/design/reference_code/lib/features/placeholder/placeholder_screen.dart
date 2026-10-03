import 'package:flutter/material.dart';

import '../../theme/ss_theme.dart';
import '../../widgets/widgets.dart';

/// Route đã nối nhưng UI chưa dựng. Tra ID trong docs/SCREENS.md + design/*.dc.html.
class SsPlaceholderScreen extends StatelessWidget {
  const SsPlaceholderScreen({super.key, required this.ids, required this.title, required this.location});
  final String ids, title, location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          SsAppBar(title: title, variant: SsAppBarVariant.compact),
          Expanded(
            child: Center(
              child: SsEmptyState(
                icon: Icons.construction_rounded,
                title: ids,
                body: 'Chưa dựng UI. Xem docs/SCREENS.md mục $ids.\nRoute: $location',
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
