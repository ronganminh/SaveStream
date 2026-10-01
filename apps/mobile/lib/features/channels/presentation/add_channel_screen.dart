import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/mock/mock_repository_base.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/watch_summary.dart';
import 'controllers/watch_providers.dart';

class AddChannelScreen extends ConsumerStatefulWidget {
  const AddChannelScreen({super.key});

  @override
  ConsumerState<AddChannelScreen> createState() => _AddChannelScreenState();
}

class _AddChannelScreenState extends ConsumerState<AddChannelScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _sourceController = TextEditingController();

  bool _autoRecord = true;
  bool _confirmedPermission = false;
  bool _showPermissionError = false;
  bool _isSubmitting = false;
  Object? _error;

  @override
  void dispose() {
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final bool formValid = _formKey.currentState!.validate();

    setState(() {
      _showPermissionError = !_confirmedPermission;
      _error = null;
    });

    if (!formValid || !_confirmedPermission) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final String rawSource = _sourceController.text.trim();
    final WatchSourceType sourceType =
        rawSource.startsWith('http://') || rawSource.startsWith('https://')
        ? WatchSourceType.url
        : WatchSourceType.username;

    try {
      final WatchSummary created = await ref
          .read(watchControllerProvider)
          .createWatch(
            CreateWatchCommand(
              sourceType: sourceType,
              sourceValue: rawSource,
              autoRecord: _autoRecord,
            ),
          );
      if (mounted) {
        context.go(AppRoutes.channelDetail(created.id));
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addChannelTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SsSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      l10n.addChannelHeading,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: SsSpacing.sm),
                    Text(l10n.addChannelBody),
                    const SizedBox(height: SsSpacing.xl),
                    if (_error != null) ...<Widget>[
                      SsErrorState(
                        title: _errorTitle(l10n, _error!),
                        message: _errorMessage(l10n, _error!),
                        retryLabel: l10n.retryAction,
                        onRetry: _submit,
                      ),
                      const SizedBox(height: SsSpacing.lg),
                    ],
                    SsTextField(
                      label: l10n.channelSourceLabel,
                      hintText: l10n.channelSourceHint,
                      controller: _sourceController,
                      prefixIcon: Icons.alternate_email_rounded,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
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
                    SsCard(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _autoRecord,
                        title: Text(l10n.autoRecordTitle),
                        subtitle: Text(l10n.autoRecordDescription),
                        onChanged: _isSubmitting
                            ? null
                            : (bool value) {
                                setState(() {
                                  _autoRecord = value;
                                });
                              },
                      ),
                    ),
                    const SizedBox(height: SsSpacing.lg),
                    SsCard(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _confirmedPermission,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(l10n.channelPermissionConfirmation),
                        onChanged: _isSubmitting
                            ? null
                            : (bool? value) {
                                setState(() {
                                  _confirmedPermission = value ?? false;
                                  if (_confirmedPermission) {
                                    _showPermissionError = false;
                                  }
                                });
                              },
                      ),
                    ),
                    if (_showPermissionError) ...<Widget>[
                      const SizedBox(height: SsSpacing.sm),
                      Text(
                        l10n.channelPermissionRequired,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: SsSpacing.xl),
                    SsPrimaryButton(
                      label: l10n.addAndMonitorAction,
                      icon: Icons.add_rounded,
                      isLoading: _isSubmitting,
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

String _errorTitle(AppLocalizations l10n, Object error) {
  if (_isOfflineLike(error)) {
    return l10n.offlineErrorTitle;
  }
  return l10n.errorTitle;
}

String _errorMessage(AppLocalizations l10n, Object error) {
  if (_isOfflineLike(error)) {
    return l10n.offlineErrorBody;
  }
  if (error is ApiException && error.kind == ApiExceptionKind.conflict) {
    return l10n.watchAlreadyExistsMessage;
  }
  return l10n.errorBody;
}

bool _isOfflineLike(Object error) {
  return (error is MockRepositoryException &&
          error.kind == MockFailureKind.offlineLike) ||
      (error is ApiException &&
          (error.kind == ApiExceptionKind.network ||
              error.kind == ApiExceptionKind.timeout));
}
