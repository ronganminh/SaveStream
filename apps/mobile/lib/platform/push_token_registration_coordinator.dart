import 'dart:async';

import 'package:package_info_plus/package_info_plus.dart';

import '../app/app_settings_controller.dart';
import '../app/session/app_session_controller.dart';
import '../features/devices/domain/models/device_registration.dart';
import '../features/devices/domain/repositories/device_repository.dart';
import 'contracts/device_info_service.dart';
import 'contracts/push_service.dart';

typedef AppVersionLoader = Future<String> Function();

final class PushTokenRegistrationCoordinator {
  PushTokenRegistrationCoordinator({
    required AppSessionController session,
    required AppSettingsController settings,
    required PushService pushService,
    required DeviceInfoService deviceInfoService,
    required DeviceRepository deviceRepository,
    AppVersionLoader? appVersionLoader,
  }) : _session = session,
       _settings = settings,
       _pushService = pushService,
       _deviceInfoService = deviceInfoService,
       _deviceRepository = deviceRepository,
       _appVersionLoader = appVersionLoader ?? _loadAppVersion;

  final AppSessionController _session;
  final AppSettingsController _settings;
  final PushService _pushService;
  final DeviceInfoService _deviceInfoService;
  final DeviceRepository _deviceRepository;
  final AppVersionLoader _appVersionLoader;

  StreamSubscription<String?>? _tokenSubscription;
  String? _latestToken;
  String? _lastRegisteredFingerprint;
  bool _hasTokenSnapshot = false;
  bool _started = false;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _tokenSubscription = _pushService.tokenStream.listen(_onToken);
    _session.addListener(_onSessionChanged);
    _settings.addListener(_onSettingsChanged);
  }

  Future<void> dispose() async {
    if (!_started) {
      return;
    }
    _started = false;
    _session.removeListener(_onSessionChanged);
    _settings.removeListener(_onSettingsChanged);
    await _tokenSubscription?.cancel();
  }

  void _onToken(String? token) {
    _hasTokenSnapshot = true;
    _latestToken = token?.trim().isEmpty ?? true ? null : token!.trim();
    if (_session.isAuthenticated) {
      unawaited(_registerCurrentDevice());
    }
  }

  void _onSessionChanged() {
    _lastRegisteredFingerprint = null;
    if (_session.isAuthenticated && _hasTokenSnapshot) {
      unawaited(_registerCurrentDevice());
    }
  }

  void _onSettingsChanged() {
    if (_session.isAuthenticated && _hasTokenSnapshot) {
      unawaited(_registerCurrentDevice());
    }
  }

  Future<void> _registerCurrentDevice() async {
    if (!_session.isAuthenticated || !_hasTokenSnapshot) {
      return;
    }

    try {
      final String deviceId = await _deviceInfoService.deviceId;
      final String deviceName = await _deviceInfoService.deviceName;
      final String appVersion = await _appVersionLoader();
      final String locale = _settings.locale.languageCode;
      final String token = _latestToken ?? '';
      final String fingerprint = [
        deviceId,
        token,
        appVersion,
        locale,
        _deviceInfoService.platform.name,
      ].join('|');
      if (fingerprint == _lastRegisteredFingerprint) {
        return;
      }

      await _deviceRepository.register(
        DeviceRegistration(
          deviceId: deviceId,
          platform: _deviceInfoService.platform,
          pushToken: _latestToken,
          deviceName: deviceName,
          appVersion: appVersion,
          locale: locale,
        ),
      );
      _lastRegisteredFingerprint = fingerprint;
    } on Object {
      // Registration is best-effort. A later token refresh, login, or locale
      // change retries the same idempotent device PUT without blocking startup.
    }
  }

  static Future<String> _loadAppVersion() async {
    return (await PackageInfo.fromPlatform()).version;
  }
}
