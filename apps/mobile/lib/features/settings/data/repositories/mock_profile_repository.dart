import '../../../../core/mock/mock_repository_base.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

final class MockProfileRepository extends MockRepositoryBase
    implements ProfileRepository {
  const MockProfileRepository(super.behavior);

  @override
  Future<UserProfile> getProfile() {
    return respond<UserProfile>(
      success: () => const UserProfile(
        email: 'alex@example.com',
        emailVerified: true,
        displayName: 'Alex Nguyen',
      ),
      empty: () =>
          const UserProfile(email: 'alex@example.com', emailVerified: false),
    );
  }

  @override
  Future<UserProfile> updateDisplayName(String? displayName) {
    final String? value = displayName?.trim();
    UserProfile updated() => UserProfile(
      email: 'alex@example.com',
      emailVerified: true,
      displayName: value == null || value.isEmpty ? null : value,
    );
    return respond<UserProfile>(success: updated, empty: updated);
  }
}
