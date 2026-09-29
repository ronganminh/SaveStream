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
      final List<Object> results = await Future.wait<Object>(
        <Future<Object>>[
          ref.watch(watchRepositoryProvider).listWatches(),
          ref.watch(recordingRepositoryProvider).listRecordings(),
          ref.watch(homeMetricsRepositoryProvider).getMetrics(),
        ],
        eagerError: false,
      );

      return HomeDashboardViewModel(
        metrics: results[2] as HomeAccountMetrics,
        watches: results[0] as List<WatchSummary>,
        recordings: results[1] as List<RecordingSummary>,
      );
    });
