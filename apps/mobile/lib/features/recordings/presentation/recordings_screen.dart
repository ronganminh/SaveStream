import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/mock/mock_repository_base.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/recording_summary.dart';
import 'controllers/recording_providers.dart';

class RecordingsScreen extends ConsumerWidget {
  const RecordingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<RecordingSummary>> recordings = ref.watch(
      recordingListProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recordingsTitle)),
      body: SafeArea(
        child: recordings.when(
          loading: () => Center(child: SsLoadingView(label: l10n.loadingLabel)),
          error: (Object error, StackTrace stackTrace) => SsErrorState(
            title: _errorTitle(l10n, error),
            message: _errorMessage(l10n, error),
            retryLabel: l10n.retryAction,
            onRetry: () => ref.invalidate(recordingListProvider),
          ),
          data: (List<RecordingSummary> items) {
            if (items.isEmpty) {
              return SsEmptyState(
                title: l10n.emptyRecordingsTitle,
                message: l10n.emptyRecordingsBody,
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(SsSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: SsSpacing.md),
              itemBuilder: (BuildContext context, int index) {
                final RecordingSummary recording = items[index];
                return SsCard(
                  child: SsListTile(
                    title: recording.creatorDisplayName,
                    subtitle: recording.creatorUsername,
                    leading: SsAvatar(label: recording.creatorDisplayName),
                    trailing: SsStatusChip(
                      label: recordingStatusLabel(l10n, recording.status),
                      tone: recordingStatusTone(recording.status),
                    ),
                    onTap: () =>
                        context.push(AppRoutes.recordingDetail(recording.id)),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String recordingStatusLabel(AppLocalizations l10n, RecordingStatus status) {
  return switch (status) {
    RecordingStatus.queued => l10n.recordingStatusQueued,
    RecordingStatus.resolving => l10n.recordingStatusResolving,
    RecordingStatus.waitingLive => l10n.recordingStatusWaitingLive,
    RecordingStatus.recording => l10n.recordingStatusRecording,
    RecordingStatus.processing => l10n.recordingStatusProcessing,
    RecordingStatus.uploading => l10n.recordingStatusUploading,
    RecordingStatus.completed => l10n.recordingStatusCompleted,
    RecordingStatus.failed => l10n.recordingStatusFailed,
    RecordingStatus.stopRequested => l10n.recordingStatusStopRequested,
    RecordingStatus.stopped => l10n.recordingStatusStopped,
  };
}

SsStatusTone recordingStatusTone(RecordingStatus status) {
  return switch (status) {
    RecordingStatus.recording => SsStatusTone.recording,
    RecordingStatus.completed => SsStatusTone.success,
    RecordingStatus.failed => SsStatusTone.error,
    RecordingStatus.stopRequested => SsStatusTone.warning,
    RecordingStatus.stopped => SsStatusTone.warning,
    RecordingStatus.queued ||
    RecordingStatus.resolving ||
    RecordingStatus.waitingLive ||
    RecordingStatus.processing ||
    RecordingStatus.uploading => SsStatusTone.neutral,
  };
}

String _errorTitle(AppLocalizations l10n, Object error) {
  if (error is MockRepositoryException &&
      error.kind == MockFailureKind.offlineLike) {
    return l10n.offlineErrorTitle;
  }
  return l10n.errorTitle;
}

String _errorMessage(AppLocalizations l10n, Object error) {
  if (error is MockRepositoryException &&
      error.kind == MockFailureKind.offlineLike) {
    return l10n.offlineErrorBody;
  }
  return l10n.errorBody;
}
