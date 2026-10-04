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

  static const String introWatchDetect = '/onboarding/intro/watch-detect';
  static const String introLocalCloud = '/onboarding/intro/local-cloud';
  static const String onboardingNotifications = '/onboarding/notifications';
  static const String onboardingAndroidPermission =
      '/onboarding/android-permission';
  static const String onboardingIosLimits = '/onboarding/ios-limits';
  static const String onboardingAddCreator = '/onboarding/add-creator';
  static const String onboardingCreatorAdded = '/onboarding/creator-added';

  static const String home = '/home';
  static const String channels = '/channels';
  static const String addChannel = '/channels/add';
  static const String recordings = '/recordings';
  static const String localRecovery = '/recordings/recovery';
  static const String credits = '/credits';
  static const String billing = '/billing';
  static const String billingReturn = '/billing/return';

  static const String settings = '/settings';
  static const String profile = '/settings/profile';
  static const String language = '/settings/language';
  static const String theme = '/settings/theme';
  static const String notifications = '/settings/notifications';
  static const String androidRecordingGuide = '/settings/recording/android';
  static const String androidOemRecordingGuide =
      '/settings/recording/android/oem';
  static const String iosRecordingGuide = '/settings/recording/ios';
  static const String privacy = '/settings/privacy';
  static const String terms = '/settings/terms';

  static const String componentGallery = '/dev/components';

  static String channelDetail(String id) => '/channels/' + id;
  static String autoRecordSettings(String id) =>
      '/channels/' + id + '/auto-record';
  static String recordingDetail(String id) => '/recordings/' + id;
  static String localRecording(String watchId) =>
      '/recordings/local/' + watchId;

  static String liveNotification(String id, {String state = 'checking'}) {
    return Uri(
      path: '/live/' + id,
      queryParameters: <String, String>{'state': state},
    ).toString();
  }

  static String checkEmailLocation(String email) {
    return Uri(
      path: checkEmail,
      queryParameters: <String, String>{'email': email},
    ).toString();
  }

  static String verifyEmailLocation({String? token}) {
    return Uri(
      path: verifyEmail,
      queryParameters: token == null ? null : <String, String>{'token': token},
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

  static Uri billingReturnUri(String orderId) {
    return Uri(
      scheme: 'savestream',
      path: billingReturn,
      queryParameters: <String, String>{'order_id': orderId},
    );
  }
}
