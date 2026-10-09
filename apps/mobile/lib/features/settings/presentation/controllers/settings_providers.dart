import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session/app_session_controller.dart';
import '../../../../core/mock/mock_providers.dart';
import '../../../auth/data/auth_providers.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../data/repositories/mock_profile_repository.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>(
      (ref) => MockProfileRepository(ref.watch(mockBehaviorProvider)),
    );

final profileProvider = FutureProvider.autoDispose<UserProfile>((ref) {
  return ref.watch(profileRepositoryProvider).getProfile();
});

final settingsAccountControllerProvider =
    Provider.family<SettingsAccountController, AppSessionController>(
      (ref, session) => SettingsAccountController(
        repository: ref.watch(authRepositoryProvider),
        session: session,
      ),
    );

class SettingsAccountController {
  const SettingsAccountController({
    required AuthRepository repository,
    required AppSessionController session,
  }) : _repository = repository,
       _session = session;

  final AuthRepository _repository;
  final AppSessionController _session;

  Future<void> logout() async {
    await _repository.logout();
    _session.markUnauthenticated();
  }

  Future<void> deleteAccount() async {
    await _repository.deleteAccount();
    _session.markUnauthenticated();
  }
}
