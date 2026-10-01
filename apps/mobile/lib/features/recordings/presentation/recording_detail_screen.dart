import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/mock/mock_repository_base.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/recording_summary.dart';
import 'controllers/recording_providers.dart';
import 'recording_ui_helpers.dart';

class RecordingDetailScreen extends ConsumerStatefulWidget {
  const RecordingDetailScreen({required this.recordingId, super.key});

  final String recordingId;

  @override
  ConsumerState<RecordingDetailScreen> createState() =>
      _RecordingDetailScreenState();
}

class _RecordingDetailScreenState extends ConsumerState<RecordingDetailScreen>
    with WidgetsBindingObserver {
  bool _isMutating = false;
  Object? _mutationError;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
    _isForeground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool foreground = state == AppLifecycleState.resumed;
    if (foreground == _isForeground) {
      return;
    }
    setState(() {
      _isForeground = foreground;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    setState(() {
      _isMutating = true;
      _mutationError = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _mutationError = error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  Future<void> _retry(RecordingSummary recording) async {
    RecordingSummary? retried;
    await _runMutation(() async {
      retried = await ref.read(recordingControllerProvider).retry(recording.id);
    });
    if (_mutationError == null &&
        retried != null &&
        retried!.id != recording.id &&
        mounted) {
      context.go(AppRoutes.recordingDetail(retried!.id));
    }
  }

  Future<void> _delete(RecordingSummary recording) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await SsConfirmDialog.show(
      context,
      title: l10n.deleteRecordingTitle,
      message: l10n.deleteRecordingMessage,
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteRecordingAction,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await _runMutation(
      () => ref.read(recordingControllerProvider).delete(recording.id),
    );
    if (_mutationError == null && mounted) {
      context.go(AppRoutes.recordings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<RecordingSummary?> recording = _isForeground
        ? ref.watch(recordingRealtimeProvider(widget.recordingId))
        : ref.watch(recordingDetailProvider(widget.recordingId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recordingDetailTitle)),
      body: SafeArea(
        child: recording.when(
          loading: () => const _RecordingDetailSkeleton(),
          error: (Object error, StackTrace stackTrace) => Center(
            child: SsErrorState(
              title: _errorTitle(l10n, error),
              message: _errorMessage(l10n, error),
              retryLabel: l10n.retryAction,
              onRetry: () =>
                  ref.invalidate(recordingDetailProvider(widget.recordingId)),
            ),
          ),
          data: (RecordingSummary? value) {
            if (value == null) {
              return Center(
                child: SsEmptyState(
                  title: l10n.recordingNotFoundTitle,
                  message: l10n.recordingNotFoundBody,
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(recordingDetailProvider(widget.recordingId));
                await ref.read(
                  recordingDetailProvider(widget.recordingId).future,
                );
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  SsSpacing.lg,
                  SsSpacing.md,
                  SsSpacing.lg,
                  SsSpacing.xxl,
                ),
                children: <Widget>[
                  _CreatorHeader(recording: value),
                  const SizedBox(height: SsSpacing.lg),
                  _LifecycleCard(recording: value),
                  if (_mutationError != null) ...<Widget>[
                    const SizedBox(height: SsSpacing.md),
                    SsErrorState(
                      title: _errorTitle(l10n, _mutationError!),
                      message: _errorMessage(l10n, _mutationError!),
                      retryLabel: l10n.retryAction,
                      onRetry: () {
                        setState(() {
                          _mutationError = null;
                        });
                      },
                    ),
                  ],
                  if (value.status == RecordingStatus.failed) ...<Widget>[
                    const SizedBox(height: SsSpacing.lg),
                    _FailureCard(recording: value),
                  ],
                  const SizedBox(height: SsSpacing.lg),
                  _MetadataCard(recording: value),
                  const SizedBox(height: SsSpacing.lg),
                  _ArtifactCard(recording: value),
                  const SizedBox(height: SsSpacing.lg),
                  _ActionsCard(
                    recording: value,
                    isMutating: _isMutating,
                    onStop: () => _runMutation(
                      () =>
                          ref.read(recordingControllerProvider).stop(value.id),
                    ),
                    onRetry: () => _retry(value),
                    onDelete: () => _delete(value),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CreatorHeader extends StatelessWidget {
  const _CreatorHeader({required this.recording});

  final RecordingSummary recording;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SsCard(
      child: Row(
        children: <Widget>[
          SsAvatar(label: recording.creatorDisplayName, radius: 28),
          const SizedBox(width: SsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  recording.creatorDisplayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: SsSpacing.xs),
                Text(
                  recording.creatorUsername,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: SsSpacing.sm),
                Text(
                  recording.id,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SsStatusChip(
            label: recordingStatusLabel(l10n, recording.status),
            tone: recordingStatusTone(recording.status),
            icon: recording.status == RecordingStatus.recording
                ? Icons.fiber_manual_record_rounded
                : null,
          ),
        ],
      ),
    );
  }
}

class _LifecycleCard extends StatelessWidget {
  const _LifecycleCard({required this.recording});

  final RecordingSummary recording;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isRecording = recording.status == RecordingStatus.recording;
    final IconData icon = _statusIcon(recording.status);

    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isRecording
                      ? colors.errorContainer
                      : colors.primaryContainer,
                  borderRadius: BorderRadius.circular(SsRadii.md),
                ),
                child: Icon(
                  icon,
                  color: isRecording
                      ? colors.onErrorContainer
                      : colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: SsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      recordingStatusLabel(l10n, recording.status),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: SsSpacing.xs),
                    Text(
                      recordingStatusDescription(l10n, recording.status),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (recording.status == RecordingStatus.recording) ...<Widget>[
            const SizedBox(height: SsSpacing.lg),
            Text(
              l10n.recordingElapsedValue(
                formatDuration(recording.durationSeconds),
              ),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: SsSpacing.xs),
            Text(
              l10n.recordingBytesValue(formatBytes(recording.bytesRecorded)),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (recording.progress != null &&
              recording.status != RecordingStatus.completed &&
              recording.status != RecordingStatus.failed &&
              recording.status != RecordingStatus.stopped) ...<Widget>[
            const SizedBox(height: SsSpacing.lg),
            LinearProgressIndicator(value: recording.progress),
            const SizedBox(height: SsSpacing.xs),
            Text(
              l10n.recordingProgressValue((recording.progress! * 100).round()),
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.recording});

  final RecordingSummary recording;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.error_outline_rounded, color: colors.error),
              const SizedBox(width: SsSpacing.sm),
              Text(
                l10n.recordingFailureTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: SsSpacing.md),
          if (recording.errorCode != null)
            Text(
              recording.errorCode!,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          if (recording.errorMessage != null) ...<Widget>[
            const SizedBox(height: SsSpacing.xs),
            Text(recording.errorMessage!),
          ],
        ],
      ),
    );
  }
}

class _MetadataCard extends StatelessWidget {
  const _MetadataCard({required this.recording});

  final RecordingSummary recording;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.recordingMetadataTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsSpacing.md),
          _DetailRow(
            label: l10n.recordingStartedLabel,
            value: recordingTimestamp(context, recording.startedAt),
          ),
          _DetailRow(
            label: l10n.recordingDurationLabel,
            value: formatDuration(recording.durationSeconds),
          ),
          _DetailRow(
            label: l10n.recordingSizeLabel,
            value: formatBytes(recording.sizeBytes ?? recording.bytesRecorded),
          ),
          _DetailRow(
            label: l10n.recordingCostLabel,
            value: formatCredits(recording.costCredits),
          ),
        ],
      ),
    );
  }
}

class _ArtifactCard extends ConsumerStatefulWidget {
  const _ArtifactCard({required this.recording});

  final RecordingSummary recording;

  @override
  ConsumerState<_ArtifactCard> createState() => _ArtifactCardState();
}

class _ArtifactCardState extends ConsumerState<_ArtifactCard> {
  bool _isOpening = false;

  Future<void> _openArtifact(
    RecordingArtifactSummary artifact, {
    required LaunchMode mode,
  }) async {
    setState(() {
      _isOpening = true;
    });
    try {
      final ArtifactDownloadUrl download = await ref
          .read(recordingControllerProvider)
          .createArtifactDownloadUrl(artifact.id);
      if (download.isExpired) {
        throw StateError('Artifact URL expired before use.');
      }
      final bool opened = await launchUrl(download.uri, mode: mode);
      if (!opened) {
        throw StateError('Unable to open artifact URL.');
      }
    } on Object {
      if (mounted) {
        SsSnackbar.show(context, context.l10n.artifactOpenFailedMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpening = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<RecordingArtifactSummary>> artifacts = ref.watch(
      recordingArtifactsProvider(widget.recording.id),
    );

    return SsCard(
      child: artifacts.when(
        loading: () => const SsSkeleton(height: 96, radius: SsRadii.md),
        error: (Object error, StackTrace stackTrace) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.recordingArtifactTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: SsSpacing.sm),
            Text(_errorMessage(l10n, error)),
            const SizedBox(height: SsSpacing.sm),
            TextButton(
              onPressed: () => ref.invalidate(
                recordingArtifactsProvider(widget.recording.id),
              ),
              child: Text(l10n.retryAction),
            ),
          ],
        ),
        data: (List<RecordingArtifactSummary> items) {
          final RecordingArtifactSummary? artifact = items.isEmpty
              ? null
              : items.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.recordingArtifactTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: SsSpacing.md),
              Wrap(
                spacing: SsSpacing.sm,
                runSpacing: SsSpacing.sm,
                children: <Widget>[
                  SsStatusChip(
                    label: artifact != null
                        ? l10n.artifactReadyLabel
                        : l10n.artifactPendingLabel,
                    tone: artifact != null
                        ? SsStatusTone.success
                        : SsStatusTone.neutral,
                    icon: Icons.inventory_2_outlined,
                  ),
                  if (artifact != null)
                    SsStatusChip(
                      label: formatBytes(artifact.sizeBytes),
                      tone: SsStatusTone.neutral,
                      icon: Icons.data_usage_rounded,
                    ),
                ],
              ),
              if (artifact != null) ...<Widget>[
                const SizedBox(height: SsSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SsSecondaryButton(
                        label: l10n.playRecordingAction,
                        icon: Icons.play_arrow_rounded,
                        onPressed: _isOpening
                            ? null
                            : () => _openArtifact(
                                artifact,
                                mode: LaunchMode.platformDefault,
                              ),
                      ),
                    ),
                    const SizedBox(width: SsSpacing.sm),
                    Expanded(
                      child: SsSecondaryButton(
                        label: l10n.downloadRecordingAction,
                        icon: Icons.download_rounded,
                        onPressed: _isOpening
                            ? null
                            : () => _openArtifact(
                                artifact,
                                mode: LaunchMode.externalApplication,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.recording,
    required this.isMutating,
    required this.onStop,
    required this.onRetry,
    required this.onDelete,
  });

  final RecordingSummary recording;
  final bool isMutating;
  final VoidCallback onStop;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<Widget> actions = <Widget>[];

    if (recording.actions.canStop) {
      actions.add(
        SsPrimaryButton(
          label: l10n.stopRecordingAction,
          icon: Icons.stop_rounded,
          isLoading: isMutating,
          onPressed: onStop,
        ),
      );
    }
    if (recording.actions.canRetry) {
      actions.add(
        SsPrimaryButton(
          label: l10n.retryRecordingAction,
          icon: Icons.replay_rounded,
          isLoading: isMutating,
          onPressed: onRetry,
        ),
      );
    }
    if (recording.actions.canDelete) {
      actions.add(
        TextButton.icon(
          onPressed: isMutating ? null : onDelete,
          icon: Icon(
            Icons.delete_outline_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          label: Text(
            l10n.deleteRecordingAction,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    if (actions.isEmpty) {
      return SsCard(
        child: Text(
          l10n.recordingNoActionsBody,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.recordingActionsTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsSpacing.md),
          for (int index = 0; index < actions.length; index++) ...<Widget>[
            actions[index],
            if (index < actions.length - 1)
              const SizedBox(height: SsSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: SsSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: SsSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingDetailSkeleton extends StatelessWidget {
  const _RecordingDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(height: 120, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 200, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 180, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 160, radius: SsRadii.lg),
      ],
    );
  }
}

IconData _statusIcon(RecordingStatus status) {
  return switch (status) {
    RecordingStatus.queued => Icons.schedule_rounded,
    RecordingStatus.resolving => Icons.search_rounded,
    RecordingStatus.waitingLive => Icons.sensors_rounded,
    RecordingStatus.recording => Icons.fiber_manual_record_rounded,
    RecordingStatus.processing => Icons.settings_rounded,
    RecordingStatus.uploading => Icons.cloud_upload_outlined,
    RecordingStatus.completed => Icons.check_circle_outline_rounded,
    RecordingStatus.failed => Icons.error_outline_rounded,
    RecordingStatus.stopRequested => Icons.stop_circle_outlined,
    RecordingStatus.stopped => Icons.stop_rounded,
  };
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
  if (error is ApiException &&
      error.kind == ApiExceptionKind.insufficientCredits) {
    return l10n.recordingInsufficientCreditMessage;
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
