import '../models/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> getProfile();

  /// PATCH /v1/me `display_name` (null or empty clears it).
  Future<UserProfile> updateDisplayName(String? displayName);
}
