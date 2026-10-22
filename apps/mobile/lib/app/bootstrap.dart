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
import '../features/channels/data/repositories/api_watch_repository.dart';
import '../features/credits/data/api_credits_repository.dart';
import '../features/credits/presentation/credits_providers.dart';
import '../features/devices/data/repositories/api_device_repository.dart';
import '../features/entitlement/data/repositories/api_entitlement_repository.dart';
import '../features/entitlement/presentation/entitlement_providers.dart'
    as entitlement_ui;
import '../features/recordings/data/repositories/api_recording_repository.dart';
import '../features/settings/data/repositories/api_notification_preferences_repository.dart';
import '../features/settings/data/repositories/api_notifications_repository.dart';
import '../features/settings/data/repositories/api_profile_repository.dart';
import '../features/store/data/repositories/api_store_repository.dart';
import '../features/store/data/retry/secure_store_purchase_retry_store.dart';
import '../features/store/presentation/a5_store_providers.dart' as store_ui;
import '../features/v2_foundation/v2_foundation_providers.dart';
import '../l10n/l10n.dart';
import '../platform/connectivity_plus_service.dart';
import '../platform/device_info_plus_service.dart';
import '../platform/firebase_push_service.dart';
import '../platform/in_app_purchase_service.dart';
import '../platform/platform_providers.dart';
import '../platform/push_runtime.dart';
import '../platform/push_token_registration_coordinator.dart';
import '../platform/share_plus_service.dart';
import 'app_settings_controller.dart';
import 'font_licenses.dart';
import 'savestream_app.dart';
import 'session/app_session_controller.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();

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
  if (Platform.isAndroid) {
    final AppLocalizations l10n = await AppLocalizations.delegate.load(
      settings.locale,
    );
    await PushRuntime.configureAndroidChannels(
      liveName: l10n.nativePushChannelLiveName,
      recordingName: l10n.nativePushChannelRecordingName,
    );
  }
  // Create channels before Firebase can receive a message.  FCM uses the
  // channel id from the server payload; creating it first prevents an early
  // LIVE push from falling back to a missing/default channel on Android.
  await pushService.initialize();

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
        appStatusRepositoryProvider.overrideWithValue(appStatusRepository),
        creditsRepositoryProvider.overrideWithValue(
          ApiCreditsRepository(apiClient: authenticatedApiClient),
        ),
        deviceRepositoryProvider.overrideWithValue(deviceRepository),
        shareServiceProvider.overrideWithValue(const SharePlusService()),
      ],
    ),
  );
}
