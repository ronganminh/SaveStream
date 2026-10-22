import 'package:flutter/foundation.dart';

import '../../../../app/session/app_session_controller.dart';
import '../../../../core/legal/legal_consent.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository repository,
    required AppSessionController session,
  }) : _repository = repository,
       _session = session;

  final AuthRepository _repository;
  final AppSessionController _session;

  bool _isLoading = false;
  bool _socialInProgress = false;
  bool _socialCancelled = false;
  AuthFailureCode? _failure;
  AccountStatusDetails? _accountStatus;

  bool get isLoading => _isLoading;

  /// The server's details when sign-in was refused for a suspended or
  /// closed account.
  AccountStatusDetails? get accountStatus => _accountStatus;

  /// True while a Google/Apple sign-in is running (the full-screen state).
  bool get socialInProgress => _socialInProgress;
  AuthFailureCode? get failure => _failure;

  /// Leave the Google sign-in screen. If the provider still finishes, the
  /// new session is signed out again so Cancel really cancels.
  void cancelSocial() {
    if (!_socialInProgress) return;
    _socialCancelled = true;
    _socialInProgress = false;
    _isLoading = false;
    _failure = null;
    notifyListeners();
  }

  void clearFailure() {
    if (_failure == null) return;
    _failure = null;
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    _start();
    try {
      await _repository.signIn(email: email, password: password);
      _finish();
      _session.markAuthenticated();
      return true;
    } on AuthException catch (error) {
      if (error.code == AuthFailureCode.emailNotVerified) {
        _session.setPendingVerificationEmail(email);
      }
      _accountStatus = error.accountStatus;
      _fail(error.code);
      return false;
    }
  }

  Future<bool> signInSocial(
    SocialAuthProvider provider, {
    LegalConsent? consent,
  }) async {
    _start();
    _socialInProgress = true;
    _socialCancelled = false;
    notifyListeners();
    try {
      final repository = _repository;
      if (repository is! SocialAuthRepository) {
        throw const AuthException(AuthFailureCode.socialUnavailable);
      }
      await (repository as SocialAuthRepository).signInSocial(
        provider,
        consent: consent,
      );
      if (_socialCancelled) {
        _socialCancelled = false;
        try {
          await _repository.logout();
        } on AuthException {
          // Local credentials are cleared by logout even if revoke fails.
        }
        return false;
      }
      _socialInProgress = false;
      _finish();
      _session.markAuthenticated();
      return true;
    } on AuthException catch (error) {
      final bool cancelledByUser = _socialCancelled;
      _socialCancelled = false;
      _socialInProgress = false;
      if (cancelledByUser || error.code == AuthFailureCode.cancelled) {
        _finish();
        return false;
      }
      _accountStatus = error.accountStatus;
      _fail(error.code);
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required LegalConsent consent,
  }) async {
    _start();
    try {
      await _repository.register(
        email: email,
        password: password,
        consent: consent,
      );
      _session.setPendingVerificationEmail(email);
      _finish();
      return true;
    } on AuthException catch (error) {
      _fail(error.code);
      return false;
    }
  }

  Future<bool> verifyEmail({required String token}) async {
    _start();
    try {
      await _repository.verifyEmail(token: token);
      _session.clearPendingVerificationEmail();
      _finish();
      return true;
    } on AuthException catch (error) {
      _fail(error.code);
      return false;
    }
  }

  Future<bool> resendVerification({required String email}) async {
    _start();
    try {
      await _repository.resendVerification(email: email);
      _finish();
      return true;
    } on AuthException catch (error) {
      _fail(error.code);
      return false;
    }
  }

  Future<bool> forgotPassword({required String email}) async {
    _start();
    try {
      await _repository.forgotPassword(email: email);
      _finish();
      return true;
    } on AuthException catch (error) {
      _fail(error.code);
      return false;
    }
  }

  Future<bool> resetPassword({
    required String token,
    required String password,
  }) async {
    _start();
    try {
      await _repository.resetPassword(token: token, password: password);
      _finish();
      return true;
    } on AuthException catch (error) {
      _fail(error.code);
      return false;
    }
  }

  Future<void> logout() async {
    _start();
    try {
      await _repository.logout();
      _finish();
      _session.markUnauthenticated();
    } on AuthException catch (error) {
      _fail(error.code);
    }
  }

  void _start() {
    _isLoading = true;
    _failure = null;
    notifyListeners();
  }

  void _finish() {
    _isLoading = false;
    _failure = null;
    notifyListeners();
  }

  void _fail(AuthFailureCode code) {
    _isLoading = false;
    _failure = code;
    notifyListeners();
  }
}
