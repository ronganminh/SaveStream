abstract final class AppRoutes {
  static const String root = '/';
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';

  static const String signIn = '/auth/sign-in';
  static const String register = '/auth/register';
  static const String verifyEmail = '/auth/verify-email';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  static const String home = '/home';
  static const String channels = '/channels';
  static const String addChannel = '/channels/add';
  static const String recordings = '/recordings';
  static const String credits = '/credits';
  static const String billing = '/billing';
  static const String billingReturn = '/billing/return';

  static const String settings = '/settings';
  static const String profile = '/settings/profile';
  static const String language = '/settings/language';
  static const String theme = '/settings/theme';
  static const String notifications = '/settings/notifications';
  static const String privacy = '/settings/privacy';
  static const String terms = '/settings/terms';

  static const String componentGallery = '/dev/components';

  static String channelDetail(String id) => '/channels/' + id;
  static String recordingDetail(String id) => '/recordings/' + id;

  static Uri billingReturnUri(String orderId) {
    return Uri(
      scheme: 'savestream',
      path: billingReturn,
      queryParameters: <String, String>{'order_id': orderId},
    );
  }
}
