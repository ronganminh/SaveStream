import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../entitlement/domain/models/entitlement.dart';
import '../../domain/models/recording_summary.dart';
import '../models/recording_library_item.dart';
import 'recording_providers.dart';

/// The recordings library lists cloud recordings only.
final FutureProvider<List<RecordingLibraryItem>> recordingLibraryProvider =
    FutureProvider<List<RecordingLibraryItem>>((Ref ref) async {
      final List<RecordingSummary> cloud = await ref
          .watch(recordingRepositoryProvider)
          .listRecordings();

      final List<RecordingLibraryItem> items = cloud
          .where((RecordingSummary item) => item.engine == Engine.cloud)
          .map(libraryItemFromCloud)
          .toList();

      items.sort((RecordingLibraryItem a, RecordingLibraryItem b) {
        final DateTime aDate =
            a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final DateTime bDate =
            b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        return bDate.compareTo(aDate);
      });
      return List<RecordingLibraryItem>.unmodifiable(items);
    });
