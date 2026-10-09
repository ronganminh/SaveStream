import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/platform_providers.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../local_recordings/domain/models/local_recording_models.dart';
import '../../local_recordings/presentation/controllers/local_recording_controller.dart';
import 'controllers/recording_library_controller.dart';
import 'models/recording_library_item.dart';
import 'recording_detail_components.dart';
import 'recording_thumbnail.dart';
import 'recording_ui_helpers.dart';

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
      appBar: AppBar(title: const SizedBox.shrink()),
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
        final bool canDelete =
            sameDevice || recording.sizeBytes == 0 || !available;
        final VoidCallback? openPlayer = sameDevice && available
            ? () {
                final Uri uri =
                    Uri.parse(AppRoutes.recordingPlayer(recording.id)).replace(
                      queryParameters: <String, String>{
                        'source': 'local',
                        'title': recording.creatorDisplayName,
                        'duration': recording.recordedSeconds.toString(),
                        'started': recording.startedAt.toIso8601String(),
                      },
                    );
                context.push(uri.toString());
              }
            : null;

        Future<void> deleteRecording() async {
          final bool? confirmed = await SsConfirmDialog.show(
            context,
            title: context.l10n.deleteRecordingTitle,
            message: context.l10n.deleteRecordingMessage,
            cancelLabel: context.l10n.cancelAction,
            confirmLabel: context.l10n.deleteRecordingAction,
          );
          if (confirmed != true || !context.mounted) return;
          try {
            await ref
                .read(localRecordingRepositoryProvider)
                .delete(recording.id, deviceId: recording.deviceId);
            ref.invalidate(recordingLibraryProvider);
            if (context.mounted) context.pop();
          } on Object catch (error) {
            if (context.mounted) SsSnackbar.show(context, error.toString());
          }
        }

        return ListView(
          scrollCacheExtent: const ScrollCacheExtent.pixels(800),
          padding: const EdgeInsets.fromLTRB(
            SsSpacing.lg,
            SsSpacing.xs,
            SsSpacing.lg,
            SsSpacing.xxl,
          ),
          children: <Widget>[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: RecordingThumbnail(
                recordingId: recording.id,
                storage: RecordingLibraryStorage.local,
                filePath: recording.filePath,
                enabled: sameDevice && available,
                borderRadius: SsRadii.lg,
                onTap: openPlayer,
              ),
            ),
            const SizedBox(height: SsSpacing.md),
            RecordingDetailHeading(
              name: recording.creatorDisplayName,
              startedAt: recording.startedAt,
              durationSeconds: recording.recordedSeconds,
              sizeBytes: recording.sizeBytes,
              status: recording.status,
              engine: Engine.local,
            ),
            const SizedBox(height: SsSpacing.md),
            if (sameDevice && available)
              SsInlineAlert(
                title: context.l10n.recordingLocalOnlyTitle,
                message: context.l10n.recordingLocalOnlyBody(
                  recording.deviceName,
                ),
                icon: Icons.smartphone_rounded,
              )
            else if (!sameDevice)
              SsInlineAlert(
                title: context.l10n.recordingNotFoundTitle,
                message: context.l10n.recordingCrossDeviceUnavailable,
                tone: SsInlineAlertTone.warning,
              )
            else
              SsInlineAlert(
                title: context.l10n.recordingNotFoundTitle,
                message: context.l10n.recordingLocalFileMissing,
                tone: SsInlineAlertTone.warning,
              ),
            const SizedBox(height: SsSpacing.md),
            RecordingDetailInfoCard(
              rows: <RecordingDetailInfoRow>[
                RecordingDetailInfoRow(
                  context.l10n.recordingStorageLabel,
                  context.l10n.recordingLocalStorageValue(recording.deviceName),
                ),
                RecordingDetailInfoRow(
                  context.l10n.recordingQualityLabel,
                  context.l10n.recordingQualitySourceValue,
                ),
                RecordingDetailInfoRow(
                  context.l10n.recordingSizeLabel,
                  formatBytes(recording.sizeBytes),
                ),
                RecordingDetailInfoRow(
                  context.l10n.recordingStartedByLabel,
                  context.l10n.recordingStartedManuallyValue,
                ),
              ],
            ),
            const SizedBox(height: SsSpacing.md),
            RecordingDetailActions(
              actions: <RecordingDetailActionData>[
                RecordingDetailActionData(
                  label: context.l10n.playRecordingAction,
                  icon: Icons.play_arrow_rounded,
                  onPressed: openPlayer,
                ),
                RecordingDetailActionData(
                  label: context.l10n.shareRecordingAction,
                  icon: Icons.ios_share_rounded,
                  onPressed:
                      sameDevice && available && recording.filePath != null
                      ? () => ref
                            .read(shareServiceProvider)
                            .shareFile(
                              filePath: recording.filePath!,
                              displayName: recording.creatorDisplayName,
                            )
                      : null,
                ),
                RecordingDetailActionData(
                  label: context.l10n.deleteAction,
                  icon: Icons.delete_outline_rounded,
                  destructive: true,
                  onPressed: canDelete ? deleteRecording : null,
                ),
              ],
            ),
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
