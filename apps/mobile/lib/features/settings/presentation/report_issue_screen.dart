/// S12 — Report issue.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/presentation/entitlement_providers.dart';

class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _includeDiagnostics = true;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final bool online = ref.read(appOnlineProvider).value ?? true;
    SsSnackbar.show(
      context,
      online
          ? context.l10n.reportIssueSentToast
          : context.l10n.reportIssueQueuedToast,
    );
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.reportIssueTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SsSpacing.lg),
        children: <Widget>[
          TextField(
            controller: _controller,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: context.l10n.reportIssuePrompt,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: SsSpacing.md),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _includeDiagnostics,
            onChanged: (bool value) =>
                setState(() => _includeDiagnostics = value),
            title: Text(context.l10n.reportDiagnosticsTitle),
            subtitle: Text(context.l10n.reportDiagnosticsBody),
          ),
          const SizedBox(height: SsSpacing.lg),
          SsPrimaryButton(
            label: _sending
                ? context.l10n.processingLabel
                : context.l10n.sendAction,
            onPressed: _sending ? null : _submit,
          ),
        ],
      ),
    );
  }
}
