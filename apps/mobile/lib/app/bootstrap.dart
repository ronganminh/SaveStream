import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_error_reporter.dart';
import '../core/storage/shared_preferences_app_settings_store.dart';
import '../features/app_status/data/repositories/api_app_status_repository.dart';
import '../features/auth/data/auth_runtime.dart';
import '../features/auth/data/current_user_id_source.dart';
import '../features/billing/data/repositories/api_billing_repository.dart';
import '../features/channels/data/repositories/api_watch_repository.dart';
import '../features/credits/data/repositories/api_credits_repository.dart';
import '../features/devices/data/repositories/api_device_repository.dart';
import '../features/entitlement/data/repositories/api_entitlement_repository.dart';
import '../features/local_recordings/data/repositories/api_local_recording_repository.dart';
import '../features/local_recordings/presentation/controllers/local_recording_controller.dart'
    as local_recording;
import '../features/recordings/data/repositories/api_recording_repository.dart';
import '../features/settings/data/repositories/api_notification_preferences_repository.dart';
import '../features/settings/data/repositories/api_notifications_repository.dart';
import '../features/settings/data/repositories/api_profile_repository.dart';
import '../features/v2_foundation/v2_foundation_providers.dart';
import '../platform/android_local_recorder.dart';
import '../platform/android_local_recovery_service.dart';
import '../platform/android_recording_platform_service.dart';
import '../platform/connectivity_plus_service.dart';
import '../platform/device_info_plus_service.dart';
import '../platform/platform_providers.dart';
import 'app_settings_controller.dart';
import 'savestream_app.dart';
import 'session/app_session_controller.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AppErrorReporter errorReporter = AppErrorReporter();
  FlutterError.onError = errorReporter.reportFlutterError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    errorReporter.reportUnhandled(error, stackTrace);
    return true;
  };

  final AppConfig config = AppConfig.fromEnvironment();
  final AppSettingsController settings = AppSettingsController(
    store: SharedPreferencesAppSettingsStore(),
  );
  await settings.initialize();

  final AppSessionController session = AppSessionController(
    authStatus: AppAuthStatus.unauthenticated,
  );
  final AuthRuntime authRuntime = AuthRuntime.create(
    config: config,
    appSession: session,
  );
  await authRuntime.sessionManager.restoreSession();
  final authenticatedApiClient = authRuntime.authenticatedApiClient;
  final entitlementRepository = ApiEntitlementRepository(
    apiClient: authenticatedApiClient,
  );
  final appStatusRepository = ApiAppStatusRepository(
    apiClient: authenticatedApiClient,
  );
  final deviceRepository = ApiDeviceRepository(
    apiClient: authenticatedApiClient,
  );
  final CurrentUserIdSource currentUserIdSource = CurrentUserIdSource(
    apiClient: authenticatedApiClient,
  );
  final AndroidLocalRecorder? androidLocalRecorder = Platform.isAndroid
      ? AndroidLocalRecorder(currentUserId: currentUserIdSource.get)
      : null;
  final ApiLocalRecordingRepository? localRecordingRepository =
      androidLocalRecorder == null
      ? null
      : ApiLocalRecordingRepository(
          apiClient: authenticatedApiClient,
          onRegistered: androidLocalRecorder.markRegistered,
        );
  final AndroidLocalRecoveryService? androidLocalRecoveryService =
      localRecordingRepository == null
      ? null
      : AndroidLocalRecoveryService(
          repository: localRecordingRepository,
          currentUserId: currentUserIdSource.get,
        );
  final AndroidRecordingPlatformService? androidRecordingPlatformService =
      Platform.isAndroid ? AndroidRecordingPlatformService() : null;

  runApp(
    SaveStreamApp(
      config: config,
      settings: settings,
      session: session,
      authRepository: authRuntime.repository,
      apiClient: authenticatedApiClient,
      watchRepository: ApiWatchRepository(apiClient: authenticatedApiClient),
      recordingRepository: ApiRecordingRepository(
        apiClient: authenticatedApiClient,
      ),
      creditsRepository: ApiCreditsRepository(
        apiClient: authenticatedApiClient,
      ),
      billingRepository: ApiBillingRepository(
        apiClient: authenticatedApiClient,
      ),
      profileRepository: ApiProfileRepository(
        apiClient: authenticatedApiClient,
      ),
      notificationsRepository: ApiNotificationsRepository(
        apiClient: authenticatedApiClient,
      ),
      notificationPreferencesRepository: ApiNotificationPreferencesRepository(
        apiClient: authenticatedApiClient,
      ),
      extraOverrides: [
        connectivityServiceProvider.overrideWithValue(
          ConnectivityPlusService(),
        ),
        deviceInfoServiceProvider.overrideWithValue(DeviceInfoPlusService()),
        entitlementRepositoryProvider.overrideWithValue(entitlementRepository),
        appStatusRepositoryProvider.overrideWithValue(appStatusRepository),
        deviceRepositoryProvider.overrideWithValue(deviceRepository),
        if (localRecordingRepository != null)
          localRecordingRepositoryProvider.overrideWithValue(
            localRecordingRepository,
          ),
        if (localRecordingRepository != null)
          local_recording.localRecordingRepositoryProvider.overrideWithValue(
            localRecordingRepository,
          ),
        if (androidLocalRecorder != null)
          localRecorderProvider.overrideWithValue(androidLocalRecorder),
        if (androidLocalRecoveryService != null)
          localRecoveryServiceProvider.overrideWithValue(
            androidLocalRecoveryService,
          ),
        if (androidRecordingPlatformService != null)
          recordingPlatformServiceProvider.overrideWithValue(
            androidRecordingPlatformService,
          ),
      ],
    ),
  );
}
