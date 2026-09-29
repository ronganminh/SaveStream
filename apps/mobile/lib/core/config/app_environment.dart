enum AppEnvironment {
  local,
  staging,
  production;

  String get label => switch (this) {
        AppEnvironment.local => 'LOCAL',
        AppEnvironment.staging => 'STAGING',
        AppEnvironment.production => 'PRODUCTION',
      };

  static AppEnvironment parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'local' => AppEnvironment.local,
      'staging' => AppEnvironment.staging,
      'production' || 'prod' => AppEnvironment.production,
      _ => throw ArgumentError.value(
          value,
          'APP_ENV',
          'Expected local, staging, or production.',
        ),
    };
  }
}
