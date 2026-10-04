import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/platform_providers.dart';
import '../../local_recordings/domain/models/local_recording_models.dart';
import '../../local_recordings/presentation/controllers/local_recording_controller.dart';
import 'controllers/recording_library_controller.dart';

/// L06 — Local recording detail.
class LocalRecordingDetailScreen extends ConsumerWidget {
  const LocalRecordingDetailScreen({required this.recordingId, super.key});

  final String recordingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LocalRecordingSummary?> recording = ref.watch(
      localRecordingLibraryDetailProvider(recordingId),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.recordingDetailTitle)),
      body: SafeArea(
        child: recording.when(
          loading: () => const _LocalDetailSkeleton(),
          error: (Object error, StackTrace stackTrace) => Center(
            child: SsAsyncErrorState(
              error: error,
              onRetry: () => ref.invalidate(
                localRecordingLibraryDetailProvider(recordingId),
              ),
            ),
          ),
          data: (LocalRecordingSummary? value) {
            if (value == null) {
              return Center(
                child: SsEmptyState(
                  title: context.l10n.recordingNotFoundTitle,
                  message: context.l10n.recordingNotFoundBody,
                ),
              );
            }
            return _LocalDetailBody(recording: value);
          },
        ),
      ),
    );
  }
}

class _LocalDetailBody extends ConsumerWidget {
  const _LocalDetailBody({required this.recording});

  final LocalRecordingSummary recording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String>(
      future: ref.watch(deviceInfoServiceProvider).deviceId,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        final bool sameDevice = snapshot.data == recording.deviceId;
        final bool available = recording.fileAvailable;
        return ListView(
          padding: const EdgeInsets.all(SsSpacing.lg),
          children: <Widget>[
            SsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          recording.creatorDisplayName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      SsLocationChip(
                        engine: Engine.local,
                        label: context.l10n.localLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: SsSpacing.sm),
                  Text(recording.creatorHandle),
                  const SizedBox(height: SsSpacing.md),
                  Text(recording.deviceName),
                  const SizedBox(height: SsSpacing.sm),
                  Text(formatDuration(recording.recordedSeconds)),
                  Text(formatBytes(recording.sizeBytes)),
                ],
              ),
            ),
            if (!sameDevice) ...<Widget>[
              const SizedBox(height: SsSpacing.md),
              SsInlineAlert(
                title: context.l10n.recordingNotFoundTitle,
                message: context.l10n.recordingCrossDeviceUnavailable,
                tone: SsInlineAlertTone.warning,
              ),
            ] else if (!available) ...<Widget>[
              const SizedBox(height: SsSpacing.md),
              SsInlineAlert(
                title: context.l10n.recordingNotFoundTitle,
                message: context.l10n.recordingLocalFileMissing,
                tone: SsInlineAlertTone.warning,
              ),
            ],
            if (sameDevice && available) ...<Widget>[
              const SizedBox(height: SsSpacing.lg),
              SsPrimaryButton(
                label: context.l10n.playRecordingAction,
                icon: Icons.play_arrow_rounded,
                onPressed: () {},
              ),
              const SizedBox(height: SsSpacing.sm),
              SsSecondaryButton(
                label: context.l10n.shareRecordingAction,
                icon: Icons.ios_share_rounded,
                onPressed: recording.filePath == null
                    ? null
                    : () => ref.read(shareServiceProvider).shareFile(
                          filePath: recording.filePath!,
                          displayName: recording.creatorDisplayName,
                        ),
              ),
              const SizedBox(height: SsSpacing.sm),
              TextButton.icon(
                onPressed: () async {
                  await ref
                      .read(localRecordingRepositoryProvider)
                      .delete(recording.id, deviceId: recording.deviceId);
                  ref.invalidate(localRecordingLibraryDetailProvider(recording.id));
                  ref.invalidate(recordingLibraryProvider);
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(context.l10n.deleteLocalRecordingAction),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LocalDetailSkeleton extends StatelessWidget {
  const _LocalDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(height: 180, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 56, radius: SsRadii.md),
      ],
    );
  }
}
