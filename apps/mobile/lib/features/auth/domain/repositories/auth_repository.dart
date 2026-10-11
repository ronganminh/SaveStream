enum SocialAuthProvider { google, apple }

abstract interface class SocialAuthRepository {
  Future<void> signInSocial(SocialAuthProvider provider);
}

abstract interface class SocialLinkFeedback {
  /// Read and reset the last provider-link warning after password sign-in.
  bool consumeSocialLinkFailure();
}

enum AuthFailureCode {
  invalidCredentials,
  accountLinkRequired,
  socialUnavailable,
  cancelled,
  emailNotVerified,
  invalidToken,
  validation,
  rateLimited,
  sessionExpired,
  server,
  offlineLike,
}

class AuthException implements Exception {
  const AuthException(this.code);

  final AuthFailureCode code;
}

abstract interface class AuthRepository {
  Future<void> signIn({required String email, required String password});

  Future<void> register({required String email, required String password});

  Future<void> verifyEmail({required String token});

  Future<void> resendVerification({required String email});

  Future<void> forgotPassword({required String email});

  Future<void> resetPassword({required String token, required String password});

  Future<void> logout();

  Future<void> deleteAccount();
}
