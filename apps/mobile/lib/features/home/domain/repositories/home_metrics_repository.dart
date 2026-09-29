import '../models/home_dashboard_view_model.dart';

abstract interface class HomeMetricsRepository {
  Future<HomeAccountMetrics> getMetrics();
}
