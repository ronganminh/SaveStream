import 'package:flutter/foundation.dart';

import '../../../../app/session/app_session_controller.dart';
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
  AuthFailureCode? _failure;

  bool get isLoading => _isLoading;
  AuthFailureCode? get failure => _failure;

  void clearFailure() {
    if (_failure == null) {
      return;
    }
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
      _fail(error.code);
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    _start();
    try {
      await _repository.register(email: email, password: password);
      _session.setPendingVerificationEmail(email);
      _finish();
      return true;
    } on AuthException catch (error) {
      _fail(error.code);
      return false;
    }
  }

  Future<bool> verifyEmail({
    required String email,
    required String code,
  }) async {
    _start();
    try {
      await _repository.verifyEmail(email: email, code: code);
      _session.clearPendingVerificationEmail();
      _finish();
      _session.markAuthenticated();
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
