import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_error_reporter.dart';
import '../core/storage/shared_preferences_app_settings_store.dart';
import '../features/auth/data/auth_runtime.dart';
import '../features/billing/data/repositories/api_billing_repository.dart';
import '../features/channels/data/repositories/api_watch_repository.dart';
import '../features/credits/data/repositories/api_credits_repository.dart';
import '../features/recordings/data/repositories/api_recording_repository.dart';
import '../features/settings/data/repositories/api_profile_repository.dart';
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

  runApp(
    SaveStreamApp(
      config: config,
      settings: settings,
      session: session,
      authRepository: authRuntime.repository,
      apiClient: authRuntime.authenticatedApiClient,
      watchRepository: ApiWatchRepository(
        apiClient: authRuntime.authenticatedApiClient,
      ),
      recordingRepository: ApiRecordingRepository(
        apiClient: authRuntime.authenticatedApiClient,
      ),
      creditsRepository: ApiCreditsRepository(
        apiClient: authRuntime.authenticatedApiClient,
      ),
      billingRepository: ApiBillingRepository(
        apiClient: authRuntime.authenticatedApiClient,
      ),
      profileRepository: ApiProfileRepository(
        apiClient: authRuntime.authenticatedApiClient,
      ),
    ),
  );
}
