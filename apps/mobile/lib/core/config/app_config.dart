import 'app_environment.dart';

class AppConfig {
  AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    this.externalCheckoutEnabled = true,
    Uri? privacyPolicyUrl,
    Uri? termsOfUseUrl,
  }) : privacyPolicyUrl =
           privacyPolicyUrl ?? Uri.parse('https://savestream.online/privacy'),
       termsOfUseUrl =
           termsOfUseUrl ?? Uri.parse('https://savestream.online/terms');

  final AppEnvironment environment;
  final Uri apiBaseUrl;

  /// External hosted checkout is intentionally disabled by default for
  /// production native builds. Enable only for a distribution channel whose
  /// payment policy has been explicitly reviewed.
  final bool externalCheckoutEnabled;
  final Uri privacyPolicyUrl;
  final Uri termsOfUseUrl;

  bool get isProduction => environment == AppEnvironment.production;
  bool get developerToolsEnabled => environment != AppEnvironment.production;

  factory AppConfig.fromEnvironment() {
    const String environmentValue = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'local',
    );
    const String configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
    const String configuredExternalCheckout = String.fromEnvironment(
      'MOBILE_EXTERNAL_CHECKOUT_ENABLED',
    );
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

    final bool externalCheckoutEnabled = configuredExternalCheckout.isEmpty
        ? environment != AppEnvironment.production
        : _parseBoolDefine(
            configuredExternalCheckout,
            'MOBILE_EXTERNAL_CHECKOUT_ENABLED',
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
      externalCheckoutEnabled: externalCheckoutEnabled,
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

  static bool _parseBoolDefine(String value, String name) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
      default:
        throw StateError('$name must be true or false.');
    }
  }
}
