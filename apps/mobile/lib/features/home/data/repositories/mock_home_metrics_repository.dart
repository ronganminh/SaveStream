import '../../../../core/mock/mock_repository_base.dart';
import '../../domain/models/home_dashboard_view_model.dart';
import '../../domain/repositories/home_metrics_repository.dart';

final class MockHomeMetricsRepository extends MockRepositoryBase
    implements HomeMetricsRepository {
  const MockHomeMetricsRepository(super.behavior);

  @override
  Future<HomeAccountMetrics> getMetrics() {
    return respond<HomeAccountMetrics>(
      success: () => const HomeAccountMetrics(
        displayName: 'Alex',
        availableCredit: 5,
        recordingHoursUsed: 12.6,
        recordingHoursLimit: 50,
      ),
      empty: () => const HomeAccountMetrics(
        displayName: 'Alex',
        availableCredit: 0,
        recordingHoursUsed: 0,
        recordingHoursLimit: 50,
      ),
    );
  }
}
