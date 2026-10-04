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
        availability: AppAvailability.available,
      ),
      empty: () => const AppStatus(
        availability: AppAvailability.maintenance,
      ),
    );
  }
}
