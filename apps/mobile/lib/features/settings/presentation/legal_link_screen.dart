import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';

class LegalLinkScreen extends StatelessWidget {
  const LegalLinkScreen({
    required this.title,
    required this.url,
    required this.openLabel,
    super.key,
  });

  final String title;
  final Uri url;
  final String openLabel;

  Future<void> _open(BuildContext context) async {
    final bool opened = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(url.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SsSpacing.lg),
          child: SsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(url.toString()),
                const SizedBox(height: SsSpacing.lg),
                SsPrimaryButton(
                  label: openLabel,
                  icon: Icons.open_in_new_rounded,
                  onPressed: () => _open(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
