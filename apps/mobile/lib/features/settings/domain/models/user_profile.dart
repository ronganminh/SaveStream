class UserProfile {
  const UserProfile({
    required this.email,
    required this.emailVerified,
    this.displayName,
  });

  final String email;
  final bool emailVerified;
  final String? displayName;
}
