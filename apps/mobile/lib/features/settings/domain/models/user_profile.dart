class UserProfile {
  const UserProfile({
    required this.email,
    required this.emailVerified,
    this.displayName,
    this.id,
  });

  final String email;
  final bool emailVerified;
  final String? displayName;

  /// Server user id (`/v1/me` `id`); the Play Billing account reference is
  /// its SHA-256.
  final String? id;
}
