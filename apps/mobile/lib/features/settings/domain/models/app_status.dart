enum AppAvailability { available, updateRequired, maintenance }

class AppStatus {
  const AppStatus({
    required this.availability,
    this.minimumVersion,
    this.message,
  });

  final AppAvailability availability;
  final String? minimumVersion;
  final String? message;
}
