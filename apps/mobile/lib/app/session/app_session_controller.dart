import 'package:flutter/foundation.dart';

enum AppAuthStatus { authenticated, unauthenticated, expired }

class AppSessionController extends ChangeNotifier {
  AppSessionController({
    bool hasCompletedOnboarding = true,
    AppAuthStatus authStatus = AppAuthStatus.authenticated,
  }) : _hasCompletedOnboarding = hasCompletedOnboarding,
       _authStatus = authStatus;

  bool _hasCompletedOnboarding;
  AppAuthStatus _authStatus;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  AppAuthStatus get authStatus => _authStatus;
  bool get isAuthenticated => _authStatus == AppAuthStatus.authenticated;

  void completeOnboarding() {
    if (_hasCompletedOnboarding) {
      return;
    }
    _hasCompletedOnboarding = true;
    notifyListeners();
  }

  void signInForPreview() {
    if (_authStatus == AppAuthStatus.authenticated) {
      return;
    }
    _authStatus = AppAuthStatus.authenticated;
    notifyListeners();
  }

  void signOutForPreview() {
    if (_authStatus == AppAuthStatus.unauthenticated) {
      return;
    }
    _authStatus = AppAuthStatus.unauthenticated;
    notifyListeners();
  }

  void expireSessionForPreview() {
    if (_authStatus == AppAuthStatus.expired) {
      return;
    }
    _authStatus = AppAuthStatus.expired;
    notifyListeners();
  }
}
