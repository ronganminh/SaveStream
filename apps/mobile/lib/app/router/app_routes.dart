abstract final class AppRoutes {
  static const String root = '/';
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String onboarding = '/onboarding'; // Legacy A02 alias.

  static const String signIn = '/auth/sign-in';
  static const String register = '/auth/sign-up';
  static const String verifyEmail = '/auth/verify';
  static const String forgotPassword = '/auth/forgot';
  static const String checkEmail = '/auth/check-email';
  static const String resetPassword = '/auth/reset';

  /// Sign-in refused (ACCOUNT_SUSPENDED / ACCOUNT_TERMINATED), and the
  /// confirmation after the account was deleted. Under /auth/ so they show
  /// while signed out.
  static const String accountSuspended = '/auth/account-suspended';
  static const String accountClosed = '/auth/account-closed';
  static const String accountDeleted = '/auth/account-deleted';

  static const String introWatchDetect = '/onboarding/intro/watch-detect';
  static const String onboardingNotifications = '/onboarding/notifications';
  static const String onboardingAddCreator = '/onboarding/add-creator';
  static const String onboardingCreatorAdded = '/onboarding/creator-added';

  static const String home = '/home';
  static const String channels = '/channels';
  static const String addChannel = '/channels/add';
  static const String recordings = '/recordings';

  /// Recording time (Credits): balance, rewarded ad, Google Play packs.
  static const String usage = '/usage';

  /// Old "buy cloud hours" link; redirects to [usage].
  static const String cloudHours = '/usage/cloud-hours';
  static const String creditsHistory = '/usage/history';
  static const String purchases = '/usage/purchases';
  static const String adPrivacy = '/usage/ad-privacy';
  static const String purchaseSuccess = '/usage/purchase/success';
  static const String purchasePending = '/usage/purchase/pending';

  /// The Account tab (hub).
  static const String settings = '/settings';
  static const String profile = '/settings/profile';
  static const String language = '/settings/language';
  static const String theme = '/settings/theme';

  /// The inbox (bell on Home and Channels).
  static const String notifications = '/notifications';

  /// Per-event Push / Email switches (Settings → Notifications).
  static const String notificationPreferences = '/settings/notifications';
  static const String help = '/settings/help';

  /// Report content or request removal, and its confirmation.
  static const String report = '/settings/report';
  static const String reportSent = '/settings/report/sent';
  static const String legalHub = '/settings/legal';
  static const String deleteAccount = '/settings/delete';

  static const String componentGallery = '/dev/components';

  static String channelDetail(String id) => '/channels/' + id;
  static String channelVerify(String id) => '/channels/' + id + '/verify';
  static String autoRecordSettings(String id) =>
      '/channels/' + id + '/auto-record';
  static String recordingDetail(String id) => '/recordings/' + id;
  static String recordingPlayer(String id) => '/recordings/player/' + id;
  static String liveNotification(String id, {String state = 'checking'}) {
    return Uri(
      path: '/live/' + id,
      queryParameters: <String, String>{'state': state},
    ).toString();
  }

  static String accountStatusLocation({
    required bool closed,
    String reason = '',
    String reference = '',
  }) {
    final Map<String, String> query = <String, String>{
      if (reason.isNotEmpty) 'reason': reason,
      if (reference.isNotEmpty) 'ref': reference,
    };
    return Uri(
      path: closed ? accountClosed : accountSuspended,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  static String accountDeletedLocation(String email) {
    return Uri(
      path: accountDeleted,
      queryParameters: email.isEmpty ? null : <String, String>{'email': email},
    ).toString();
  }

  static String reportSentLocation({
    required String reference,
    required String email,
  }) {
    return Uri(
      path: reportSent,
      queryParameters: <String, String>{'ref': reference, 'email': email},
    ).toString();
  }

  static String forgotPasswordLocation({String? email}) {
    return Uri(
      path: forgotPassword,
      queryParameters: email == null || email.isEmpty
          ? null
          : <String, String>{'email': email},
    ).toString();
  }

  static String checkEmailLocation(String email) {
    return Uri(
      path: checkEmail,
      queryParameters: <String, String>{'email': email},
    ).toString();
  }

  static String verifyEmailLocation({String? token, bool sent = false}) {
    final Map<String, String> query = <String, String>{
      if (token != null) 'token': token,
      if (sent) 'sent': '1',
    };
    return Uri(
      path: verifyEmail,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  static String resetPasswordLocation({String? token}) {
    return Uri(
      path: resetPassword,
      queryParameters: token == null ? null : <String, String>{'token': token},
    ).toString();
  }

  static String firstCreatorAddedLocation({
    required String name,
    required String handle,
  }) {
    return Uri(
      path: onboardingCreatorAdded,
      queryParameters: <String, String>{'name': name, 'handle': handle},
    ).toString();
  }
}
