class MinimumSupportedVersion {
  const MinimumSupportedVersion({
    required this.android,
    required this.ios,
  });

  final String android;
  final String ios;
}

class MaintenanceStatus {
  const MaintenanceStatus({required this.active, this.eta});

  final bool active;
  final DateTime? eta;
}

class AppStatus {
  const AppStatus({
    required this.minSupportedVersion,
    required this.maintenance,
  });

  final MinimumSupportedVersion minSupportedVersion;
  final MaintenanceStatus maintenance;
}
