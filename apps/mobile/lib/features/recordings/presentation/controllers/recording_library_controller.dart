import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../entitlement/domain/models/entitlement.dart';
import '../../domain/models/recording_summary.dart';
import 'recording_providers.dart';

/// Every cloud recording of the account, newest first. The library filters
/// it on the device because the API filters by one status at a time.
final FutureProvider<List<RecordingSummary>> recordingLibraryProvider =
    FutureProvider<List<RecordingSummary>>((Ref ref) async {
      // Stop, delete and other mutations bump the revision.
      ref.watch(recordingRevisionProvider);
      final List<RecordingSummary> items =
          (await ref.watch(recordingRepositoryProvider).listRecordings())
              .where((RecordingSummary item) => item.engine == Engine.cloud)
              .toList();
      // Not started yet (queued, waiting for the LIVE) sorts first.
      final DateTime notStarted = DateTime.utc(9999);
      items.sort(
        (RecordingSummary a, RecordingSummary b) =>
            (b.startedAt ?? notStarted).compareTo(a.startedAt ?? notStarted),
      );
      return List<RecordingSummary>.unmodifiable(items);
    });
