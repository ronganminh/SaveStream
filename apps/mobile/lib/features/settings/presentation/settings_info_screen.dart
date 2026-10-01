import 'package:flutter/material.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';

class SettingsInfoScreen extends StatelessWidget {
  const SettingsInfoScreen({
    required this.title,
    required this.message,
    required this.icon,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(SsSpacing.xl),
            child: SsCard(
              child: SsEmptyState(icon: icon, title: title, message: message),
            ),
          ),
        ),
      ),
    );
  }
}
