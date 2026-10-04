import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/models/app_status.dart';
import '../../domain/repositories/app_status_repository.dart';

final class ApiAppStatusRepository implements AppStatusRepository {
  const ApiAppStatusRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<AppStatus> getStatus() async {
    try {
      final response = await _apiClient.get<AppStatus>(
        '/v1/app/status',
        decoder: _decode,
      );
      return response.data;
    } on ApiException catch (error) {
      if (error.statusCode == 501 || error.code == 'NOT_IMPLEMENTED') {
        return const AppStatus(
          minSupportedVersion: MinimumSupportedVersion(
            android: '0.0.0',
            ios: '0.0.0',
          ),
          maintenance: MaintenanceStatus(active: false),
        );
      }
      rethrow;
    }
  }

  static AppStatus _decode(Object? json) {
    final Map<Object?, Object?> map = _requiredMap(json, 'app status');
    final Map<Object?, Object?> versions = _requiredMap(
      map['min_supported_version'],
      'min_supported_version',
    );
    final Map<Object?, Object?> maintenance = _requiredMap(
      map['maintenance'],
      'maintenance',
    );

    return AppStatus(
      minSupportedVersion: MinimumSupportedVersion(
        android: _requiredString(versions['android'], 'android version'),
        ios: _requiredString(versions['ios'], 'ios version'),
      ),
      maintenance: MaintenanceStatus(
        active: _requiredBool(maintenance['active'], 'maintenance.active'),
        eta: _optionalDateTime(maintenance['eta'], 'maintenance.eta'),
      ),
    );
  }
}

Map<Object?, Object?> _requiredMap(Object? value, String name) {
  if (value is! Map) throw FormatException('Expected $name object.');
  return value;
}

String _requiredString(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Expected non-empty $name.');
  }
  return value.trim();
}

bool _requiredBool(Object? value, String name) {
  if (value is! bool) throw FormatException('Expected $name boolean.');
  return value;
}

DateTime? _optionalDateTime(Object? value, String name) {
  if (value == null) return null;
  if (value is! String) throw FormatException('Expected nullable $name.');
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Expected valid $name timestamp.');
  return parsed.toUtc();
}
