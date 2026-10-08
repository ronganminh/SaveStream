import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_error_reporter.dart';
import '../core/storage/shared_preferences_app_settings_store.dart';
import '../features/app_status/data/repositories/api_app_status_repository.dart';
import '../features/auth/data/auth_runtime.dart';
import '../features/auth/data/current_user_id_source.dart';
import '../features/channels/data/repositories/api_watch_repository.dart';
import '../features/devices/data/repositories/api_device_repository.dart';
import '../features/entitlement/data/repositories/api_entitlement_repository.dart';
import '../features/entitlement/domain/models/entitlement.dart';
import '../features/entitlement/presentation/entitlement_providers.dart'
    as entitlement_ui;
import '../features/local_recordings/data/repositories/api_local_recording_repository.dart';
import '../features/local_recordings/data/repositories/indexed_local_recording_repository.dart';
import '../features/local_recordings/presentation/controllers/local_recording_controller.dart'
    as local_recording;
import '../features/recordings/data/repositories/api_recording_repository.dart';
import '../features/rewards/data/repositories/api_reward_repository.dart';
import '../features/settings/data/repositories/api_notification_preferences_repository.dart';
import '../features/settings/data/repositories/api_notifications_repository.dart';
import '../features/settings/data/repositories/api_profile_repository.dart';
import '../features/store/data/repositories/api_store_repository.dart';
import '../features/store/data/retry/secure_store_purchase_retry_store.dart';
import '../features/store/presentation/a5_store_providers.dart' as store_ui;
import '../features/v2_foundation/v2_foundation_providers.dart';
import '../l10n/l10n.dart';
import '../platform/android_local_recorder.dart';
import '../platform/android_local_recovery_service.dart';
import '../platform/android_recording_platform_service.dart';
import '../platform/connectivity_plus_service.dart';
import '../platform/device_info_plus_service.dart';
import '../platform/firebase_push_service.dart';
import '../platform/google_mobile_ads_service.dart';
import '../platform/in_app_purchase_service.dart';
import '../platform/platform_providers.dart';
import '../platform/push_runtime.dart';
import '../platform/push_token_registration_coordinator.dart';
import '../platform/share_plus_service.dart';
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

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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
  final rewardRepository = ApiRewardRepository(
    apiClient: authenticatedApiClient,
  );
  final GoogleMobileAdsService adsService = GoogleMobileAdsService(
    isEligible: () async {
      if (!session.isAuthenticated) return false;
      final entitlement = await entitlementRepository.getEntitlement();
      return entitlement.plan == Plan.free && entitlement.watchCount > 0;
    },
  );
  void refreshAdsConsent() {
    if (session.isAuthenticated) {
      unawaited(adsService.refreshConsentInfo());
    }
  }

  session.addListener(refreshAdsConsent);
  refreshAdsConsent();
  final deviceRepository = ApiDeviceRepository(
    apiClient: authenticatedApiClient,
  );
  final DeviceInfoPlusService deviceInfoService = DeviceInfoPlusService();
  final FirebasePushService pushService = FirebasePushService();
  PushTokenRegistrationCoordinator(
    session: session,
    settings: settings,
    pushService: pushService,
    deviceInfoService: deviceInfoService,
    deviceRepository: deviceRepository,
  ).start();
  await pushService.initialize();
  if (Platform.isAndroid) {
    final AppLocalizations l10n = await AppLocalizations.delegate.load(
      settings.locale,
    );
    await PushRuntime.configureAndroidChannels(
      liveName: l10n.nativePushChannelLiveName,
      recordingName: l10n.nativePushChannelRecordingName,
    );
  }

  final CurrentUserIdSource currentUserIdSource = CurrentUserIdSource(
    apiClient: authenticatedApiClient,
  );
  final AndroidLocalRecorder? androidLocalRecorder = Platform.isAndroid
      ? AndroidLocalRecorder(currentUserId: currentUserIdSource.get)
      : null;
  final ApiLocalRecordingRepository? apiLocalRecordingRepository =
      androidLocalRecorder == null
      ? null
      : ApiLocalRecordingRepository(
          apiClient: authenticatedApiClient,
          onRegistered: androidLocalRecorder.markRegistered,
        );
  final IndexedLocalRecordingRepository? localRecordingRepository =
      apiLocalRecordingRepository == null
      ? null
      : IndexedLocalRecordingRepository(
          delegate: apiLocalRecordingRepository,
          currentUserId: currentUserIdSource.get,
          currentDeviceId: () => deviceInfoService.deviceId,
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
      profileRepository: ApiProfileRepository(
        apiClient: authenticatedApiClient,
      ),
      notificationsRepository: ApiNotificationsRepository(
        apiClient: authenticatedApiClient,
      ),
      notificationPreferencesRepository: ApiNotificationPreferencesRepository(
        apiClient: authenticatedApiClient,
      ),
      foregroundPushMessages: pushService.foregroundMessageStream,
      openedPushMessages: pushService.runtimeOpenedMessageStream,
      extraOverrides: [
        connectivityServiceProvider.overrideWithValue(
          ConnectivityPlusService(),
        ),
        deviceInfoServiceProvider.overrideWithValue(deviceInfoService),
        adsServiceProvider.overrideWithValue(adsService),
        pushServiceProvider.overrideWithValue(pushService),
        purchaseServiceProvider.overrideWithValue(InAppPurchaseService()),
        store_ui.storeRepositoryProvider.overrideWithValue(
          ApiStoreRepository(apiClient: authenticatedApiClient),
        ),
        store_ui.storePurchaseRetryStoreProvider.overrideWithValue(
          SecureStorePurchaseRetryStore(),
        ),
        // Production screens consume the presentation-layer provider.
        // `v2_foundation` has a similarly named provider for mock previews.
        entitlementRepositoryProvider.overrideWithValue(entitlementRepository),
        entitlement_ui.entitlementRepositoryProvider.overrideWithValue(
          entitlementRepository,
        ),
        rewardRepositoryProvider.overrideWithValue(rewardRepository),
        local_recording.rewardRepositoryProvider.overrideWithValue(
          rewardRepository,
        ),
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
        shareServiceProvider.overrideWithValue(const SharePlusService()),
      ],
    ),
  );
}
