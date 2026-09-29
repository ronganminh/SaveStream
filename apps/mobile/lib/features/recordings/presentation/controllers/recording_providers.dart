import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_providers.dart';
import '../../data/repositories/mock_recording_repository.dart';
import '../../domain/models/recording_summary.dart';
import '../../domain/repositories/recording_repository.dart';

final Provider<RecordingRepository> recordingRepositoryProvider =
    Provider<RecordingRepository>(
      (ref) => MockRecordingRepository(ref.watch(mockBehaviorProvider)),
    );

final FutureProvider<List<RecordingSummary>> recordingListProvider =
    FutureProvider<List<RecordingSummary>>(
      (ref) => ref.watch(recordingRepositoryProvider).listRecordings(),
    );

final recordingDetailProvider =
    FutureProvider.family<RecordingSummary?, String>(
      (ref, id) => ref.watch(recordingRepositoryProvider).getRecording(id),
    );
