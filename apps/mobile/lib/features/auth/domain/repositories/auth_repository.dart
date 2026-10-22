import '../../../../core/legal/legal_consent.dart';

enum SocialAuthProvider { google, apple }

abstract interface class SocialAuthRepository {
  /// [consent] is sent when the user accepted the terms on the sign-up
  /// screen; the server needs it when this sign-in creates an account.
  Future<void> signInSocial(
    SocialAuthProvider provider, {
    LegalConsent? consent,
  });
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
  consentRequired,
  legalOutdated,
  invalidToken,
  validation,
  rateLimited,
  sessionExpired,
  server,
  offlineLike,

  /// Sign-in refused: the account is suspended (ACCOUNT_SUSPENDED).
  accountSuspended,

  /// Sign-in refused: the account was closed (ACCOUNT_TERMINATED).
  accountTerminated,
}

/// What the server says about a suspended or closed account.
class AccountStatusDetails {
  const AccountStatusDetails({
    this.reason = '',
    this.reference = '',
    this.email = '',
  });

  final String reason;
  final String reference;
  final String email;
}

class AuthException implements Exception {
  const AuthException(this.code, {this.accountStatus});

  final AuthFailureCode code;

  /// Set for [AuthFailureCode.accountSuspended] / [accountTerminated].
  final AccountStatusDetails? accountStatus;
}

abstract interface class AuthRepository {
  Future<void> signIn({required String email, required String password});

  Future<void> register({
    required String email,
    required String password,
    LegalConsent? consent,
  });

  Future<void> verifyEmail({required String token});

  Future<void> resendVerification({required String email});

  Future<void> forgotPassword({required String email});

  Future<void> resetPassword({required String token, required String password});

  Future<void> logout();

  Future<void> deleteAccount();
}
