import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_error_reporter.dart';
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
  runApp(SaveStreamApp(config: config));
}
