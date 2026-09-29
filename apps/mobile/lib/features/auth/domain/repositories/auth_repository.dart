enum AuthFailureCode {
  invalidCredentials,
  emailNotVerified,
  rateLimited,
  server,
  offlineLike,
}

class AuthException implements Exception {
  const AuthException(this.code);

  final AuthFailureCode code;
}

abstract interface class AuthRepository {
  Future<void> signIn({
    required String email,
    required String password,
  });

  Future<void> register({
    required String email,
    required String password,
  });

  Future<void> verifyEmail({
    required String email,
    required String code,
  });

  Future<void> resendVerification({required String email});

  Future<void> forgotPassword({required String email});

  Future<void> logout();
}
