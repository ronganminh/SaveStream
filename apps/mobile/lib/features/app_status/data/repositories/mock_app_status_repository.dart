import '../../../../core/mock/mock_repository_base.dart';
import '../../domain/models/app_status.dart';
import '../../domain/repositories/app_status_repository.dart';

final class MockAppStatusRepository extends MockRepositoryBase
    implements AppStatusRepository {
  const MockAppStatusRepository(super.behavior);

  @override
  Future<AppStatus> getStatus() {
    return respond<AppStatus>(
      success: () => const AppStatus(
        minSupportedVersion: MinimumSupportedVersion(
          android: '2.0.0',
          ios: '2.0.0',
        ),
        maintenance: MaintenanceStatus(active: false),
      ),
      empty: () => const AppStatus(
        minSupportedVersion: MinimumSupportedVersion(
          android: '2.0.0',
          ios: '2.0.0',
        ),
        maintenance: MaintenanceStatus(active: false),
      ),
    );
  }
}
