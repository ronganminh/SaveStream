import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/api/api_providers.dart';
import '../../../../platform/platform_providers.dart';
import '../../../auth/data/current_user_id_source.dart';
import '../../../local_recordings/data/local_file_index.dart';
import '../../../local_recordings/domain/models/local_recording_models.dart';
import '../../../local_recordings/presentation/controllers/local_recording_controller.dart';
import '../../domain/models/recording_summary.dart';
import '../models/recording_library_item.dart';
import 'recording_providers.dart';

final FutureProvider<bool> foreignLocalRecordingOwnershipProvider =
    FutureProvider<bool>((Ref ref) async {
      if (!Platform.isAndroid && !Platform.isIOS) {
        return false;
      }
      final String userId = await CurrentUserIdSource(
        apiClient: ref.watch(apiClientProvider),
      ).get();
      final Directory support = await getApplicationSupportDirectory();
      return LocalFileIndex(
        root: Directory('${support.path}/local_recordings'),
      ).hasRecordingsOwnedByOtherUsers(userId: userId);
    });

final FutureProvider<List<RecordingLibraryItem>> recordingLibraryProvider =
    FutureProvider<List<RecordingLibraryItem>>((Ref ref) async {
      final String currentDeviceId = await ref
          .watch(deviceInfoServiceProvider)
          .deviceId;
      final List<RecordingSummary> cloud = await ref
          .watch(recordingRepositoryProvider)
          .listRecordings();
      final List<LocalRecordingSummary> local = await ref
          .watch(localRecordingRepositoryProvider)
          .list();

      final List<RecordingLibraryItem> items = <RecordingLibraryItem>[
        ...cloud.map(libraryItemFromCloud),
        ...local.map(
          (LocalRecordingSummary item) =>
              libraryItemFromLocal(item, currentDeviceId: currentDeviceId),
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

final localRecordingLibraryDetailProvider =
    FutureProvider.family<LocalRecordingSummary?, String>((
      Ref ref,
      String id,
    ) async {
      final List<LocalRecordingSummary> items = await ref
          .watch(localRecordingRepositoryProvider)
          .list();
      for (final LocalRecordingSummary item in items) {
        if (item.id == id) return item;
      }
      return null;
    });
