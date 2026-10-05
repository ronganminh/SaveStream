/// S03 — Device storage for Local recordings only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/platform_providers.dart';
import '../../local_recordings/domain/models/local_recording_models.dart';
import '../../v2_foundation/v2_foundation_providers.dart';

class DeviceStorageSnapshot {
  const DeviceStorageSnapshot({
    required this.freeBytes,
    required this.localBytes,
    required this.localCount,
  });

  final int freeBytes;
  final int localBytes;
  final int localCount;
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
      );
    });

class DeviceStorageScreen extends ConsumerWidget {
  const DeviceStorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DeviceStorageSnapshot> value = ref.watch(
      deviceStorageSnapshotProvider,
    );

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
