import '../../domain/repositories/auth_repository.dart';

enum AuthMockScenario {
  success,
  invalidCredentials,
  emailNotVerified,
  rateLimited,
  serverError,
  offlineLike,
}

enum _AuthOperation {
  signIn,
  register,
  verifyEmail,
  resendVerification,
  forgotPassword,
  logout,
}

class MockAuthRepository implements AuthRepository {
  const MockAuthRepository({
    required this.scenario,
    this.latency = const Duration(milliseconds: 160),
  });

  final AuthMockScenario scenario;
  final Duration latency;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) {
    return _respond(_AuthOperation.signIn);
  }

  @override
  Future<void> register({
    required String email,
    required String password,
  }) {
    return _respond(_AuthOperation.register);
  }

  @override
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) {
    return _respond(_AuthOperation.verifyEmail);
  }

  @override
  Future<void> resendVerification({required String email}) {
    return _respond(_AuthOperation.resendVerification);
  }

  @override
  Future<void> forgotPassword({required String email}) {
    return _respond(_AuthOperation.forgotPassword);
  }

  @override
  Future<void> logout() {
    return _respond(_AuthOperation.logout);
  }

  Future<void> _respond(_AuthOperation operation) async {
    await Future<void>.delayed(latency);

    switch (scenario) {
      case AuthMockScenario.success:
        return;
      case AuthMockScenario.invalidCredentials:
        if (operation == _AuthOperation.signIn) {
          throw const AuthException(AuthFailureCode.invalidCredentials);
        }
        return;
      case AuthMockScenario.emailNotVerified:
        if (operation == _AuthOperation.signIn) {
          throw const AuthException(AuthFailureCode.emailNotVerified);
        }
        return;
      case AuthMockScenario.rateLimited:
        throw const AuthException(AuthFailureCode.rateLimited);
      case AuthMockScenario.serverError:
        throw const AuthException(AuthFailureCode.server);
      case AuthMockScenario.offlineLike:
        throw const AuthException(AuthFailureCode.offlineLike);
    }
  }
}
