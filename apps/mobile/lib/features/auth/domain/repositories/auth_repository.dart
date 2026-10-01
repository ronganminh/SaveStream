enum AuthFailureCode {
  invalidCredentials,
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
