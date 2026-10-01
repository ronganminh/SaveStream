import '../../domain/models/user_profile.dart';

UserProfile userProfileFromJson(Object? json) {
  if (json is! Map) {
    throw const FormatException('Expected user profile response object.');
  }

  final Object? email = json['email'];
  final Object? emailVerified = json['email_verified'];
  final Object? displayName = json['display_name'];

  if (email is! String ||
      email.trim().isEmpty ||
      emailVerified is! bool ||
      (displayName != null && displayName is! String)) {
    throw const FormatException('Malformed user profile response.');
  }

  final String? normalizedDisplayName = displayName is String
      ? displayName.trim()
      : null;

  return UserProfile(
    email: email.trim(),
    emailVerified: emailVerified,
    displayName: normalizedDisplayName == null || normalizedDisplayName.isEmpty
        ? null
        : normalizedDisplayName,
  );
}
