import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../platform/platform_providers.dart';
import '../../../local_recordings/domain/models/local_recording_models.dart';
import '../../../local_recordings/presentation/controllers/local_recording_controller.dart';
import '../../domain/models/recording_summary.dart';
import 'recording_providers.dart';
import '../models/recording_library_item.dart';

final FutureProvider<List<RecordingLibraryItem>> recordingLibraryProvider =
    FutureProvider<List<RecordingLibraryItem>>((Ref ref) async {
      final String currentDeviceId =
          await ref.watch(deviceInfoServiceProvider).deviceId;
      final List<RecordingSummary> cloud =
          await ref.watch(recordingRepositoryProvider).listRecordings();
      final List<LocalRecordingSummary> local =
          await ref.watch(localRecordingRepositoryProvider).list();

      final List<RecordingLibraryItem> items = <RecordingLibraryItem>[
        ...cloud.map(libraryItemFromCloud),
        ...local.map(
          (LocalRecordingSummary item) => libraryItemFromLocal(
            item,
            currentDeviceId: currentDeviceId,
          ),
        ),
      ];

      items.sort((RecordingLibraryItem a, RecordingLibraryItem b) {
        final DateTime aDate =
            a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final DateTime bDate =
            b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        return bDate.compareTo(aDate);
      });
      return List<RecordingLibraryItem>.unmodifiable(items);
    });
