import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/report_repository.dart';

export '../../app_status/presentation/system_status_providers.dart'
    show appVersionProvider;

/// Production overrides this with [ApiReportRepository] at bootstrap.
final Provider<ReportRepository> reportRepositoryProvider =
    Provider<ReportRepository>((Ref ref) => const MockReportRepository());
