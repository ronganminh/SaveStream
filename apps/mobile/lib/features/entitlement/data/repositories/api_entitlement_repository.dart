import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/models/entitlement.dart';
import '../../domain/repositories/entitlement_repository.dart';

final class ApiEntitlementRepository implements EntitlementRepository {
  const ApiEntitlementRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Entitlement> getEntitlement() async {
    try {
      final response = await _apiClient.get<Entitlement>(
        '/v1/me/entitlement',
        decoder: _decodeEntitlement,
      );
      return response.data;
    } on ApiException catch (error) {
      if (_isNotImplemented(error)) {
        return _safeFreeFallback();
      }
      rethrow;
    }
  }

  static Entitlement _decodeEntitlement(Object? json) {
    final Map<Object?, Object?> map = _requiredMap(json, 'entitlement');
    final Map<Object?, Object?> limits = _requiredMap(map['limits'], 'limits');
    final Map<Object?, Object?> local = _requiredMap(map['local'], 'local');

    return Entitlement(
      plan: switch (_requiredString(map['plan'], 'plan')) {
        'free' => Plan.free,
        'pro' => Plan.pro,
        final String value => throw FormatException(
          'Unsupported entitlement plan: $value',
        ),
      },
      hasPurchased: _requiredBool(map['has_purchased'], 'has_purchased'),
      cloudMinutesAvailable: _requiredInt(
        map['cloud_minutes_available'],
        'cloud_minutes_available',
      ),
      limits: EntitlementLimits(
        maxWatches: _requiredInt(limits['max_watches'], 'limits.max_watches'),
        maxConcurrentCloudRecordings: _requiredInt(
          limits['max_concurrent_cloud_recordings'],
          'limits.max_concurrent_cloud_recordings',
        ),
        cloudRetentionDays: _requiredInt(
          limits['cloud_retention_days'],
          'limits.cloud_retention_days',
        ),
      ),
      watchCount: _requiredInt(map['watch_count'], 'watch_count'),
      local: LocalEntitlement(
        enabled: _requiredBool(local['enabled'], 'local.enabled'),
        unlimited: _requiredBool(local['unlimited'], 'local.unlimited'),
        dailyMinutes: _requiredInt(
          local['daily_minutes'],
          'local.daily_minutes',
        ),
        minutesRemaining: _requiredInt(
          local['minutes_remaining'],
          'local.minutes_remaining',
        ),
        resetsAt: _requiredDateTime(local['resets_at'], 'local.resets_at'),
        rewardsUsedToday: _requiredInt(
          local['rewards_used_today'],
          'local.rewards_used_today',
        ),
        rewardsCapPerDay: _requiredInt(
          local['rewards_cap_per_day'],
          'local.rewards_cap_per_day',
        ),
        minutesPerReward: _requiredInt(
          local['minutes_per_reward'],
          'local.minutes_per_reward',
        ),
        extensionsCapPerRecording: _requiredInt(
          local['extensions_cap_per_recording'],
          'local.extensions_cap_per_recording',
        ),
      ),
      updatedAt: _requiredDateTime(map['updated_at'], 'updated_at'),
    );
  }

  static Entitlement _safeFreeFallback() {
    final DateTime now = DateTime.now().toUtc();
    final DateTime nextReset = DateTime.utc(now.year, now.month, now.day + 1);
    return Entitlement(
      plan: Plan.free,
      hasPurchased: false,
      cloudMinutesAvailable: 0,
      limits: const EntitlementLimits(
        maxWatches: 3,
        maxConcurrentCloudRecordings: 0,
        cloudRetentionDays: 7,
      ),
      watchCount: 0,
      local: LocalEntitlement(
        enabled: true,
        unlimited: false,
        dailyMinutes: 10,
        minutesRemaining: 10,
        resetsAt: nextReset,
        rewardsUsedToday: 0,
        rewardsCapPerDay: 8,
        minutesPerReward: 10,
        extensionsCapPerRecording: 4,
      ),
      updatedAt: now,
    );
  }
}

bool _isNotImplemented(ApiException error) =>
    error.statusCode == 501 || error.code == 'NOT_IMPLEMENTED';

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

int _requiredInt(Object? value, String name) {
  if (value is! int || value < 0) {
    throw FormatException('Expected non-negative $name integer.');
  }
  return value;
}

DateTime _requiredDateTime(Object? value, String name) {
  if (value is! String) throw FormatException('Expected $name timestamp.');
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Expected valid $name timestamp.');
  return parsed.toUtc();
}
