import 'app_environment.dart';

class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUrl});

  final AppEnvironment environment;
  final Uri apiBaseUrl;

  factory AppConfig.fromEnvironment() {
    const String environmentValue = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'local',
    );
    const String configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

    final AppEnvironment environment = AppEnvironment.parse(environmentValue);
    final String baseUrl = configuredBaseUrl.isNotEmpty
        ? configuredBaseUrl
        : _defaultApiBaseUrl(environment);

    if (baseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is required for ${environment.label.toLowerCase()} builds.',
      );
    }

    return AppConfig(environment: environment, apiBaseUrl: Uri.parse(baseUrl));
  }

  static String _defaultApiBaseUrl(AppEnvironment environment) {
    switch (environment) {
      case AppEnvironment.local:
        return 'http://10.0.2.2:8000';
      case AppEnvironment.staging:
      case AppEnvironment.production:
        return '';
    }
  }
}
