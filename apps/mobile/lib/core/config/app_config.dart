import 'app_environment.dart';

class AppConfig {
  AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    Uri? privacyPolicyUrl,
    Uri? termsOfUseUrl,
    Uri? acceptableUseUrl,
  }) : privacyPolicyUrl =
           privacyPolicyUrl ?? Uri.parse('https://savestream.online/privacy'),
       termsOfUseUrl =
           termsOfUseUrl ?? Uri.parse('https://savestream.online/terms'),
       acceptableUseUrl =
           acceptableUseUrl ??
           (termsOfUseUrl ?? Uri.parse('https://savestream.online/terms'))
               .replace(path: '/acceptable-use');

  final AppEnvironment environment;
  final Uri apiBaseUrl;

  final Uri privacyPolicyUrl;
  final Uri termsOfUseUrl;

  /// Acceptable Use Policy, on the same site as the Terms of Use.
  final Uri acceptableUseUrl;

  /// Refund Policy, on the same site as the Terms of Use.
  Uri get refundPolicyUrl => termsOfUseUrl.replace(path: '/refund');

  /// A page on the website that hosts the Terms of Use.
  Uri sitePage(String path, {Map<String, String>? query}) =>
      termsOfUseUrl.replace(path: path, queryParameters: query);

  /// Copyright & Takedown Policy.
  Uri get copyrightPolicyUrl => sitePage('/copyright');

  /// The web /report form (copyright notice, or abuse with [abuse]).
  Uri reportFormUrl({bool abuse = false}) => sitePage(
    '/report',
    query: abuse ? const <String, String>{'type': 'abuse'} : null,
  );

  /// A help center article (savestream.online/help/<slug>).
  Uri helpArticleUrl(String slug) => sitePage('/help/$slug');

  /// Service status page.
  Uri get statusPageUrl => sitePage('/status');

  /// Account deletion on the web (Play's data deletion link).
  Uri get accountDeletionUrl => sitePage('/delete-account');

  static const String supportEmail = 'support@savestream.online';
  static const String abuseEmail = 'abuse@savestream.online';

  /// Android application id; the Play Store listing opens from it.
  static const String androidPackageName = 'com.savestream.app';

  /// The Play Store app (market://) and the web listing as fallback.
  static final Uri playStoreAppUrl = Uri.parse(
    'market://details?id=$androidPackageName',
  );
  static final Uri playStoreWebUrl = Uri.parse(
    'https://play.google.com/store/apps/details?id=$androidPackageName',
  );

  static Uri mailto(String address, {String? subject}) => Uri(
    scheme: 'mailto',
    path: address,
    query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}',
  );

  /// Google Play's order history (receipts, refunds) for the signed-in
  /// Play account.
  static final Uri googlePlayOrderHistoryUrl = Uri.parse(
    'https://play.google.com/store/account/orderhistory',
  );

  bool get isProduction => environment == AppEnvironment.production;
  bool get developerToolsEnabled => environment != AppEnvironment.production;

  factory AppConfig.fromEnvironment() {
    const String environmentValue = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'local',
    );
    const String configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
    const String configuredPrivacyPolicyUrl = String.fromEnvironment(
      'PRIVACY_POLICY_URL',
    );
    const String configuredTermsOfUseUrl = String.fromEnvironment(
      'TERMS_OF_USE_URL',
    );

    final AppEnvironment environment = AppEnvironment.parse(environmentValue);
    final String baseUrl = configuredBaseUrl.isNotEmpty
        ? configuredBaseUrl
        : _defaultApiBaseUrl(environment);

    final Uri apiBaseUrl = _requireAbsoluteUri(
      baseUrl,
      name: 'API_BASE_URL',
      requireHttps: environment != AppEnvironment.local,
    );

    final Uri privacyPolicyUrl = _requireAbsoluteUri(
      configuredPrivacyPolicyUrl.isEmpty
          ? 'https://savestream.online/privacy'
          : configuredPrivacyPolicyUrl,
      name: 'PRIVACY_POLICY_URL',
      requireHttps: true,
    );
    final Uri termsOfUseUrl = _requireAbsoluteUri(
      configuredTermsOfUseUrl.isEmpty
          ? 'https://savestream.online/terms'
          : configuredTermsOfUseUrl,
      name: 'TERMS_OF_USE_URL',
      requireHttps: true,
    );

    return AppConfig(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      privacyPolicyUrl: privacyPolicyUrl,
      termsOfUseUrl: termsOfUseUrl,
    );
  }

  static String _defaultApiBaseUrl(AppEnvironment environment) {
    switch (environment) {
      case AppEnvironment.local:
        return 'http://10.0.2.2:8000';
      case AppEnvironment.staging:
        return 'https://staging-api.savestream.online';
      case AppEnvironment.production:
        return 'https://api.savestream.online';
    }
  }

  static Uri _requireAbsoluteUri(
    String value, {
    required String name,
    required bool requireHttps,
  }) {
    if (value.isEmpty) {
      throw StateError('$name must not be empty.');
    }
    final Uri uri = Uri.parse(value);
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw StateError('$name must be an absolute URI.');
    }
    if (uri.userInfo.isNotEmpty) {
      throw StateError('$name must not contain credentials.');
    }
    if (requireHttps && uri.scheme.toLowerCase() != 'https') {
      throw StateError('HTTPS $name is required for release builds.');
    }
    return uri;
  }
}
