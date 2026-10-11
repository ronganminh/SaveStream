import '../../../../core/api/api_exception.dart';
import '../../domain/repositories/auth_repository.dart';
import '../firebase_social_identity_client.dart';
import '../remote/auth_protected_api.dart';
import '../remote/auth_public_api.dart';
import '../session/auth_session_manager.dart';

final class ApiAuthRepository
    implements AuthRepository, SocialAuthRepository, SocialLinkFeedback {
  ApiAuthRepository({
    required AuthPublicApi publicApi,
    required AuthProtectedApi protectedApi,
    required AuthSessionManager sessionManager,
  }) : _publicApi = publicApi,
       _protectedApi = protectedApi,
       _sessionManager = sessionManager;

  final AuthPublicApi _publicApi;
  final AuthProtectedApi _protectedApi;
  final AuthSessionManager _sessionManager;

  String? _pendingSocialIdToken;
  bool _lastSocialLinkFailed = false;

  @override
  bool consumeSocialLinkFailure() {
    final failed = _lastSocialLinkFailed;
    _lastSocialLinkFailed = false;
    return failed;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      final tokens = await _publicApi.login(email: email, password: password);
      await _sessionManager.storeAuthenticatedTokens(tokens);
      final pendingToken = _pendingSocialIdToken;
      _pendingSocialIdToken = null;
      _lastSocialLinkFailed = false;
      if (pendingToken != null) {
        final protectedApi = _protectedApi;
        if (protectedApi is SocialLinkApi) {
          try {
            await (protectedApi as SocialLinkApi).linkSocial(
              idToken: pendingToken,
              password: password,
            );
          } on Object {
            // The password session remains valid; surface a separate warning.
            _lastSocialLinkFailed = true;
          }
        } else {
          _lastSocialLinkFailed = true;
        }
      }
    } on ApiException catch (error) {
      throw AuthException(_mapFailure(error));
    } on Object {
      throw const AuthException(AuthFailureCode.server);
    }
  }

  @override
  Future<void> signInSocial(SocialAuthProvider provider) async {
    try {
      final publicApi = _publicApi;
      if (publicApi is! SocialAuthPublicApi) {
        throw const AuthException(AuthFailureCode.socialUnavailable);
      }
      _pendingSocialIdToken = null;
      final idToken = await FirebaseSocialIdentityClient().getIdToken(provider);
      try {
        final tokens = await (publicApi as SocialAuthPublicApi).socialLogin(
          idToken: idToken,
        );
        await _sessionManager.storeAuthenticatedTokens(tokens);
      } on ApiException catch (error) {
        if (error.code == 'AUTH_ACCOUNT_LINK_REQUIRED') {
          _pendingSocialIdToken = idToken;
        }
        rethrow;
      }
    } on AuthException {
      rethrow;
    } on ApiException catch (error) {
      throw AuthException(_mapFailure(error));
    } on Object {
      throw const AuthException(AuthFailureCode.server);
    }
  }

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {
    try {
      await _publicApi.register(email: email, password: password);
    } on ApiException catch (error) {
      throw AuthException(_mapFailure(error));
    } on Object {
      throw const AuthException(AuthFailureCode.server);
    }
  }

  @override
  Future<void> verifyEmail({required String token}) async {
    try {
      await _publicApi.verifyEmail(token: token);
    } on ApiException catch (error) {
      throw AuthException(_mapFailure(error, tokenOperation: true));
    } on Object {
      throw const AuthException(AuthFailureCode.server);
    }
  }

  @override
  Future<void> resendVerification({required String email}) async {
    try {
      await _publicApi.resendVerification(email: email);
    } on ApiException catch (error) {
      throw AuthException(_mapFailure(error));
    } on Object {
      throw const AuthException(AuthFailureCode.server);
    }
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    try {
      await _publicApi.forgotPassword(email: email);
    } on ApiException catch (error) {
      throw AuthException(_mapFailure(error));
    } on Object {
      throw const AuthException(AuthFailureCode.server);
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    try {
      await _publicApi.resetPassword(token: token, password: password);
    } on ApiException catch (error) {
      throw AuthException(_mapFailure(error, tokenOperation: true));
    } on Object {
      throw const AuthException(AuthFailureCode.server);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _protectedApi.logout();
    } on Object {
      // Local logout still succeeds when the remote revoke call is unavailable.
    }

    try {
      await _sessionManager.clearLocalSession();
    } on Object {
      throw const AuthException(AuthFailureCode.server);
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _protectedApi.deleteAccount();
      await _sessionManager.clearLocalSession();
    } on ApiException catch (error) {
      throw AuthException(_mapFailure(error));
    } on AuthException {
      rethrow;
    } on Object {
      throw const AuthException(AuthFailureCode.server);
    }
  }

  AuthFailureCode _mapFailure(
    ApiException error, {
    bool tokenOperation = false,
  }) {
    if (error.code == 'AUTH_ACCOUNT_LINK_REQUIRED') {
      return AuthFailureCode.accountLinkRequired;
    }
    if (error.code == 'SOCIAL_AUTH_NOT_CONFIGURED') {
      return AuthFailureCode.socialUnavailable;
    }
    if (error.code == 'AUTH_INVALID_CREDENTIALS') {
      return AuthFailureCode.invalidCredentials;
    }
    if (error.code == 'AUTH_EMAIL_NOT_VERIFIED') {
      return AuthFailureCode.emailNotVerified;
    }
    if (error.code == 'AUTH_SESSION_REVOKED') {
      return AuthFailureCode.sessionExpired;
    }
    if (error.code == 'VALIDATION_ERROR') {
      return tokenOperation
          ? AuthFailureCode.invalidToken
          : AuthFailureCode.validation;
    }

    return switch (error.kind) {
      ApiExceptionKind.rateLimited => AuthFailureCode.rateLimited,
      ApiExceptionKind.network ||
      ApiExceptionKind.timeout => AuthFailureCode.offlineLike,
      ApiExceptionKind.unauthorized => AuthFailureCode.sessionExpired,
      _ => AuthFailureCode.server,
    };
  }
}
