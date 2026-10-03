/// A12 — Add first creator.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../channels/domain/models/watch_summary.dart';
import '../../channels/presentation/controllers/watch_providers.dart';

class AddFirstCreatorScreen extends ConsumerStatefulWidget {
  const AddFirstCreatorScreen({super.key});

  @override
  ConsumerState<AddFirstCreatorScreen> createState() =>
      _AddFirstCreatorScreenState();
}

class _AddFirstCreatorScreenState extends ConsumerState<AddFirstCreatorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _sourceController = TextEditingController(
    text: '@linastudio',
  );
  bool _submitting = false;
  Object? _error;

  @override
  void dispose() {
    _sourceController.dispose();
    super.dispose();
  }

  String get _handle {
    final String raw = _sourceController.text.trim();
    final Uri? uri = Uri.tryParse(raw);
    final String source =
        uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : raw;
    final String username = source.replaceFirst('@', '');
    return '@' + (username.isEmpty ? 'creator' : username);
  }

  String get _displayName {
    final String username = _handle.replaceFirst('@', '');
    return username
        .split(RegExp(r'[_\-.]+'))
        .where((String part) => part.isNotEmpty)
        .map(
          (String part) =>
              part.substring(0, 1).toUpperCase() + part.substring(1),
        )
        .join(' ');
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final String raw = _sourceController.text.trim();
    final WatchSourceType type =
        raw.startsWith('http://') || raw.startsWith('https://')
        ? WatchSourceType.url
        : WatchSourceType.username;

    try {
      final WatchSummary created = await ref
          .read(watchControllerProvider)
          .createWatch(
            CreateWatchCommand(
              sourceType: type,
              sourceValue: raw,
              autoRecord: false,
              notifyOnLive: true,
            ),
          );
      if (!mounted) return;
      context.go(
        AppRoutes.firstCreatorAddedLocation(
          name: created.creatorDisplayName,
          handle: created.creatorUsername,
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SsSpacing.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      l10n.addFirstCreatorTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: SsSpacing.sm),
                    Text(l10n.addFirstCreatorBody),
                    const SizedBox(height: SsSpacing.xl),
                    Wrap(
                      spacing: SsSpacing.sm,
                      runSpacing: SsSpacing.sm,
                      children: <Widget>[
                        SsStatusChip(
                          label: l10n.tiktokSupportedLabel,
                          icon: Icons.music_note_rounded,
                          tone: SsStatusTone.success,
                        ),
                        SsStatusChip(label: l10n.douyinComingSoonLabel),
                      ],
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: SsSpacing.lg),
                      SsAsyncErrorState(error: _error!, onRetry: _submit),
                    ],
                    const SizedBox(height: SsSpacing.lg),
                    SsTextField(
                      label: l10n.onboardingCreatorSourceLabel,
                      hintText: l10n.channelSourceHint,
                      controller: _sourceController,
                      prefixIcon: Icons.alternate_email_rounded,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => setState(() {}),
                      validator: (String? value) {
                        final String source = value?.trim() ?? '';
                        if (source.isEmpty) {
                          return l10n.channelSourceRequired;
                        }
                        if (source.contains(' ') || source == '@') {
                          return l10n.channelSourceInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: SsSpacing.lg),
                    AnimatedBuilder(
                      animation: _sourceController,
                      builder: (BuildContext context, Widget? child) {
                        return SsCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: SsSpacing.sm),
                                  Text(
                                    l10n.creatorFoundLabel,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                ],
                              ),
                              const SizedBox(height: SsSpacing.md),
                              SsListTile(
                                title: _displayName,
                                subtitle: _handle + ' · TikTok',
                                leading: SsAvatar(label: _displayName),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: SsSpacing.lg),
                    SsInlineAlert(
                      title: l10n.responsibleUseReminderTitle,
                      message: l10n.responsibleUseReminderBody,
                      tone: SsInlineAlertTone.info,
                    ),
                    const SizedBox(height: SsSpacing.xl),
                    SsPrimaryButton(
                      label: l10n.addAndFollowAction,
                      isLoading: _submitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
