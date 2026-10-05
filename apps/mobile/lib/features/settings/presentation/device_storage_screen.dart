/// S03 — Device storage for Local recordings only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/platform_providers.dart';
import '../../local_recordings/domain/models/local_recording_models.dart';
import '../../local_recordings/presentation/controllers/local_recording_controller.dart';

class DeviceStorageSnapshot {
  const DeviceStorageSnapshot({
    required this.freeBytes,
    required this.localBytes,
    required this.localCount,
    required this.recordings,
  });

  final int freeBytes;
  final int localBytes;
  final int localCount;
  final List<LocalRecordingSummary> recordings;
}

final FutureProvider<DeviceStorageSnapshot> deviceStorageSnapshotProvider =
    FutureProvider<DeviceStorageSnapshot>((Ref ref) async {
      final int freeBytes = await ref
          .watch(deviceInfoServiceProvider)
          .freeStorageBytes;
      final List<LocalRecordingSummary> recordings = await ref
          .watch(localRecordingRepositoryProvider)
          .list();
      final Iterable<LocalRecordingSummary> available = recordings.where(
        (LocalRecordingSummary item) => item.fileAvailable,
      );
      return DeviceStorageSnapshot(
        freeBytes: freeBytes,
        localBytes: available.fold<int>(
          0,
          (int total, LocalRecordingSummary item) => total + item.sizeBytes,
        ),
        localCount: available.length,
        recordings: available.toList(growable: false),
      );
    });

class DeviceStorageScreen extends ConsumerWidget {
  const DeviceStorageScreen({super.key});

  Future<void> _deleteOldLocal(
    BuildContext context,
    WidgetRef ref,
    DeviceStorageSnapshot data,
  ) async {
    final DateTime cutoff = DateTime.now().subtract(const Duration(days: 30));
    final List<LocalRecordingSummary> old = data.recordings
        .where((LocalRecordingSummary item) => item.startedAt.isBefore(cutoff))
        .toList(growable: false);
    if (old.isEmpty) {
      SsSnackbar.show(context, context.l10n.deviceStorageNothingToCleanToast);
      return;
    }

    final int bytes = old.fold<int>(
      0,
      (int total, LocalRecordingSummary item) => total + item.sizeBytes,
    );
    final bool? confirmed = await SsConfirmDialog.show(
      context,
      title: context.l10n.deviceStorageDeleteOldTitle,
      message: context.l10n.deviceStorageDeleteOldBody(
        old.length,
        formatFileSize(bytes),
      ),
      cancelLabel: context.l10n.cancelAction,
      confirmLabel: context.l10n.deleteAction,
    );
    if (confirmed != true || !context.mounted) return;

    final String deviceId = await ref.read(deviceInfoServiceProvider).deviceId;
    for (final LocalRecordingSummary item in old) {
      await ref
          .read(localRecordingRepositoryProvider)
          .delete(item.id, deviceId: deviceId);
    }
    ref.invalidate(deviceStorageSnapshotProvider);
    if (context.mounted) {
      SsSnackbar.show(context, context.l10n.deviceStorageCleanedToast);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DeviceStorageSnapshot> value = ref.watch(
      deviceStorageSnapshotProvider,
    );
    final LocalRecordingController recorder = ref.watch(
      localRecordingControllerProvider,
    );
    final bool cleanupLocked =
        recorder.hasActiveSession || recorder.hasSecondarySession;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.deviceStorageTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SsSpacing.lg),
          child: value.when(
            loading: () => const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SsSkeleton(height: 132, radius: SsRadii.lg),
                SizedBox(height: SsSpacing.md),
                SsSkeleton(height: 96, radius: SsRadii.lg),
              ],
            ),
            error: (Object error, StackTrace stackTrace) => SsAsyncErrorState(
              error: error,
              onRetry: () => ref.invalidate(deviceStorageSnapshotProvider),
            ),
            data: (DeviceStorageSnapshot data) => ListView(
              children: <Widget>[
                SsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.deviceStorageFreeLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: SsSpacing.sm),
                      Text(
                        formatFileSize(data.freeBytes),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SsSpacing.md),
                SsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.deviceStorageLocalLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: SsSpacing.sm),
                      Text(
                        context.l10n.deviceStorageLocalValue(
                          data.localCount,
                          formatFileSize(data.localBytes),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SsSpacing.md),
                Text(
                  context.l10n.deviceStorageCleanupTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: SsSpacing.sm),
                SsCard(
                  child: SsListTile(
                    title: context.l10n.deviceStorageDeleteOldTitle,
                    subtitle: cleanupLocked
                        ? context.l10n.deviceStorageCleanupLockedBody
                        : context.l10n.deviceStorageDeleteOldSubtitle,
                    leading: const Icon(Icons.history_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: cleanupLocked
                        ? null
                        : () => _deleteOldLocal(context, ref, data),
                  ),
                ),
                const SizedBox(height: SsSpacing.md),
                SsInlineAlert(
                  title: context.l10n.deviceStorageScopeTitle,
                  message: context.l10n.deviceStorageScopeBody,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
