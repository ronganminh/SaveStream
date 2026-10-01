import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_error_reporter.dart';
import '../core/storage/shared_preferences_app_settings_store.dart';
import 'app_settings_controller.dart';
import 'savestream_app.dart';

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

  runApp(SaveStreamApp(config: config, settings: settings));
}
