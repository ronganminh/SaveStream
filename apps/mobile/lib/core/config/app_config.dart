import 'app_environment.dart';

class AppConfig {
  AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    Uri? privacyPolicyUrl,
    Uri? termsOfUseUrl,
  }) : privacyPolicyUrl =
           privacyPolicyUrl ?? Uri.parse('https://savestream.online/privacy'),
       termsOfUseUrl =
           termsOfUseUrl ?? Uri.parse('https://savestream.online/terms');

  final AppEnvironment environment;
  final Uri apiBaseUrl;

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
