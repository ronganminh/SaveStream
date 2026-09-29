enum AppEnvironment {
  local,
  staging,
  production;

  String get label {
    switch (this) {
      case AppEnvironment.local:
        return 'LOCAL';
      case AppEnvironment.staging:
        return 'STAGING';
      case AppEnvironment.production:
        return 'PRODUCTION';
    }
  }

  static AppEnvironment parse(String value) {
    switch (value.trim().toLowerCase()) {
      case 'local':
        return AppEnvironment.local;
      case 'staging':
        return AppEnvironment.staging;
      case 'production':
      case 'prod':
        return AppEnvironment.production;
      default:
        throw ArgumentError.value(
          value,
          'APP_ENV',
          'Expected local, staging, or production.',
        );
    }
  }
}
