import 'package:flutter/foundation.dart';

enum AppAuthStatus { authenticated, unauthenticated, expired }

class AppSessionController extends ChangeNotifier {
  AppSessionController({
    bool hasCompletedOnboarding = true,
    AppAuthStatus authStatus = AppAuthStatus.authenticated,
    String? pendingVerificationEmail,
  }) : _hasCompletedOnboarding = hasCompletedOnboarding,
       _authStatus = authStatus,
       _pendingVerificationEmail = pendingVerificationEmail;

  bool _hasCompletedOnboarding;
  AppAuthStatus _authStatus;
  String? _pendingVerificationEmail;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  AppAuthStatus get authStatus => _authStatus;
  bool get isAuthenticated => _authStatus == AppAuthStatus.authenticated;
  String? get pendingVerificationEmail => _pendingVerificationEmail;

  void completeOnboarding() {
    if (_hasCompletedOnboarding) {
      return;
    }
    _hasCompletedOnboarding = true;
    notifyListeners();
  }

  void markAuthenticated() {
    if (_authStatus == AppAuthStatus.authenticated) {
      return;
    }
    _authStatus = AppAuthStatus.authenticated;
    notifyListeners();
  }

  void markUnauthenticated() {
    if (_authStatus == AppAuthStatus.unauthenticated) {
      return;
    }
    _authStatus = AppAuthStatus.unauthenticated;
    notifyListeners();
  }

  void setPendingVerificationEmail(String email) {
    if (_pendingVerificationEmail == email) {
      return;
    }
    _pendingVerificationEmail = email;
    notifyListeners();
  }

  void clearPendingVerificationEmail() {
    if (_pendingVerificationEmail == null) {
      return;
    }
    _pendingVerificationEmail = null;
    notifyListeners();
  }

  void signInForPreview() => markAuthenticated();

  void signOutForPreview() => markUnauthenticated();

  void expireSessionForPreview() {
    if (_authStatus == AppAuthStatus.expired) {
      return;
    }
    _authStatus = AppAuthStatus.expired;
    notifyListeners();
  }
}
