import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_providers.dart';
import '../../../channels/domain/models/watch_summary.dart';
import '../../../channels/presentation/controllers/watch_providers.dart';
import '../../../recordings/domain/models/recording_summary.dart';
import '../../../recordings/presentation/controllers/recording_providers.dart';
import '../../data/repositories/mock_home_metrics_repository.dart';
import '../../domain/models/home_dashboard_view_model.dart';
import '../../domain/repositories/home_metrics_repository.dart';

final Provider<HomeMetricsRepository> homeMetricsRepositoryProvider =
    Provider<HomeMetricsRepository>(
      (ref) => MockHomeMetricsRepository(ref.watch(mockBehaviorProvider)),
    );

final FutureProvider<HomeDashboardViewModel> homeDashboardProvider =
    FutureProvider<HomeDashboardViewModel>((ref) async {
      final Future<List<WatchSummary>> watchesFuture = ref
          .watch(watchRepositoryProvider)
          .listWatches();
      final Future<List<RecordingSummary>> recordingsFuture = ref
          .watch(recordingRepositoryProvider)
          .listRecordings();
      final Future<HomeAccountMetrics> metricsFuture = ref
          .watch(homeMetricsRepositoryProvider)
          .getMetrics();

      final List<WatchSummary> watches = await watchesFuture;
      final List<RecordingSummary> recordings = await recordingsFuture;
      final HomeAccountMetrics metrics = await metricsFuture;

      return HomeDashboardViewModel(
        metrics: metrics,
        watches: watches,
        recordings: recordings,
      );
    });
